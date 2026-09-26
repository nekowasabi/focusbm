namespace FocusBM.Core;

/// <summary>Swift BookmarkStore 互換のブックマーク DTO。Core は Win32/P-Invoke を含まない。</summary>
public sealed record Bookmark(
    string Id,
    string AppName,
    string Context,
    AppState? State = null,
    string? BundleIdPattern = null,
    string? Shortcut = null,
    bool NoShortcut = false,
    bool LowPriority = false,
    DateTimeOffset? CreatedAt = null,
    IReadOnlyDictionary<string, string>? UnknownFields = null,
    string? PullRequestUrl = null,
    bool ExecuteOnToggleRepress = false)
{
    public string DisplayName => string.IsNullOrWhiteSpace(Context) ? AppName : $"{AppName} — {Context}";
    public string DisplayLabel => State switch
    {
        WslProcessState process => AppendDirectory(AppName, process.WorkingDirectory),
        TmuxPaneState => AppName,
        _ => Id
    };

    private static string AppendDirectory(string appName, string? workingDirectory)
    {
        var directory = AgentIdentity.DirectoryLeaf(workingDirectory);
        if (directory is null) return appName;
        return appName.EndsWith($" — {directory}", StringComparison.Ordinal) ? appName : $"{appName} — {directory}";
    }
    /// <summary>絞り込み表の「名前」列。エージェントは作業ディレクトリ名、それ以外は DisplayLabel。</summary>
    public string ListName => State is WslProcessState process && AgentIdentity.DirectoryLeaf(process.WorkingDirectory) is { } directory
        ? directory
        : DisplayLabel;

    /// <summary>絞り込み表の「アプリ／端末」列。名前列と重複する末尾の " — ディレクトリ" は落とす。</summary>
    public string ListDetail
    {
        get
        {
            var suffix = $" — {ListName}";
            var detail = AppName.EndsWith(suffix, StringComparison.Ordinal) ? AppName[..^suffix.Length] : AppName;
            return detail == ListName ? string.Empty : detail;
        }
    }

    public TmuxAgentStatus? AgentStatus => (State as WslProcessState)?.AgentStatus;
    public string? AgentEmoji => AgentIdentity.Emoji((State as WslProcessState)?.Command);
    public bool IsAIAgent => State is WslProcessState or TmuxPaneState;
    public string? UrlHint => State is BrowserAppState browser
        ? browser.UrlPattern ?? (string.IsNullOrWhiteSpace(browser.Url) ? null : browser.Url)
        : null;
    public string? PullRequestLabel => GitHubPullRequest.Validate(PullRequestUrl) is { AbsolutePath: var path }
        ? $"#{path.Split('/', StringSplitOptions.RemoveEmptyEntries).Last()}"
        : null;
}
