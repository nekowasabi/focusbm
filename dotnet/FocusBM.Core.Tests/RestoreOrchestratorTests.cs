using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class RestoreOrchestratorTests
{
    [Fact] public async Task BrowserFailure_FallsBackToActivationAsPartial()
    {
        var orch = new BookmarkRestoreOrchestrator(new FakeActivation(), new FakeBrowser(OperationResult.VisibleError(OperationStatus.Unsupported, "cdp disabled")));
        var result = await orch.RestoreAsync(new Bookmark("b", "Chrome", "ctx", new BrowserAppState("https://example.test")));
        Assert.Equal(OperationStatus.Partial, result.Status);
        Assert.True(result.IsSuccess);
    }
    [Fact]
    public async Task BrowserSuccess_DoesNotRunUnnecessaryAppActivation()
    {
        var activation = new FakeActivation();
        var orch = new BookmarkRestoreOrchestrator(activation, new FakeBrowser(OperationResult.Success("tab activated")));

        var result = await orch.RestoreAsync(new Bookmark("b", "Chrome", "ctx", new BrowserAppState("https://example.test")));

        Assert.True(result.IsSuccess);
        Assert.Equal(0, activation.Calls);
    }

    [Fact]
    public async Task Restore_EmitsTimingSamples()
    {
        var samples = new RecordingTimingSink();
        var orch = new BookmarkRestoreOrchestrator(new FakeActivation(), timing: samples);

        await orch.RestoreAsync(new Bookmark("a", "notepad", "ctx"));

        Assert.Contains(samples.Items, sample => sample.Stage == "start");
        Assert.Contains(samples.Items, sample => sample.Stage == "complete");
    }

    private sealed class FakeActivation : IActivationService
    {
        public int Calls { get; private set; }

        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default)
        {
            Calls++;
            return Task.FromResult(OperationResult.Success("activated", target));
        }
    }

    private sealed class RecordingTimingSink : IRestoreTimingSink
    {
        public List<RestoreTimingSample> Items { get; } = [];

        public void Record(RestoreTimingSample sample) => Items.Add(sample);
    }

    private sealed class FakeBrowser : IBrowserTabService { private readonly OperationResult _result; public FakeBrowser(OperationResult result)=>_result=result; public Task<OperationResult> RestoreTabAsync(BrowserAppState state, CancellationToken cancellationToken = default)=>Task.FromResult(_result); }
}

public class ActivationTargetBuildTests
{
    [Fact] public void AppOnlyState_WindowTitleIsCarriedToActivationTarget()
    {
        var target = Assert.IsType<ActivationTarget.App>(BookmarkRestoreOrchestrator.BuildTarget(
            new Bookmark("doc", "notepad", "ctx", new AppOnlyState("memo.txt"))));
        Assert.Equal("memo.txt", target.WindowTitle);
    }

    [Fact]
    public void BrowserState_UrlPatternIsPreferredForOpen()
    {
        var target = Assert.IsType<ActivationTarget.BrowserTab>(BookmarkRestoreOrchestrator.BuildTarget(
            new Bookmark("github", "Firefox", "dev", new BrowserAppState("dev", UrlPattern: "github.com"))));
        Assert.Equal("github.com", target.UrlPattern);
        Assert.Equal("https://github.com", BrowserOpenUrl.Resolve(target.Url, target.UrlPattern));
    }
}

public class WslProcessRestoreTests
{
    [Fact]
    public async Task WslProcessState_ReturnsUnsupportedWithoutActivatingAnApp()
    {
        var activation = new TrackingActivation();
        var orchestrator = new BookmarkRestoreOrchestrator(activation);

        var result = await orchestrator.RestoreAsync(new Bookmark("wsl:42", "wsl", "claude", new WslProcessState(42, "claude")));

        Assert.Equal(OperationStatus.Unsupported, result.Status);
        Assert.Equal(0, activation.Calls);
    }

    [Fact]
    public async Task WslProcessState_UsesWslFocusService()
    {
        var activation = new TrackingActivation();
        var focus = new TrackingWslFocus();
        var orchestrator = new BookmarkRestoreOrchestrator(activation, wsl: focus);
        var bookmark = new Bookmark("wsl:42", "wsl", "claude", new WslProcessState(42, "claude"));

        var result = await orchestrator.RestoreAsync(bookmark);

        Assert.True(result.IsSuccess);
        Assert.Same(bookmark.State, focus.Process);
        Assert.Equal(0, activation.Calls);
    }

