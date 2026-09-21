using System.Globalization;
using System.Text;

namespace FocusBM.Core;

/// <summary>Small deterministic YAML subset serializer for FocusBM bookmarks. Unknown top-level fields are preserved per bookmark.</summary>
public sealed class BookmarkYamlSerializer
{
    public string Serialize(BookmarkStore store)
    {
        var sb = new StringBuilder();
        sb.AppendLine("settings:");
        var settings = store.Settings ?? new AppSettings();
        sb.AppendLine($"  bookmarkListColumns: {settings.NormalizedColumns}");
        sb.AppendLine($"  cmdMapping: {settings.CmdMapping}");
        sb.AppendLine("  hotkey:");
        sb.AppendLine($"    togglePanel: {Q(HotkeyParser.Format(settings.EffectiveHotkey))}");
        sb.AppendLine($"  panelWidth: {settings.EffectivePanelWidth.ToString(CultureInfo.InvariantCulture)}");
        sb.AppendLine($"  panelHeight: {settings.EffectivePanelHeight.ToString(CultureInfo.InvariantCulture)}");
        if (settings.ListFontSize is not null) sb.AppendLine($"  listFontSize: {settings.ListFontSize.Value.ToString(CultureInfo.InvariantCulture)}");
        if (!string.IsNullOrWhiteSpace(settings.FontName)) sb.AppendLine($"  fontName: {Q(settings.FontName)}");
        if (settings.DisplayNumber is not null) sb.AppendLine($"  displayNumber: {settings.DisplayNumber.Value}");
        if (settings.AutoExecuteOnSingleResult is not null) sb.AppendLine($"  autoExecuteOnSingleResult: {settings.AutoExecuteOnSingleResult.Value.ToString().ToLowerInvariant()}");
        if (settings.AutoExecuteDelay is not null) sb.AppendLine($"  autoExecuteDelay: {settings.AutoExecuteDelay.Value.ToString(CultureInfo.InvariantCulture)}");
        if (settings.DirectNumberKeys is not null) sb.AppendLine($"  directNumberKeys: {settings.DirectNumberKeys.Value.ToString().ToLowerInvariant()}");
        if (settings.ShowAIAgentShortcut is not null) sb.AppendLine($"  showAIAgentShortcut: {settings.ShowAIAgentShortcut.Value.ToString().ToLowerInvariant()}");
        sb.AppendLine($"  showTmuxAgents: {settings.EffectiveShowTmuxAgents.ToString().ToLowerInvariant()}");
        sb.AppendLine($"  showWslAgents: {settings.EffectiveShowWslAgents.ToString().ToLowerInvariant()}");
        sb.AppendLine($"  openSessionPullRequest: {Q(settings.OpenSessionPullRequestHotkey)}");
        sb.AppendLine($"  forceReloadAgents: {Q(settings.ForceReloadAgentsHotkey)}");
        sb.AppendLine($"  imeRestoreEnabled: {settings.ImeRestoreEnabled.ToString().ToLowerInvariant()}");
        sb.AppendLine($"  virtuawinEnabled: {settings.VirtuaWinEnabled.ToString().ToLowerInvariant()}");
        if (settings.BrowserCdp is not null)
        {
            sb.AppendLine($"  browserCdpEnabled: {settings.BrowserCdp.Enabled.ToString().ToLowerInvariant()}");
            if (!string.IsNullOrWhiteSpace(settings.BrowserCdp.Endpoint)) sb.AppendLine($"  browserCdpEndpoint: {Q(settings.BrowserCdp.Endpoint!)}");
            if (!string.IsNullOrWhiteSpace(settings.BrowserCdp.ProfilePath)) sb.AppendLine($"  browserCdpProfilePath: {Q(settings.BrowserCdp.ProfilePath!)}");
            sb.AppendLine($"  browserCdpRequireProfileMarker: {settings.BrowserCdp.RequireProfileMarker.ToString().ToLowerInvariant()}");
            sb.AppendLine($"  browserCdpRequireKnownBrowserOwner: {settings.BrowserCdp.RequireKnownBrowserOwner.ToString().ToLowerInvariant()}");
            if (!string.IsNullOrWhiteSpace(settings.BrowserCdp.MarkerFileName)) sb.AppendLine($"  browserCdpMarkerFileName: {Q(settings.BrowserCdp.MarkerFileName)}");
        }
        if (settings.Wsl is not null)
        {
            sb.AppendLine($"  wslEnabled: {settings.Wsl.Enabled.ToString().ToLowerInvariant()}");
            if (!string.IsNullOrWhiteSpace(settings.Wsl.Distribution)) sb.AppendLine($"  wslDistribution: {Q(settings.Wsl.Distribution!)}");
            if (!string.IsNullOrWhiteSpace(settings.Wsl.User)) sb.AppendLine($"  wslUser: {Q(settings.Wsl.User!)}");
        }
        sb.AppendLine("bookmarks:");
        foreach (var bm in store.Bookmarks)
        {
            sb.AppendLine($"  - id: {Q(bm.Id)}");
            sb.AppendLine($"    appName: {Q(bm.AppName)}");
            sb.AppendLine($"    context: {Q(bm.Context)}");
            if (!string.IsNullOrWhiteSpace(bm.BundleIdPattern)) sb.AppendLine($"    bundleIdPattern: {Q(bm.BundleIdPattern!)}");
            if (!string.IsNullOrWhiteSpace(bm.Shortcut)) sb.AppendLine($"    shortcut: {Q(bm.Shortcut!)}");
            if (bm.NoShortcut) sb.AppendLine("    noShortcut: true");
            if (bm.LowPriority) sb.AppendLine("    lowPriority: true");
            if (bm.ExecuteOnToggleRepress) sb.AppendLine("    executeOnToggleRepress: true");
            if (bm.UnknownFields is not null)
            {
                foreach (var kv in bm.UnknownFields.OrderBy(k => k.Key))
                {
                    sb.AppendLine($"    {kv.Key}: {Q(kv.Value)}");
                }
            }
            if (bm.State is not null)
            {
                sb.AppendLine("    state:");
                sb.AppendLine($"      type: {Q(bm.State.Type)}");
                switch (bm.State)
                {
                    case BrowserAppState b:
                        sb.AppendLine($"      url: {Q(b.Url)}");
                        if (b.UrlPrefix is not null) sb.AppendLine($"      urlPrefix: {Q(b.UrlPrefix)}");
                        if (b.UrlPattern is not null) sb.AppendLine($"      urlPattern: {Q(b.UrlPattern)}");
                        if (b.Title is not null) sb.AppendLine($"      title: {Q(b.Title)}");
                        if (b.TabIndex is not null) sb.AppendLine($"      tabIndex: {b.TabIndex}");
                        break;
                    case AppOnlyState a when a.WindowTitle is not null:
                        sb.AppendLine($"      windowTitle: {Q(a.WindowTitle)}");
                        break;
                    case TmuxPaneState t:
                        sb.AppendLine($"      session: {Q(t.Session)}");
                        sb.AppendLine($"      window: {Q(t.Window)}");
                        sb.AppendLine($"      paneId: {Q(t.PaneId)}");
                        break;
                    case WslProcessState w:
                        sb.AppendLine($"      pid: {w.Pid}");
                        sb.AppendLine($"      command: {Q(w.Command)}");
                        if (w.Terminal is not null) sb.AppendLine($"      terminal: {Q(w.Terminal)}");
                        if (w.TmuxPaneId is not null) sb.AppendLine($"      tmuxPaneId: {Q(w.TmuxPaneId)}");
                        if (w.TmuxSession is not null) sb.AppendLine($"      tmuxSession: {Q(w.TmuxSession)}");
                        if (w.TmuxWindow is not null) sb.AppendLine($"      tmuxWindow: {Q(w.TmuxWindow)}");
                        if (w.WorkingDirectory is not null) sb.AppendLine($"      workingDirectory: {Q(w.WorkingDirectory)}");
                        break;
                    case WslNvimState n:
                        if (n.WorkingDirectory is not null) sb.AppendLine($"      workingDirectory: {Q(n.WorkingDirectory)}");
                        if (!string.IsNullOrEmpty(n.ExCommand)) sb.AppendLine($"      exCommand: {Q(n.ExCommand)}");
                        break;
                    case UnknownAppState u:
                        foreach (var kv in u.Fields.OrderBy(k => k.Key))
                        {
                            if (!string.Equals(kv.Key, "type", StringComparison.OrdinalIgnoreCase)) sb.AppendLine($"      {kv.Key}: {Q(kv.Value)}");
                        }
                        break;
                }
            }
        }
        return sb.ToString();
    }

