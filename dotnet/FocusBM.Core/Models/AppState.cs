namespace FocusBM.Core;

public abstract record AppState(string Type)
{
    public static AppState Unknown(string type, IReadOnlyDictionary<string,string>? fields = null) => new UnknownAppState(type, fields ?? new Dictionary<string,string>());
}

public sealed record BrowserAppState(
    string Url,
    string? UrlPrefix = null,
    string? UrlPattern = null,
    string? Title = null,
    int? TabIndex = null) : AppState("browser");

public sealed record AppOnlyState(string? WindowTitle = null) : AppState("app");

public sealed record FloatingWindowsState(IReadOnlyList<string> WindowTitles) : AppState("floatingWindows");

public sealed record TmuxPaneState(string Session, string Window, string PaneId) : AppState("tmux");
public sealed record WslProcessState(
    int Pid,
    string Command,
    string? Terminal = null,
    string? TmuxPaneId = null,
    string? TmuxSession = null,
    string? TmuxWindow = null,
    string? WorkingDirectory = null,
    TmuxAgentStatus? AgentStatus = null,
    string? ScreenCapture = null) : AppState("wslProcess");

public sealed record WslNvimState(
    string? WorkingDirectory = null,
    string ExCommand = "") : AppState("wslNvim");

public sealed record UnknownAppState(string UnknownType, IReadOnlyDictionary<string,string> Fields) : AppState(UnknownType);

public sealed record AgentScreenCapture(string Id, string Title, string Text, int Index = 0)
{
    public string NumberedTitle => Index > 0 ? $"{Index}  {Title}" : Title;
}

public sealed record BookmarkStore(AppSettings? Settings, IReadOnlyList<Bookmark> Bookmarks)
{
    public BookmarkStore() : this(null, Array.Empty<Bookmark>()) {}
}
