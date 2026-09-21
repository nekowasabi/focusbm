using System.Diagnostics;
using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Activation;
using FocusBM.Infrastructure.Windows.Browser;
using FocusBM.Infrastructure.Windows.Processes;
using FocusBM.Infrastructure.Windows.Wsl;

return await FocusBmCli.RunAsync(args, Console.Out, Console.Error);

public static class FocusBmCli
{
    public static async Task<int> RunAsync(string[] args, TextWriter stdout, TextWriter stderr)
    {
        var command = args.FirstOrDefault() ?? "help";
        var path = BookmarkPaths.ResolveDefaultYamlPath();
        var repo = new YamlBookmarkRepository(path);
        try
        {
            switch (command)
            {
                case "where":
                    await stdout.WriteLineAsync(path);
                    return 0;
                case "list":
                    return await ListAsync(repo, stdout);
                case "add":
                    return await AddAsync(repo, args, stdout, stderr);
                case "delete":
                case "del":
                    return await DeleteAsync(repo, args, stdout, stderr);
                case "edit":
                    return await EditAsync(path, stdout, stderr);
                case "restore":
                case "switch":
                    return await RestoreByIdAsync(repo, args, stdout, stderr);
                case "restore-context":
                    return await RestoreByQueryAsync(repo, args, stdout, stderr);
                case "save":
                    return await SaveForegroundAsync(repo, args, stdout, stderr);
                case "tmux-list":
                    return await TmuxListAsync(repo, stdout, stderr);
                case "config":
                    return await ConfigAsync(repo, args, stdout, stderr);
                case "sample":
                    return await SampleAsync(repo, stdout);
                case "help":
                default:
                    await stdout.WriteLineAsync("focusbm-win commands: list, add <id> <app> <context>, delete <id>, edit, save <id> [context], restore <id>, restore-context <query>, switch <id>, tmux-list, config get|set <key> <value>|init-cdp [profilePath] [endpoint], sample, where");
                    return command == "help" ? 0 : 2;
            }
        }
        catch (Exception ex)
        {
            await stderr.WriteLineAsync(Redactor.Mask(ex.Message));
            return 1;
        }
    }

    private static async Task<int> ListAsync(IBookmarkRepository repo, TextWriter stdout)
    {
        var store = await repo.LoadAsync();
        foreach (var item in store.Bookmarks) await stdout.WriteLineAsync($"{item.Id}\t{item.AppName}\t{item.Context}");
        return 0;
    }

