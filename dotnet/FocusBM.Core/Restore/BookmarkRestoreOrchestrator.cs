namespace FocusBM.Core;

public sealed class BookmarkRestoreOrchestrator
{
    private readonly IActivationService _activation;
    private readonly IBrowserTabService? _browser;
    private readonly ITmuxService? _tmux;
    private readonly IWslProcessFocusService? _wsl;
    private readonly IRestoreTimingSink? _timing;
    private readonly IWslNvimService? _nvim;

    public BookmarkRestoreOrchestrator(
        IActivationService activation,
        IBrowserTabService? browser = null,
        ITmuxService? tmux = null,
        IWslProcessFocusService? wsl = null,
        IRestoreTimingSink? timing = null,
        IWslNvimService? nvim = null)
    {
        _activation = activation;
        _browser = browser;
        _tmux = tmux;
        _wsl = wsl;
        _timing = timing;
        _nvim = nvim;
    }

    public async Task<OperationResult> RestoreAsync(Bookmark bookmark, CancellationToken cancellationToken = default)
    {
        var timing = new RestoreTimingScope($"restore:{bookmark.Id}:{bookmark.State?.Type ?? "app"}", _timing);
        timing.Mark("start");
        var target = BuildTarget(bookmark);
        switch (bookmark.State)
        {
            case BrowserAppState b when _browser is not null:
                var browser = await _browser.RestoreTabAsync(b, cancellationToken).ConfigureAwait(false);
                if (!browser.IsSuccess)
                {
                    var fallback = await _activation.ActivateAsync(target, cancellationToken).ConfigureAwait(false);
                    var result = fallback.IsSuccess
                        ? new OperationResult(OperationStatus.Partial, $"Browser tab restore failed ({browser.Status}: {browser.Message}); app activation succeeded: {fallback.Message}", target)
                        : browser;
                    timing.Mark("complete", result.Status.ToString());
                    return result;
                }
                timing.Mark("complete", browser.Status.ToString());
                return browser;
            case TmuxPaneState t when _tmux is not null:
                var tmuxResult = await _tmux.FocusPaneAsync(t, cancellationToken).ConfigureAwait(false);
                timing.Mark("complete", tmuxResult.Status.ToString());
                return tmuxResult;
            case WslProcessState w when _wsl is not null:
                var wslResult = await _wsl.FocusProcessAsync(w, cancellationToken).ConfigureAwait(false);
                timing.Mark("complete", wslResult.Status.ToString());
                return wslResult;
            case WslProcessState:
                var unsupported = OperationResult.VisibleError(OperationStatus.Unsupported, "WSL process focus is not supported");
                timing.Mark("complete", unsupported.Status.ToString());
                return unsupported;
            case WslNvimState n when _nvim is not null:
                // Activate the host app first while we still have foreground rights (before any wsl.exe await).
                var appFocus = await _activation.ActivateAsync(target, cancellationToken);
                if (!appFocus.IsSuccess)
                {
                    timing.Mark("complete", appFocus.Status.ToString());
                    return appFocus;
                }
                var nvimResult = await _nvim.RestoreAsync(n, cancellationToken);
                var combined = nvimResult.IsSuccess
                    ? OperationResult.Success($"{appFocus.Message}; {nvimResult.Message}", target)
                    : new OperationResult(OperationStatus.Partial, $"{appFocus.Message}; pane focus failed: {nvimResult.Message}", target);
                timing.Mark("complete", combined.Status.ToString());
                return combined;
            case WslNvimState:
                var nvimUnsupported = OperationResult.VisibleError(OperationStatus.Unsupported, "WSL Neovim restore is not supported");
                timing.Mark("complete", nvimUnsupported.Status.ToString());
                return nvimUnsupported;
        }
        var activation = await _activation.ActivateAsync(target, cancellationToken).ConfigureAwait(false);
        timing.Mark("complete", activation.Status.ToString());
        return activation;
    }

    public static ActivationTarget BuildTarget(Bookmark bookmark) => bookmark.State switch
    {
        BrowserAppState b => new ActivationTarget.BrowserTab(bookmark.AppName, b.Url, b.TabIndex, b.UrlPrefix, b.UrlPattern),
        TmuxPaneState t => new ActivationTarget.TmuxPane(t.Session, t.Window, t.PaneId),
        WslProcessState => new ActivationTarget.App(bookmark.AppName, bookmark.BundleIdPattern),
        WslNvimState => new ActivationTarget.App(bookmark.AppName, bookmark.BundleIdPattern),
        AppOnlyState a => new ActivationTarget.App(bookmark.AppName, bookmark.BundleIdPattern, a.WindowTitle),
        FloatingWindowsState f => new ActivationTarget.App(bookmark.AppName, bookmark.BundleIdPattern, f.WindowTitles.FirstOrDefault()),
        _ => new ActivationTarget.App(bookmark.AppName, bookmark.BundleIdPattern)
    };
}
