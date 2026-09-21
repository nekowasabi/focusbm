using System.Collections.ObjectModel;
using System.ComponentModel;

namespace FocusBM.Core;

/// <summary>Portable ViewModel logic shared by WPF and testable without WindowsDesktop runtime.</summary>
public sealed class SearchPanelViewModel : INotifyPropertyChanged
{
    private string _query = string.Empty;
    private IReadOnlyList<Bookmark> _all = Array.Empty<Bookmark>();
    private int _generation;
    private readonly Func<Bookmark, CancellationToken, Task<OperationResult>>? _restore;
    private readonly Func<Bookmark, CancellationToken, Task<Uri?>>? _pullRequestResolver;

    public SearchPanelViewModel(
        Func<Bookmark, CancellationToken, Task<OperationResult>>? restore = null,
        Func<Bookmark, CancellationToken, Task<Uri?>>? pullRequestResolver = null)
    {
        _restore = restore;
        _pullRequestResolver = pullRequestResolver;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public ObservableCollection<Bookmark> Results { get; } = new();
    public ObservableCollection<ShortcutAssignment> Shortcuts { get; } = new();
    public int SelectedIndex { get; set; }
    public int HoveredIndex { get; set; } = -1;
    public ObservableCollection<AgentScreenCapture> PreviewCaptures { get; } = new();
    public bool IsPreviewVisible => PreviewCaptures.Count > 0;
    public bool IsTiledPreview { get; private set; }
    public int PreviewColumnCount => IsTiledPreview ? 2 : 1;
    public string PreviewFontFamily => Settings.EffectivePreviewFontName ?? "Consolas";
    public double PreviewFontSize => Settings.EffectivePreviewFontSize;
    public AppSettings Settings { get; private set; } = new();
    public string StatusMessage { get; private set; } = "準備完了";
    public string Query { get => _query; set { _query = value ?? string.Empty; Refresh(); OnChanged(nameof(Query)); OnChanged(nameof(ShowShortcuts)); OnChanged(nameof(ShowShortcutBar)); } }

    public void ClearQuery() => Query = string.Empty;

    public void Load(BookmarkStore store, bool announce = true)
    {
        Settings = store.Settings ?? new AppSettings();
        _all = store.Bookmarks;
        RebuildShortcuts();
        Refresh();
        OnChanged(nameof(Settings));
        OnChanged(nameof(PreviewFontFamily));
        OnChanged(nameof(PreviewFontSize));
        if (announce) SetStatus($"{_all.Count} 件のブックマークを読み込みました");
    }

    public void SetStatus(string message)
    {
        StatusMessage = message;
        OnChanged(nameof(StatusMessage));
    }

    public void Refresh()
    {
        var gen = ++_generation;
        var filtered = BookmarkSearcher.Filter(_all, _query);
        if (gen != _generation) return;
        Results.Clear();
        var visible = string.IsNullOrEmpty(_query)
            ? filtered.Where(bm => string.IsNullOrWhiteSpace(bm.Shortcut))
            : filtered;
        foreach (var bm in visible) Results.Add(bm);
        SelectedIndex = Results.Count == 0 ? -1 : Math.Clamp(SelectedIndex, 0, Results.Count - 1);
        OnChanged(nameof(Results));
        OnChanged(nameof(SelectedIndex));
        ScheduleAutoExecute();
    }

    public event Action? AutoExecuteRequested;
    private CancellationTokenSource? _autoExecuteCts;

    private void ScheduleAutoExecute()
    {
        _autoExecuteCts?.Cancel();
        _autoExecuteCts = null;
        if (Settings.AutoExecuteOnSingleResult != true || string.IsNullOrEmpty(_query) || Results.Count != 1) return;
        var cts = new CancellationTokenSource();
        _autoExecuteCts = cts;
        var delay = Settings.EffectiveAutoExecuteDelay;
        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(delay), cts.Token).ConfigureAwait(false);
                AutoExecuteRequested?.Invoke();
            }
            catch (OperationCanceledException) { }
        });
    }

    public bool SelectByDigit(int number)
    {
        var label = number.ToString();
        for (var i = 0; i < Results.Count; i++)
        {
            var assigned = Shortcuts.FirstOrDefault(a => a.Bookmark == Results[i]);
            if (assigned?.Shortcut == label)
            {
                SelectedIndex = i;
                OnChanged(nameof(SelectedIndex));
                return true;
            }
        }
        return false;
    }

    private void RebuildShortcuts()
    {
        Shortcuts.Clear();
        ShortcutBar.Clear();
        foreach (var assignment in ShortcutAssigner.Assign(_all, Settings).Where(a => a.Shortcut is not null))
        {
            Shortcuts.Add(assignment);
            if (!string.IsNullOrWhiteSpace(assignment.Bookmark.Shortcut)) ShortcutBar.Add(assignment);
        }
        OnChanged(nameof(Shortcuts));
        OnChanged(nameof(ShortcutBar));
        OnChanged(nameof(ShowShortcuts));
        OnChanged(nameof(ShowShortcutBar));
    }

    public ObservableCollection<ShortcutAssignment> ShortcutBar { get; } = new();
    public bool ShowShortcuts => string.IsNullOrEmpty(Query) && Shortcuts.Count > 0;
    public bool ShowShortcutBar => string.IsNullOrEmpty(Query) && ShortcutBar.Count > 0;

    public async Task<OperationResult?> RestoreShortcutAsync(string key, CancellationToken cancellationToken = default)
    {
        if (!ShowShortcuts) return null;
        var assignment = Shortcuts.FirstOrDefault(a => string.Equals(a.Shortcut, key, StringComparison.Ordinal));
        if (assignment is null) return null;
        var index = Results.IndexOf(assignment.Bookmark);
        if (index >= 0)
        {
            SelectedIndex = index;
            OnChanged(nameof(SelectedIndex));
        }
        if (_restore is null)
        {
            SetStatus($"restore target: {BookmarkRestoreOrchestrator.BuildTarget(assignment.Bookmark)}");
            return OperationResult.Success(StatusMessage, BookmarkRestoreOrchestrator.BuildTarget(assignment.Bookmark));
        }
        var result = await _restore(assignment.Bookmark, cancellationToken);
        SetStatus(result.Message);
        LogRestore(assignment.Bookmark, assignment.Shortcut, result);
        return result;
    }

    public void Move(NavigationCommand command)
    {
        SelectedIndex = GridNavigator.Move(SelectedIndex, Results.Count, Settings.NormalizedColumns, command);
        OnChanged(nameof(SelectedIndex));
    }

    public Bookmark? ToggleRepressTarget => _all.FirstOrDefault(bookmark => bookmark.ExecuteOnToggleRepress);

    public Task<OperationResult> RestoreSelectedAsync(CancellationToken cancellationToken = default)
    {
        var selected = SelectedBookmark;
        if (selected is null)
        {
            SetStatus("復元対象が選択されていません");
            return Task.FromResult(OperationResult.VisibleError(OperationStatus.NotFound, StatusMessage));
        }
        return RestoreBookmarkAsync(selected, cancellationToken);
    }

    public async Task<OperationResult> RestoreBookmarkAsync(Bookmark bookmark, CancellationToken cancellationToken = default)
    {
        if (_restore is null)
        {
            SetStatus($"restore target: {BookmarkRestoreOrchestrator.BuildTarget(bookmark)}");
            return OperationResult.Success(StatusMessage, BookmarkRestoreOrchestrator.BuildTarget(bookmark));
        }
        var result = await _restore(bookmark, cancellationToken);
        SetStatus(result.Message);
        LogRestore(bookmark, null, result);
        return result;
    }

    private static void LogRestore(Bookmark bookmark, string? shortcut, OperationResult result) =>
        FocusBmLog.Write("restore", $"{bookmark.Id} app={bookmark.AppName} type={bookmark.State?.Type ?? "app"} shortcut={shortcut ?? "-"} -> {result.Status} {result.Message}");

    public Bookmark? SelectedBookmark => SelectedIndex >= 0 && SelectedIndex < Results.Count ? Results[SelectedIndex] : null;

    public IReadOnlyList<WslProcessState> PullRequestCandidates => _all
        .Select(bookmark => bookmark.State)
        .OfType<WslProcessState>()
        .Where(state => GitHubPullRequest.SupportsAgent(state.Command) && !string.IsNullOrWhiteSpace(state.WorkingDirectory))
        .GroupBy(state => state.WorkingDirectory!, StringComparer.Ordinal)
        .Select(group => group.First())
        .ToArray();

    public bool CanResolveSessionPullRequest(Bookmark bookmark) =>
        bookmark.State is WslProcessState state
        && GitHubPullRequest.SupportsAgent(state.Command)
        && (!string.IsNullOrWhiteSpace(state.WorkingDirectory) || (state.Pid > 0 && string.Equals(state.Command, "claude", StringComparison.OrdinalIgnoreCase)))
        && _pullRequestResolver is not null;

    public async Task<Uri?> ResolveSessionPullRequestAsync(Bookmark bookmark, CancellationToken cancellationToken = default)
    {
        if (!CanResolveSessionPullRequest(bookmark)) return null;
        return await _pullRequestResolver!(bookmark, cancellationToken).ConfigureAwait(false);
    }

    public void ApplyPullRequestCache(IReadOnlyDictionary<string, string> urls)
    {
        _all = _all.Select(bookmark =>
        {
            if (bookmark.State is WslProcessState state
                && state.WorkingDirectory is { } directory
                && urls.TryGetValue(directory, out var url)) return bookmark with { PullRequestUrl = url };
            return bookmark with { PullRequestUrl = null };
        }).ToArray();
        Refresh();
    }

    public Bookmark? PreviewTarget
    {
        get
        {
            if (HoveredIndex >= 0 && HoveredIndex < Results.Count && Results[HoveredIndex].IsAIAgent)
                return Results[HoveredIndex];
            return SelectedBookmark is { IsAIAgent: true } selected ? selected : null;
        }
    }

    public bool DismissPreview()
    {
        if (PreviewCaptures.Count == 0) return false;
        PreviewCaptures.Clear();
        IsTiledPreview = false;
        OnChanged(nameof(IsPreviewVisible));
        OnChanged(nameof(IsTiledPreview));
        OnChanged(nameof(PreviewColumnCount));
        return true;
    }

    public bool ShowHoveredPreview()
    {
        if (PreviewTarget is not { } bookmark) return false;
        var capture = CaptureFromCache(bookmark);
        if (capture is null) return false;
        SetPreview(new[] { capture }, tiled: false);
        return true;
    }

    public bool ShowAllPreviews()
    {
        var agents = _all.Where(bookmark => bookmark.IsAIAgent).ToArray();
        if (agents.Length == 0) return false;
        var captures = agents.Select(CaptureFromCache).OfType<AgentScreenCapture>().ToArray();
        if (captures.Length == 0) return false;
        SetPreview(captures, tiled: captures.Length > 1);
        return true;
    }

    private void SetPreview(IReadOnlyList<AgentScreenCapture> captures, bool tiled)
    {
        PreviewCaptures.Clear();
        var index = 1;
        foreach (var capture in captures)
            PreviewCaptures.Add(capture with { Index = index++ });
        IsTiledPreview = tiled;
        OnChanged(nameof(IsPreviewVisible));
        OnChanged(nameof(IsTiledPreview));
        OnChanged(nameof(PreviewColumnCount));
    }

    public Bookmark? BookmarkForPreviewDigit(int number)
    {
        if (number < 1 || number > PreviewCaptures.Count) return null;
        var id = PreviewCaptures[number - 1].Id;
        return _all.FirstOrDefault(bookmark => string.Equals(bookmark.Id, id, StringComparison.Ordinal));
    }

    private static AgentScreenCapture? CaptureFromCache(Bookmark bookmark)
    {
        if (!bookmark.IsAIAgent) return null;
        var cached = PreviewLayout.TrimTrailingBlankLines(bookmark.State switch
        {
            WslProcessState process => process.ScreenCapture,
            _ => null
        });
        var paneId = bookmark.State switch
        {
            WslProcessState process => process.TmuxPaneId,
            TmuxPaneState pane => pane.PaneId,
            _ => null
        };
        var text = string.IsNullOrWhiteSpace(cached)
            ? string.IsNullOrWhiteSpace(paneId)
                ? "tmux ペインがないため画面キャプチャできません"
                : "キャプチャできませんでした"
            : cached;
        return new AgentScreenCapture(bookmark.Id, bookmark.DisplayLabel, text);
    }

    private void OnChanged(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