    public BookmarkStore Deserialize(string yaml)
    {
        if (string.IsNullOrWhiteSpace(yaml)) return new BookmarkStore(new AppSettings(), Array.Empty<Bookmark>());
        var migrated = MigrateV1Yaml(yaml);
        var bookmarks = new List<Bookmark>();
        AppSettings settings = new();
        Dictionary<string,string>? current = null;
        Dictionary<string,string>? state = null;
        var inState = false;
        foreach (var raw in migrated.Replace("\r\n", "\n").Split('\n'))
        {
            var line = raw.TrimEnd();
            var trimmed = line.Trim();
            if (trimmed.Length == 0 || trimmed.StartsWith('#')) continue;
            if (trimmed == "settings:" || trimmed == "bookmarks:") { inState = false; continue; }
            if (trimmed.StartsWith("- "))
            {
                if (current is not null) bookmarks.Add(BuildBookmark(current, state));
                current = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
                state = null;
                inState = false;
                var rest = trimmed[2..];
                AddKeyValue(current, rest);
                continue;
            }
            if (trimmed == "state:") { state = new(StringComparer.OrdinalIgnoreCase); inState = true; continue; }
            if (current is null)
            {
                var kv = SplitKeyValue(trimmed);
                if (kv is { } s)
                {
                    settings = s.Key switch
                    {
                        "bookmarkListColumns" => settings with { BookmarkListColumns = int.TryParse(s.Value, out var n) ? n : settings.BookmarkListColumns },
                        "cmdMapping" => settings with { CmdMapping = Enum.TryParse<CmdMapping>(s.Value, true, out var cm) ? cm : CmdMapping.Undecided },
                        "togglePanel" => TryApplyTogglePanel(settings, Uq(s.Value)),
                        "hotkeyKey" => settings with { Hotkey = (settings.Hotkey ?? new HotkeySettings()) with { Key = Uq(s.Value) } },
                        "hotkeyModifiers" => settings with { Hotkey = (settings.Hotkey ?? new HotkeySettings()) with { Modifiers = ParseModifiers(Uq(s.Value)) } },
                        "panelWidth" => settings with { PanelWidth = double.TryParse(Uq(s.Value), NumberStyles.Float, CultureInfo.InvariantCulture, out var w) ? w : settings.PanelWidth },
                        "panelHeight" => settings with { PanelHeight = double.TryParse(Uq(s.Value), NumberStyles.Float, CultureInfo.InvariantCulture, out var h) ? h : settings.PanelHeight },
                        "listFontSize" => settings with { ListFontSize = double.TryParse(Uq(s.Value), NumberStyles.Float, CultureInfo.InvariantCulture, out var fs) ? fs : settings.ListFontSize },
                        "fontName" => settings with { FontName = Uq(s.Value) },
                        "displayNumber" => settings with { DisplayNumber = int.TryParse(Uq(s.Value), out var dn) ? dn : settings.DisplayNumber },
                        "autoExecuteOnSingleResult" => settings with { AutoExecuteOnSingleResult = ParseBool(s.Value) },
                        "autoExecuteDelay" => settings with { AutoExecuteDelay = double.TryParse(Uq(s.Value), NumberStyles.Float, CultureInfo.InvariantCulture, out var ad) ? ad : settings.AutoExecuteDelay },
                        "directNumberKeys" => settings with { DirectNumberKeys = ParseBool(s.Value) },
                        "showAIAgentShortcut" => settings with { ShowAIAgentShortcut = ParseBool(s.Value) },
                        "showTmuxAgents" => settings with { ShowTmuxAgents = ParseBool(s.Value) },
                        "showWslAgents" => settings with { ShowWslAgents = ParseBool(s.Value) },
                        "openSessionPullRequest" => settings with { OpenSessionPullRequestHotkey = Uq(s.Value) },
                        "forceReloadAgents" => settings with { ForceReloadAgentsHotkey = Uq(s.Value) },
                        "imeRestoreEnabled" => settings with { ImeRestoreEnabled = ParseBool(s.Value) ?? false },
                        "virtuawinEnabled" => settings with { VirtuaWinEnabled = ParseBool(s.Value) ?? false },
                        "browserCdpEnabled" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { Enabled = ParseBool(s.Value) ?? false } },
                        "browserCdpEndpoint" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { Endpoint = Uq(s.Value) } },
                        "browserCdpProfilePath" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { ProfilePath = Uq(s.Value) } },
                        "browserCdpRequireProfileMarker" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { RequireProfileMarker = ParseBool(s.Value) ?? true } },
                        "browserCdpRequireKnownBrowserOwner" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { RequireKnownBrowserOwner = ParseBool(s.Value) ?? true } },
                        "browserCdpMarkerFileName" => settings with { BrowserCdp = (settings.BrowserCdp ?? new BrowserCdpSettings()) with { MarkerFileName = Uq(s.Value) } },
                        "wslEnabled" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { Enabled = ParseBool(s.Value) ?? false } },
                        "wslDistribution" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { Distribution = Uq(s.Value) } },
                        "wslUser" => settings with { Wsl = (settings.Wsl ?? new WslSettings()) with { User = Uq(s.Value) } },
                        _ => settings
                    };
                }
            }
            else AddKeyValue(inState ? state! : current, trimmed);
        }
        if (current is not null) bookmarks.Add(BuildBookmark(current, state));
        return new BookmarkStore(settings, bookmarks);
    }

    public string MigrateV1Yaml(string yaml)
    {
        // V1 bookmarks used title/url at the item level. Do not rewrite those
        // substrings inside state keys (urlPattern, urlPrefix) or state title.
        var lines = yaml.Replace("\r\n", "\n").Split('\n');
        var inState = false;
        for (var i = 0; i < lines.Length; i++)
        {
            var trimmed = lines[i].Trim();
            if (trimmed.StartsWith("- ") || trimmed is "settings:" or "bookmarks:") inState = false;
            if (trimmed == "state:") { inState = true; continue; }
            if (inState) continue;
            lines[i] = System.Text.RegularExpressions.Regex.Replace(
                lines[i],
                @"^(\s*(?:- )?)title:",
                "$1id:");
            lines[i] = System.Text.RegularExpressions.Regex.Replace(
                lines[i],
                @"^(\s*(?:- )?)url:",
                "$1context:");
        }
        return string.Join("\n", lines);
    }

    private static Bookmark BuildBookmark(Dictionary<string,string> d, Dictionary<string,string>? s)
    {
        var id = Get(d, "id", Get(d, "title", "untitled"));
        var app = Get(d, "appName", Get(d, "app", "Unknown"));
        var context = Get(d, "context", Get(d, "url", string.Empty));
        var known = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "id", "title", "appName", "app", "context", "url", "bundleIdPattern", "shortcut", "noShortcut", "lowPriority", "executeOnToggleRepress" };
        var unknown = d.Where(kv => !known.Contains(kv.Key)).ToDictionary(kv => kv.Key, kv => Uq(kv.Value), StringComparer.OrdinalIgnoreCase);
        AppState? state = null;
        if (s is not null && s.TryGetValue("type", out var type))
        {
            state = type switch
            {
                "browser" => new BrowserAppState(Get(s, "url", context), GetN(s,"urlPrefix"), GetN(s,"urlPattern"), GetN(s,"title"), int.TryParse(GetN(s,"tabIndex"), out var ti) ? ti : null),
                "app" => new AppOnlyState(GetN(s,"windowTitle")),
                "tmux" => new TmuxPaneState(Get(s,"session",""), Get(s,"window",""), Get(s,"paneId","")),
                "wslProcess" => new WslProcessState(
                    int.TryParse(Get(s, "pid", "0"), out var pid) ? pid : 0,
                    Get(s, "command", ""),
                    GetN(s, "terminal"),
                    GetN(s, "tmuxPaneId"),
                    GetN(s, "tmuxSession"),
                    GetN(s, "tmuxWindow"),
                    GetN(s, "workingDirectory")),
                "wslNvim" or "itermNvim" => new WslNvimState(GetN(s, "workingDirectory"), GetN(s, "exCommand") ?? string.Empty),
                "floatingWindows" => new FloatingWindowsState(Array.Empty<string>()),
                _ => AppState.Unknown(type, s)
            };
        }
        return new Bookmark(id, app, context, state, GetN(d,"bundleIdPattern"), GetN(d,"shortcut"), ParseBool(GetN(d,"noShortcut")) ?? false, ParseBool(GetN(d,"lowPriority")) ?? false, UnknownFields: unknown.Count == 0 ? null : unknown, ExecuteOnToggleRepress: ParseBool(GetN(d,"executeOnToggleRepress")) ?? false);
    }

    private static AppSettings TryApplyTogglePanel(AppSettings settings, string text)
    {
        try
        {
            var parsed = HotkeyParser.Parse(text);
            return settings with { Hotkey = new HotkeySettings(parsed.Key, parsed.Modifiers) };
        }
        catch (ArgumentException)
        {
            return settings;
        }
    }

    private static void AddKeyValue(Dictionary<string,string> d, string text)
    {
        if (SplitKeyValue(text) is { } kv) d[kv.Key] = Uq(kv.Value);
    }
    private static (string Key,string Value)? SplitKeyValue(string text)
    {
        var idx = text.IndexOf(':');
        if (idx < 0) return null;
        return (text[..idx].Trim(), text[(idx+1)..].Trim());
    }
    private static string Get(Dictionary<string,string> d, string k, string fallback) => d.TryGetValue(k, out var v) ? Uq(v) : fallback;
    private static string? GetN(Dictionary<string,string> d, string k) => d.TryGetValue(k, out var v) ? Uq(v) : null;
    private static bool? ParseBool(string? v) => bool.TryParse(v, out var b) ? b : null;
    private static HotkeyModifiers ParseModifiers(string value)
    {
        HotkeyModifiers mods = HotkeyModifiers.None;
        foreach (var part in value.Split(new[] { '+', ',', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            mods |= Enum.TryParse<HotkeyModifiers>(part, true, out var parsed) ? parsed : HotkeyModifiers.None;
        }
        return mods == HotkeyModifiers.None ? new HotkeySettings().Modifiers : mods;
    }
    private static string Q(string s) => s.Any(ch => char.IsWhiteSpace(ch) || ch is ':' or '#' or '"') ? '"' + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + '"' : s;
    private static string Uq(string s) => s.Trim().Trim('"').Replace("\\\"", "\"").Replace("\\\\", "\\");
}
