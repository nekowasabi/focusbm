namespace FocusBM.Core;

public abstract record ActivationTarget
{
    public sealed record None : ActivationTarget;
    public sealed record App(string AppName, string? BundleIdPattern = null, string? WindowTitle = null) : ActivationTarget;
    public sealed record BrowserTab(string AppName, string Url, int? TabIndex = null, string? UrlPrefix = null, string? UrlPattern = null) : ActivationTarget;
    public sealed record TmuxPane(string Session, string Window, string PaneId) : ActivationTarget;
}

public enum OperationStatus { Success, NotFound, Duplicate, Unsupported, Timeout, ValidationError, NoOp, Failed, Partial }

public sealed record OperationResult(OperationStatus Status, string Message, ActivationTarget? Target = null)
{
    public bool IsSuccess => Status is OperationStatus.Success or OperationStatus.NoOp or OperationStatus.Partial;
    public static OperationResult Success(string message, ActivationTarget? target = null) => new(OperationStatus.Success, message, target);
    public static OperationResult VisibleError(OperationStatus status, string message) => new(status, message, null);
}
