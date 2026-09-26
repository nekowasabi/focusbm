using System.Diagnostics;
using System.Windows;
using System.Windows.Interop;
using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Activation;
using FocusBM.Infrastructure.Windows.Hotkeys;
using FocusBM.Infrastructure.Windows.Browser;
using FocusBM.Infrastructure.Windows.Processes;
using FocusBM.Infrastructure.Windows.Wsl;
using Forms = System.Windows.Forms;
using System.Windows.Threading;

namespace FocusBM.App.Wpf;

public partial class App : System.Windows.Application
{
    private MainWindow? _window;
    private Forms.NotifyIcon? _notifyIcon;
    private WindowsHotkeyService? _hotkeyService;
    private WindowsHotkeyService? _forceReloadHotkeyService;
    private HwndSource? _hotkeyHwnd;
    private SearchPanelViewModel? _viewModel;
    private AppSettings _settings = new();
    private readonly WindowsImeService _imeService = new();
    private WslProcessService? _wslService;
    private WslAgentDiscoveryService? _agentDiscovery;
    private WslSettings? _agentDiscoverySettings;
    private DispatcherTimer? _agentStatusTimer;
    private bool _agentRefreshInProgress;
    private int _agentRefreshGeneration;
    private DispatcherTimer? _pullRequestTimer;
    private bool _pullRequestRefreshInProgress;
    private readonly Dictionary<string, (string Url, DateTimeOffset FetchedAt)> _pullRequestCache = new(StringComparer.Ordinal);
    private readonly Dictionary<string, DateTimeOffset> _pullRequestFailures = new(StringComparer.Ordinal);
    private static readonly TimeSpan PullRequestCacheTtl = TimeSpan.FromMinutes(5);

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (e.Args.Any(a => string.Equals(a, "--self-test", StringComparison.OrdinalIgnoreCase)))
        {
            Shutdown(await RunSelfTestAsync(e.Args));
            return;
        }
        var repo = new YamlBookmarkRepository(BookmarkPaths.ResolveDefaultYamlPath());
        // Why: YAML-only at startup. WSL/tmux listing is slow; AgentRefreshSchedule fills agents in the background.
        var store = await repo.LoadAsync();
        var settings = store.Settings ?? new AppSettings();
        _settings = settings;
        FocusBmLog.Open(BookmarkPaths.ResolveDefaultLogPath());
        FocusBmLog.Write("app", "startup");
        var timing = new TraceRestoreTimingSink();
        var activation = new WindowsActivationService(settings.VirtuaWinEnabled, timing);
        var browser = settings.BrowserCdp?.Enabled == true ? new ChromiumCdpTabService(settings, timing: timing) : null;
        var runner = new DefaultProcessRunner(timing);
        var tmux = settings.Wsl?.Enabled == true ? new WslTmuxService(settings.Wsl, runner, timing) : null;
        var wsl = settings.Wsl?.Enabled == true ? new WslProcessService(settings.Wsl, runner, activation, timing) : null;
        _wslService = wsl;
        _agentDiscovery = settings.Wsl?.Enabled == true ? new WslAgentDiscoveryService(settings.Wsl, timing) : null;
        _agentDiscoverySettings = settings.Wsl;
        var orchestrator = new BookmarkRestoreOrchestrator(activation, browser, tmux, wsl, timing, tmux);
        _viewModel = new SearchPanelViewModel(
            orchestrator.RestoreAsync,
            wsl is null ? null : ResolvePullRequestAsync);
        _viewModel.Load(store);

