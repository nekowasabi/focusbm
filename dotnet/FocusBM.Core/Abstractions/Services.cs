namespace FocusBM.Core;

public interface IActivationService
{
    Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default);
}

public interface IHotkeyService : IAsyncDisposable
{
    event EventHandler? Pressed;
    Task<OperationResult> RegisterAsync(ParsedHotkey hotkey, CancellationToken cancellationToken = default);
    Task UnregisterAsync(CancellationToken cancellationToken = default);
}

public interface IImeService
{
    Task<OperationResult> DisableImeAsync(CancellationToken cancellationToken = default);
    Task<OperationResult> RestoreImeAsync(CancellationToken cancellationToken = default);
}

public interface IBrowserTabService
{
    Task<OperationResult> RestoreTabAsync(BrowserAppState state, CancellationToken cancellationToken = default);
}

public interface ITmuxService
{
    Task<IReadOnlyList<TmuxPaneInfo>> ListPanesAsync(CancellationToken cancellationToken = default);
    Task<OperationResult> FocusPaneAsync(TmuxPaneState pane, CancellationToken cancellationToken = default);
}

public enum TmuxAgentStatus
{
    Running,
    PlanMode,
    AcceptEdits,
    Idle
}

public sealed record TmuxPaneInfo(
    string Session,
    string Window,
    string PaneId,
    string? CurrentCommand = null,
    string? Title = null,
    string? Status = null,
    string? CurrentDirectory = null,
    string? WindowName = null,
    TmuxAgentStatus AgentStatus = TmuxAgentStatus.Idle);

public interface IWslProcessFocusService
{
    Task<OperationResult> FocusProcessAsync(WslProcessState process, CancellationToken cancellationToken = default);
}

public interface IWslNvimService
{
    Task<OperationResult> RestoreAsync(WslNvimState nvim, CancellationToken cancellationToken = default);
}

public interface IProcessRunner
{
    Task<ProcessRunResult> RunAsync(string fileName, IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken = default);
}

public sealed record ProcessRunResult(int ExitCode, string StandardOutput, string StandardError, bool TimedOut);


public interface IForegroundContextService
{
    Task<ForegroundContextResult> CaptureAsync(AppSettings settings, CancellationToken cancellationToken = default);
}

public sealed record ForegroundContextResult(OperationStatus Status, string Message, string AppName, string Context, string? BundleIdPattern = null, AppState? State = null)
{
    public bool IsSuccess => Status == OperationStatus.Success;
}


public interface IIconProvider
{
    Task<IconResult> GetIconAsync(string appNameOrPath, CancellationToken cancellationToken = default);
}

public sealed record IconResult(OperationStatus Status, string Message, byte[]? PngBytes = null, string? SourcePath = null)
{
    public bool IsSuccess => Status == OperationStatus.Success && PngBytes is { Length: > 0 };
}