    private static async Task<int> AddAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 4) return await Fail(stderr, "add requires id appName context");
        var loaded = await repo.LoadAsync();
        var bm = new Bookmark(args[1], args[2], args[3]);
        await repo.SaveAsync(Upsert(loaded, bm));
        await stdout.WriteLineAsync("added");
        return 0;
    }

    private static async Task<int> DeleteAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 2) return await Fail(stderr, "delete requires id");
        var before = await repo.LoadAsync();
        var next = before.Bookmarks.Where(b => b.Id != args[1]).ToList();
        if (next.Count == before.Bookmarks.Count) return await Fail(stderr, "bookmark not found");
        await repo.SaveAsync(before with { Bookmarks = next });
        await stdout.WriteLineAsync("deleted");
        return 0;
    }

    private static async Task<int> EditAsync(string path, TextWriter stdout, TextWriter stderr)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        if (!File.Exists(path)) await File.WriteAllTextAsync(path, new BookmarkYamlSerializer().Serialize(new BookmarkStore(new AppSettings(), Array.Empty<Bookmark>())));
        var editor = Environment.GetEnvironmentVariable("EDITOR");
        if (string.IsNullOrWhiteSpace(editor)) editor = OperatingSystem.IsWindows() ? "notepad.exe" : Environment.GetEnvironmentVariable("VISUAL") ?? "vi";
        try
        {
            var psi = new ProcessStartInfo(editor, $"\"{path}\"") { UseShellExecute = true };
            using var p = Process.Start(psi);
            await stdout.WriteLineAsync($"opened: {path}");
            return 0;
        }
        catch (Exception ex)
        {
            return await Fail(stderr, $"failed to open editor: {Redactor.Mask(ex.Message)}");
        }
    }

    private static async Task<int> RestoreByIdAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 2) return await Fail(stderr, "restore requires id");
        var s = await repo.LoadAsync();
        var selected = s.Bookmarks.FirstOrDefault(b => b.Id == args[1]);
        if (selected is null) return await Fail(stderr, "bookmark not found");
        return await RestoreAsync(s, selected, stdout, stderr);
    }

    private static async Task<int> RestoreByQueryAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 2) return await Fail(stderr, "restore-context requires query");
        var s = await repo.LoadAsync();
        var query = string.Join(' ', args.Skip(1));
        var matches = BookmarkSearcher.Filter(s.Bookmarks, query);
        if (matches.Count == 0) return await Fail(stderr, "bookmark not found");
        return await RestoreAsync(s, matches[0], stdout, stderr);
    }

    private static async Task<int> RestoreAsync(BookmarkStore store, Bookmark selected, TextWriter stdout, TextWriter stderr)
    {
        var settings = store.Settings ?? new AppSettings();
        var browser = settings.BrowserCdp?.Enabled == true ? new ChromiumCdpTabService(settings) : null;
        var tmux = settings.Wsl?.Enabled == true ? new WslTmuxService(settings.Wsl, new DefaultProcessRunner()) : null;
        var wsl = settings.Wsl?.Enabled == true ? new WslProcessService(settings.Wsl, new DefaultProcessRunner()) : null;
        var orchestrator = new BookmarkRestoreOrchestrator(new WindowsActivationService(settings.VirtuaWinEnabled), browser, tmux, wsl);
        var result = await orchestrator.RestoreAsync(selected);
        var line = $"{result.Status}: {result.Message}";
        if (result.IsSuccess) { await stdout.WriteLineAsync(line); return 0; }
        await stderr.WriteLineAsync(line);
        return result.Status == OperationStatus.Unsupported ? 3 : 1;
    }

    private static async Task<int> SaveForegroundAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 2) return await Fail(stderr, "save requires id");
        var store = await repo.LoadAsync();
        var settings = store.Settings ?? new AppSettings();
        var capture = await new WindowsForegroundContextService().CaptureAsync(settings);
        if (!capture.IsSuccess)
        {
            await stderr.WriteLineAsync($"{capture.Status}: {capture.Message}");
            return capture.Status == OperationStatus.Unsupported ? 3 : 1;
        }
        var context = args.Length >= 3 ? string.Join(' ', args.Skip(2)) : capture.Context;
        var state = capture.State;
        if (settings.BrowserCdp?.Enabled == true && LooksLikeChromium(capture.AppName))
        {
            var browserCapture = await new ChromiumCdpTabService(settings).CaptureFirstPageAsync(capture.AppName);
            if (browserCapture.IsSuccess)
            {
                state = browserCapture.State;
                context = args.Length >= 3 ? context : browserCapture.Context;
            }
            else
            {
                await stderr.WriteLineAsync($"CDP capture fallback: {browserCapture.Status}: {browserCapture.Message}");
            }
        }
        var bm = new Bookmark(args[1], capture.AppName, context, state, capture.BundleIdPattern);
        await repo.SaveAsync(Upsert(store, bm));
        await stdout.WriteLineAsync($"saved: {bm.Id}\t{bm.AppName}\t{bm.Context}");
        return 0;
    }

    private static async Task<int> TmuxListAsync(IBookmarkRepository repo, TextWriter stdout, TextWriter stderr)
    {
        var store = await repo.LoadAsync();
        var settings = store.Settings?.Wsl;
        if (settings?.Enabled != true) return await Fail(stderr, "WSL/tmux capability disabled");
        var panes = await new WslTmuxService(settings, new DefaultProcessRunner()).ListPanesAsync();
        foreach (var p in panes) await stdout.WriteLineAsync($"{p.Session}\t{p.Window}\t{p.PaneId}\t{p.CurrentCommand}\t{p.Title}\t{p.WindowName}\t{p.CurrentDirectory}");
        return 0;
    }


    private static async Task<int> SampleAsync(IBookmarkRepository repo, TextWriter stdout)
    {
        var store = await repo.LoadAsync();
        var sample = new Bookmark("memo", "notepad", "manual test notepad", new AppOnlyState("Untitled"));
        await repo.SaveAsync(Upsert(store with { Settings = store.Settings ?? new AppSettings() }, sample));
        await stdout.WriteLineAsync("sample bookmark written: memo -> notepad");
        return 0;
    }

    private static async Task<int> ConfigAsync(IBookmarkRepository repo, string[] args, TextWriter stdout, TextWriter stderr)
    {
        if (args.Length < 2) return await Fail(stderr, "config requires get or set");
        var store = await repo.LoadAsync();
        var settings = store.Settings ?? new AppSettings();
        if (args[1] == "init-cdp")
        {
            var profilePath = args.Length >= 3 ? args[2] : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "focusbm-cdp-profile");
            var endpoint = args.Length >= 4 ? args[3] : "http://127.0.0.1:9222";
            ChromiumCdpTabService.EnsureProfileMarker(profilePath);
            settings = settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { Enabled = true, Endpoint = endpoint, ProfilePath = profilePath, RequireProfileMarker = true } };
            await repo.SaveAsync(store with { Settings = settings });
            await stdout.WriteLineAsync($"cdp initialized: endpoint={endpoint} profilePath={profilePath}");
            return 0;
        }
        if (args[1] == "get")
        {
            await stdout.WriteLineAsync($"bookmarkListColumns={settings.BookmarkListColumns}");
            await stdout.WriteLineAsync($"cmdMapping={settings.CmdMapping}");
            await stdout.WriteLineAsync($"togglePanel={HotkeyParser.Format(settings.EffectiveHotkey)}");
            await stdout.WriteLineAsync($"hotkeyKey={settings.EffectiveHotkey.Key}");
            await stdout.WriteLineAsync($"hotkeyModifiers={settings.EffectiveHotkey.Modifiers}");
            await stdout.WriteLineAsync($"panelWidth={settings.EffectivePanelWidth}");
            await stdout.WriteLineAsync($"panelHeight={settings.EffectivePanelHeight}");
            await stdout.WriteLineAsync($"displayNumber={settings.DisplayNumber?.ToString() ?? "primary"}");
            await stdout.WriteLineAsync($"openSessionPullRequest={settings.OpenSessionPullRequestHotkey}");
            await stdout.WriteLineAsync($"forceReloadAgents={settings.ForceReloadAgentsHotkey}");
            await stdout.WriteLineAsync($"imeRestoreEnabled={settings.ImeRestoreEnabled}");
            await stdout.WriteLineAsync($"virtuawinEnabled={settings.VirtuaWinEnabled}");
            await stdout.WriteLineAsync($"browserCdpEnabled={settings.BrowserCdp?.Enabled ?? false}");
            await stdout.WriteLineAsync($"browserCdpEndpoint={settings.BrowserCdp?.Endpoint ?? string.Empty}");
            await stdout.WriteLineAsync($"browserCdpProfilePath={settings.BrowserCdp?.ProfilePath ?? string.Empty}");
            await stdout.WriteLineAsync($"browserCdpRequireKnownBrowserOwner={settings.BrowserCdp?.RequireKnownBrowserOwner ?? true}");
            await stdout.WriteLineAsync($"wslEnabled={settings.Wsl?.Enabled ?? false}");
            await stdout.WriteLineAsync($"wslDistribution={settings.Wsl?.Distribution ?? string.Empty}");
            await stdout.WriteLineAsync($"wslUser={settings.Wsl?.User ?? string.Empty}");
            return 0;
        }
        if (args[1] != "set" || args.Length < 4) return await Fail(stderr, "config set requires key and value");
        var key = args[2];
        var value = string.Join(' ', args.Skip(3));
        settings = ApplyConfig(settings, key, value);
        await repo.SaveAsync(store with { Settings = settings });
        await stdout.WriteLineAsync($"configured: {key}={value}");
        return 0;
    }

    private static AppSettings ApplyConfig(AppSettings settings, string key, string value)
    {
        bool Bool() => bool.TryParse(value, out var b) ? b : throw new ArgumentException($"{key} must be true/false");
        int Int() => int.TryParse(value, out var n) ? n : throw new ArgumentException($"{key} must be integer");
        return key switch
        {
            "bookmarkListColumns" => settings with { BookmarkListColumns = Int() },
            "cmdMapping" => settings with { CmdMapping = Enum.Parse<CmdMapping>(value, ignoreCase: true) },
            "hotkeyKey" => settings with { Hotkey = (settings.Hotkey ?? new HotkeySettings()) with { Key = value } },
            "hotkeyModifiers" => settings with { Hotkey = (settings.Hotkey ?? new HotkeySettings()) with { Modifiers = ParseModifiers(value) } },
            "togglePanel" => ApplyTogglePanel(settings, value),
            "panelWidth" => settings with { PanelWidth = double.TryParse(value, out var w) ? w : throw new ArgumentException("panelWidth must be a number") },
            "panelHeight" => settings with { PanelHeight = double.TryParse(value, out var h) ? h : throw new ArgumentException("panelHeight must be a number") },
            "displayNumber" => settings with { DisplayNumber = Int() },
            "imeRestoreEnabled" => settings with { ImeRestoreEnabled = Bool() },
            "virtuawinEnabled" => settings with { VirtuaWinEnabled = Bool() },
            "browserCdpEnabled" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { Enabled = Bool() } },
            "browserCdpEndpoint" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { Endpoint = value } },
            "browserCdpProfilePath" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { ProfilePath = value } },
            "browserCdpRequireKnownBrowserOwner" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { RequireKnownBrowserOwner = Bool() } },
            "wslEnabled" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { Enabled = Bool() } },
            "wslDistribution" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { Distribution = value } },
            "wslUser" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { User = value } },
            "openSessionPullRequest" => settings with { OpenSessionPullRequestHotkey = value },
            "forceReloadAgents" => settings with { ForceReloadAgentsHotkey = value },
            _ => throw new ArgumentException($"unknown config key: {key}")
        };
    }

    private static AppSettings ApplyTogglePanel(AppSettings settings, string value)
    {
        var parsed = HotkeyParser.Parse(value, settings.CmdMapping);
        return settings with { Hotkey = new HotkeySettings(parsed.Key, parsed.Modifiers) };
    }

    private static HotkeyModifiers ParseModifiers(string value)
    {
        HotkeyModifiers mods = HotkeyModifiers.None;
        foreach (var part in value.Split(new[] { '+', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            mods |= Enum.Parse<HotkeyModifiers>(part, ignoreCase: true);
        }
        return mods;
    }


    private static bool LooksLikeChromium(string appName)
    {
        var normalized = appName.Replace(" ", "", StringComparison.OrdinalIgnoreCase).ToLowerInvariant();
        return normalized.Contains("chrome") || normalized.Contains("chromium") || normalized.Contains("msedge") || normalized.Contains("edge");
    }

    private static BookmarkStore Upsert(BookmarkStore store, Bookmark bookmark)
    {
        var list = store.Bookmarks.Where(b => b.Id != bookmark.Id).Concat(new[] { bookmark }).ToList();
        return store with { Bookmarks = list };
    }

    private static async Task<int> Fail(TextWriter stderr, string message) { await stderr.WriteLineAsync(message); return 2; }
}