        _window = new MainWindow(_viewModel);
        _window.ApplyPanelLayout(settings);
        _window.Hide();
        SetupTray();
        await SetupHotkeyAsync(settings);
        ShowPanel();
        StartPullRequestRefresh();
        _ = RefreshDynamicEntriesAsync();
    }


    private static async Task<int> RunSelfTestAsync(string[] args)
    {
        try
        {
            var repo = new YamlBookmarkRepository(BookmarkPaths.ResolveDefaultYamlPath());
            var store = await repo.LoadAsync();
            if (store.Bookmarks.Count == 0)
            {
                store = store with
                {
                    Settings = store.Settings ?? new AppSettings(),
                    Bookmarks = new[] { new Bookmark("self-test", "notepad", "self test", new AppOnlyState("Untitled"), Shortcut: "s") }
                };
                await repo.SaveAsync(store);
            }
            var vm = new SearchPanelViewModel();
            vm.Load(store);
            if (vm.Results.Count == 0 && vm.ShortcutBar.Count == 0) return 11;
            vm.Query = store.Bookmarks[0].Id;
            if (vm.Results.Count == 0) return 12;
            vm.Query = string.Empty;
            var shortcut = vm.Shortcuts.FirstOrDefault()?.Shortcut;
            if (!string.IsNullOrWhiteSpace(shortcut))
            {
                var result = await vm.RestoreShortcutAsync(shortcut);
                if (result is null || !result.IsSuccess) return 13;
            }
            return 0;
        }
        catch
        {
            return 99;
        }
    }

    private async Task SetupHotkeyAsync(AppSettings settings)
    {
        _hotkeyHwnd ??= CreateHotkeyHwnd();
        var hwnd = _hotkeyHwnd.Handle;
        _hotkeyService = new WindowsHotkeyService(hwnd);
        _hotkeyService.Pressed += (_, _) => Dispatcher.BeginInvoke(() =>
        {
            FocusBmLog.Write("hotkey", "togglePanel");
            _ = HandleTogglePanelHotkeyAsync();
        });
        var parsed = BuildParsedHotkey(settings);
        var result = await _hotkeyService.RegisterAsync(parsed);
        FocusBmLog.Write("hotkey", result.IsSuccess ? $"registered {parsed.Modifiers}+{parsed.Key}" : result.Message);
        if (!result.IsSuccess && _window?.DataContext is SearchPanelViewModel vm)
        {
            vm.SetStatus(result.Message);
        }

        _forceReloadHotkeyService = new WindowsHotkeyService(hwnd);
        _forceReloadHotkeyService.Pressed += (_, _) => _ = ForceReloadAgentsAsync();
        ParsedHotkey reloadHotkey;
        try
        {
            reloadHotkey = HotkeyParser.Parse(settings.ForceReloadAgentsHotkey, settings.CmdMapping);
        }
        catch (ArgumentException)
        {
            reloadHotkey = HotkeyParser.Parse("ctrl+alt+r");
        }
        var reloadResult = await _forceReloadHotkeyService.RegisterAsync(reloadHotkey);
        if (!reloadResult.IsSuccess && _window?.DataContext is SearchPanelViewModel reloadVm)
        {
            reloadVm.SetStatus(reloadResult.Message);
        }
    }

    // Why: RegisterHotKey on the panel HWND dies after Hide/Escape/Alt+Tab. A message-only window stays alive for the process lifetime.
    private HwndSource CreateHotkeyHwnd()
    {
        var parameters = new HwndSourceParameters("FocusBMHotkeyHost")
        {
            Width = 1,
            Height = 1,
            ParentWindow = new IntPtr(-3)
        };
        var source = new HwndSource(parameters);
        source.AddHook(WndProc);
        return source;
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        handled = (_hotkeyService?.ProcessWindowMessage(msg, wParam) == true)
            || (_forceReloadHotkeyService?.ProcessWindowMessage(msg, wParam) == true);
        return IntPtr.Zero;
    }


    private static ParsedHotkey BuildParsedHotkey(AppSettings settings)
    {
        var hotkey = settings.EffectiveHotkey;
        var modifiers = hotkey.Modifiers;
        if (modifiers.HasFlag(HotkeyModifiers.Command))
        {
            modifiers &= ~HotkeyModifiers.Command;
            modifiers |= settings.CmdMapping switch
            {
                CmdMapping.MacCommandToControl => HotkeyModifiers.Control,
                CmdMapping.MacCommandToWindows => HotkeyModifiers.Windows,
                _ => HotkeyModifiers.Command
            };
        }
        return new ParsedHotkey(hotkey.Key, modifiers);
    }

    private void SetupTray()
    {
        // Why: mac uses the template symbol bookmark.fill, which follows menu bar light/dark; pick the matching glyph for the taskbar theme.
        var trayIconName = Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 0) is 1 ? "tray-light.ico" : "tray-dark.ico";
        _notifyIcon = new Forms.NotifyIcon
        {
            Text = "focusBM",
            Icon = new System.Drawing.Icon(typeof(App).Assembly.GetManifestResourceStream(trayIconName)!, Forms.SystemInformation.SmallIconSize),
            Visible = true,
            ContextMenuStrip = new Forms.ContextMenuStrip()
        };
        _notifyIcon.ContextMenuStrip.Items.Add("開く", null, (_, _) => ShowPanel());
        _notifyIcon.ContextMenuStrip.Items.Add("ログを開く", null, (_, _) => OpenLog());
        _notifyIcon.ContextMenuStrip.Items.Add("再読み込み", null, async (_, _) => await ReloadAsync());
        _notifyIcon.ContextMenuStrip.Items.Add("終了", null, async (_, _) => await ShutdownAsync());
        _notifyIcon.DoubleClick += (_, _) => ShowPanel();
    }

    private void ShowPanel()
    {
        FocusBmLog.Write("panel", "present");
        if (_window is null) return;
        _window.PlaceOnConfiguredDisplay();
        _window.Present();
        StartAgentStatusMonitoring();
        if (_settings.ImeRestoreEnabled) _ = _imeService.DisableImeAsync();
    }

    private async Task HandleTogglePanelHotkeyAsync()
    {
        // Why: Match macOS behavior: re-press confirms the configured target before falling back to the selected row.
        if (_window?.IsVisible == true) await _window.ExecuteToggleRepressAsync();
        else ShowPanel();
    }

    private static void OpenLog()
    {
        var path = FocusBmLog.Path;
        if (string.IsNullOrWhiteSpace(path) || !System.IO.File.Exists(path)) return;
        Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
    }


    private async Task<BookmarkStore> LoadStoreWithDynamicEntriesAsync(YamlBookmarkRepository repo)
    {
        var store = await repo.LoadAsync();
        var settings = store.Settings ?? new AppSettings();
        var bookmarks = store.Bookmarks.ToList();
        var showTmux = settings.Wsl?.Enabled == true && settings.EffectiveShowTmuxAgents;
        var showWsl = settings.Wsl?.Enabled == true && settings.EffectiveShowWslAgents;
        if (showTmux || showWsl)
        {
            var discovery = EnsureAgentDiscovery(settings.Wsl!);
            var snapshot = discovery is null
                ? AgentDiscoverySnapshot.Empty
                : await discovery.TryDiscoverAsync(includeTmuxDescendants: true, includeTmux: showTmux).ConfigureAwait(false);
            bookmarks.AddRange(AgentSearchItems.Build(
                snapshot.Panes,
                snapshot.Processes,
                showTmux,
                showWsl,
                snapshot.TmuxDiscoverySucceeded,
                snapshot.SessionTerminals,
                snapshot.ProcessDiscoverySucceeded));
        }
        return store with { Bookmarks = bookmarks };
    }

    // Why: bookmarks.yml may change WSL settings between reloads; rebuild the worker when they differ.
    private WslAgentDiscoveryService? EnsureAgentDiscovery(WslSettings settings)
    {
        if (_agentDiscovery is not null && SameWslSettings(_agentDiscoverySettings, settings)) return _agentDiscovery;
        _agentDiscovery?.Dispose();
        _agentDiscovery = settings.Enabled ? new WslAgentDiscoveryService(settings) : null;
        _agentDiscoverySettings = settings;
        return _agentDiscovery;
    }

    private static bool SameWslSettings(WslSettings? a, WslSettings? b) =>
        a is not null && b is not null
        && a.Enabled == b.Enabled
        && string.Equals(a.Distribution, b.Distribution, StringComparison.Ordinal)
        && string.Equals(a.User, b.User, StringComparison.Ordinal)
        && SameStrings(a.AllowedDistributions, b.AllowedDistributions)
        && SameStrings(a.AllowedUsers, b.AllowedUsers);

    private static bool SameStrings(IReadOnlyList<string>? a, IReadOnlyList<string>? b) =>
        a is null ? b is null : b is not null && a.SequenceEqual(b, StringComparer.Ordinal);

    private async Task<Uri?> ResolvePullRequestAsync(Bookmark bookmark, CancellationToken cancellationToken)
    {
        if (_wslService is null || bookmark.State is not WslProcessState state) return null;
        return await _wslService.ResolvePullRequestUrlAsync(state.Command, state.WorkingDirectory, cancellationToken, state.Pid).ConfigureAwait(false);
    }

    private async Task ForceReloadAgentsAsync()
    {
        if (_window?.IsVisible == true) await RefreshDynamicEntriesAsync();
        else await ReloadAsync();
    }

    internal void StartAgentStatusMonitoring()
    {
        EnsureAgentStatusTimer(AgentRefreshSchedule.VisibleInterval);
        // Why: fresh agent rows must appear immediately when the panel opens, not after one timer interval.
        _ = RefreshDynamicEntriesAsync();
    }

    internal void StopAgentStatusMonitoring() =>
        EnsureAgentStatusTimer(AgentRefreshSchedule.HiddenInterval);

    private void EnsureAgentStatusTimer(TimeSpan interval)
    {
        if (_agentStatusTimer is null)
        {
            _agentStatusTimer = new DispatcherTimer { Interval = interval };
            _agentStatusTimer.Tick += async (_, _) => await RefreshDynamicEntriesAsync();
            _agentStatusTimer.Start();
            return;
        }
        _agentStatusTimer.Interval = interval;
    }

    private void HaltAgentStatusMonitoring()
    {
        _agentRefreshGeneration++;
        _agentStatusTimer?.Stop();
        _agentStatusTimer = null;
    }

    private async Task RefreshDynamicEntriesAsync()
    {
        if (_agentRefreshInProgress || _viewModel is null) return;
        _agentRefreshInProgress = true;
        var generation = ++_agentRefreshGeneration;
        try
        {
            var repo = new YamlBookmarkRepository(BookmarkPaths.ResolveDefaultYamlPath());
            var store = await LoadStoreWithDynamicEntriesAsync(repo);
            if (generation == _agentRefreshGeneration)
            {
                _viewModel.Load(store, announce: false);
                ApplyPullRequestCache();
                var agents = store.Bookmarks.Count(bookmark => bookmark.IsAIAgent);
                FocusBmLog.Write("agents", $"rows={agents}");
            }
        }
        catch
        {
            // Dynamic discovery is optional; a failed refresh must not terminate the tray app.
        }
        finally
        {
            _agentRefreshInProgress = false;
        }
    }

    private void StartPullRequestRefresh()
    {
        if (_pullRequestTimer is not null) return;
        _pullRequestTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(15) };
        _pullRequestTimer.Tick += async (_, _) => await RefreshPullRequestCacheAsync();
        _pullRequestTimer.Start();
        _ = RefreshPullRequestCacheAsync();
    }

    private void StopPullRequestRefresh()
    {
        _pullRequestTimer?.Stop();
        _pullRequestTimer = null;
    }

    private async Task RefreshPullRequestCacheAsync()
    {
        if (_pullRequestRefreshInProgress || _viewModel is null || _wslService is null) return;
        _pullRequestRefreshInProgress = true;
        try
        {
            var now = DateTimeOffset.UtcNow;
            var candidates = _viewModel.PullRequestCandidates
                .Where(state => state.WorkingDirectory is not null && !IsPullRequestCacheFresh(state.WorkingDirectory, now))
                .ToArray();
            using var gate = new SemaphoreSlim(4);
            var service = _wslService;
            var resolved = await Task.WhenAll(candidates.Select(async state =>
            {
                await gate.WaitAsync().ConfigureAwait(false);
                try
                {
                    var directory = state.WorkingDirectory!;
                    var url = await service.ResolvePullRequestUrlAsync(state.Command, directory, processId: state.Pid).ConfigureAwait(false);
                    return (directory, url: url?.AbsoluteUri);
                }
                finally
                {
                    gate.Release();
                }
            })).ConfigureAwait(true);

            var fetchedAt = DateTimeOffset.UtcNow;
            foreach (var result in resolved)
            {
                if (result.url is not null)
                {
                    _pullRequestCache[result.directory] = (result.url, fetchedAt);
                    _pullRequestFailures.Remove(result.directory);
                }
                else
                {
                    _pullRequestFailures[result.directory] = fetchedAt;
                }
            }
            ApplyPullRequestCache();
        }
        catch
        {
            // Pull-request discovery is optional; a failed background refresh is retried on the next interval.
        }
        finally
        {
            _pullRequestRefreshInProgress = false;
        }
    }

    private bool IsPullRequestCacheFresh(string directory, DateTimeOffset now) =>
        (_pullRequestCache.TryGetValue(directory, out var success) && now - success.FetchedAt < PullRequestCacheTtl)
        || (_pullRequestFailures.TryGetValue(directory, out var failure) && now - failure < PullRequestCacheTtl);

    private void ApplyPullRequestCache()
    {
        if (_viewModel is null) return;
        var now = DateTimeOffset.UtcNow;
        _viewModel.ApplyPullRequestCache(_pullRequestCache
            .Where(pair => now - pair.Value.FetchedAt < PullRequestCacheTtl)
            .ToDictionary(pair => pair.Key, pair => pair.Value.Url, StringComparer.Ordinal));
    }

    private async Task ReloadAsync()
    {
        if (_viewModel is null) return;
        var repo = new YamlBookmarkRepository(BookmarkPaths.ResolveDefaultYamlPath());
        var store = await LoadStoreWithDynamicEntriesAsync(repo);
        _settings = store.Settings ?? new AppSettings();
        _viewModel.Load(store);
        _window?.ApplyPanelLayout(_settings);
        ApplyPullRequestCache();
        ShowPanel();
    }

    public async Task RestoreImeIfNeededAsync()
    {
        if (_settings.ImeRestoreEnabled) await _imeService.RestoreImeAsync();
    }

    private async Task ShutdownAsync()
    {
        if (_window is not null) _window.AllowClose = true;
        if (_hotkeyService is not null) await _hotkeyService.DisposeAsync();
        if (_forceReloadHotkeyService is not null) await _forceReloadHotkeyService.DisposeAsync();
        _agentDiscovery?.Dispose();
        _agentDiscovery = null;
        _hotkeyHwnd?.Dispose();
        _hotkeyHwnd = null;
        if (_notifyIcon is not null) { _notifyIcon.Visible = false; _notifyIcon.Dispose(); }
        Shutdown();
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        HaltAgentStatusMonitoring();
        StopPullRequestRefresh();
        _agentDiscovery?.Dispose();
        _agentDiscovery = null;
        if (_window is not null) _window.AllowClose = true;
        if (_hotkeyService is not null) await _hotkeyService.DisposeAsync();
        if (_forceReloadHotkeyService is not null) await _forceReloadHotkeyService.DisposeAsync();
        _hotkeyHwnd?.Dispose();
        _hotkeyHwnd = null;
        if (_notifyIcon is not null) { _notifyIcon.Visible = false; _notifyIcon.Dispose(); }
        base.OnExit(e);
    }
}