    private sealed class TrackingActivation : IActivationService
    {
        public int Calls { get; private set; }

        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default)
        {
            Calls++;
            return Task.FromResult(OperationResult.Success("activated", target));
        }
    }

    private sealed class TrackingWslFocus : IWslProcessFocusService
    {
        public WslProcessState? Process { get; private set; }

        public Task<OperationResult> FocusProcessAsync(WslProcessState process, CancellationToken cancellationToken = default)
        {
            Process = process;
            return Task.FromResult(OperationResult.Success("focused"));
        }
    }
}

public class WslNvimRestoreTests
{
    [Fact]
    public async Task WslNvimState_UsesNvimService()
    {
        var nvim = new TrackingNvim();
        var orchestrator = new BookmarkRestoreOrchestrator(new TrackingActivation(), nvim: nvim);

        var result = await orchestrator.RestoreAsync(new Bookmark("nvim", "tmux", "editor", new WslNvimState()));

        Assert.True(result.IsSuccess);
        Assert.NotNull(nvim.State);
    }

    [Fact]
    public async Task WslNvimState_ActivatesHostApp()
    {
        var nvim = new TrackingNvim();
        var activation = new TrackingActivation();
        var orchestrator = new BookmarkRestoreOrchestrator(activation, nvim: nvim);

        var result = await orchestrator.RestoreAsync(new Bookmark("focusbm-nvim", "Windows Terminal", "dev", new WslNvimState()));

        Assert.True(result.IsSuccess);
        Assert.NotNull(nvim.State);
        var app = Assert.IsType<ActivationTarget.App>(activation.Target);
        Assert.Equal("Windows Terminal", app.AppName);
        Assert.Contains("activated", result.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task WslNvimState_FailsWhenHostAppActivationFails()
    {
        var orchestrator = new BookmarkRestoreOrchestrator(new FailingActivation(), nvim: new TrackingNvim());

        var result = await orchestrator.RestoreAsync(new Bookmark("focusbm-nvim", "Windows Terminal", "dev", new WslNvimState()));

        Assert.False(result.IsSuccess);
    }

    [Fact]
    public async Task WslNvimState_ActivatesHostAppEvenWhenPaneFocusFails()
    {
        var activation = new TrackingActivation();
        var orchestrator = new BookmarkRestoreOrchestrator(activation, nvim: new FailingNvim());

        var result = await orchestrator.RestoreAsync(new Bookmark("focusbm-nvim", "Windows Terminal", "dev", new WslNvimState()));

        Assert.Equal(OperationStatus.Partial, result.Status);
        Assert.True(result.IsSuccess);
        var app = Assert.IsType<ActivationTarget.App>(activation.Target);
        Assert.Equal("Windows Terminal", app.AppName);
    }

    private sealed class TrackingActivation : IActivationService
    {
        public ActivationTarget? Target { get; private set; }

        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default)
        {
            Target = target;
            return Task.FromResult(OperationResult.Success("activated", target));
        }
    }

    private sealed class FailingActivation : IActivationService
    {
        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default) =>
            Task.FromResult(OperationResult.VisibleError(OperationStatus.Failed, "front failed"));
    }

    private sealed class TrackingNvim : IWslNvimService
    {
        public WslNvimState? State { get; private set; }

        public Task<OperationResult> RestoreAsync(WslNvimState nvim, CancellationToken cancellationToken = default)
        {
            State = nvim;
            return Task.FromResult(OperationResult.Success("WSL tmux Neovim pane focused"));
        }
    }

    private sealed class FailingNvim : IWslNvimService
    {
        public Task<OperationResult> RestoreAsync(WslNvimState nvim, CancellationToken cancellationToken = default) =>
            Task.FromResult(OperationResult.VisibleError(OperationStatus.NotFound, "WSL tmux Neovim pane was not found"));
    }
}

public class RestoreFallbackTests
{
    [Fact] public async Task BrowserFailureFallsBackToAppActivationAsPartial()
    {
        var orch = new BookmarkRestoreOrchestrator(new SucceedingActivation(), new FailingBrowser());
        var result = await orch.RestoreAsync(new Bookmark("web", "chrome", "ctx", new BrowserAppState("https://example.test")));
        Assert.Equal(OperationStatus.Partial, result.Status);
        Assert.True(result.IsSuccess);
    }

    private sealed class SucceedingActivation : IActivationService
    {
        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default) => Task.FromResult(OperationResult.Success("activated", target));
    }
    private sealed class FailingBrowser : IBrowserTabService
    {
        public Task<OperationResult> RestoreTabAsync(BrowserAppState state, CancellationToken cancellationToken = default) => Task.FromResult(OperationResult.VisibleError(OperationStatus.NotFound, "no tab"));
    }
}
