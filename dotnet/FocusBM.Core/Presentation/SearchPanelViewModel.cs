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
    private readonly Func<string, CancellationToken, Task<string?>>? _capturePane;
    private readonly Func<string, string, CancellationToken, Task<OperationResult>>? _sendPrompt;
    private readonly SemaphoreSlim _promptSendSemaphore = new(1, 1);
    private string _promptDraft = string.Empty;
    private int? _promptTargetIndex;
    private bool _isPromptFieldFocused;
    private string? _promptError;
    private int _previewGeneration;
    private bool _previewRefreshInFlight;

    public SearchPanelViewModel(
        Func<Bookmark, CancellationToken, Task<OperationResult>>? restore = null,
        Func<Bookmark, CancellationToken, Task<Uri?>>? pullRequestResolver = null,
        Func<string, CancellationToken, Task<string?>>? capturePane = null,
        Func<string, string, CancellationToken, Task<OperationResult>>? sendPrompt = null)
    {
        _restore = restore;
        _pullRequestResolver = pullRequestResolver;
        _capturePane = capturePane;
        PreviewCaptures.CollectionChanged += (_, _) => OnChanged(nameof(PreviewMaxLineCount));
        _sendPrompt = sendPrompt;
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
    public int PreviewMaxLineCount => PreviewLayout.MaxLineCount(PreviewCaptures.Select(capture => capture.Text));
    public string PreviewFontFamily => Settings.EffectivePreviewFontName ?? "Consolas";
    public double PreviewFontSize => Settings.EffectivePreviewFontSize;
    public string PromptDraft
    {
        get => _promptDraft;
        set
        {
            value ??= string.Empty;
            if (_promptDraft == value) return;
            _promptDraft = value;
            OnChanged(nameof(PromptDraft));
        }
    }
    public int? PromptTargetIndex => _promptTargetIndex;
    public string? PromptTargetLabel => IsTiledPreview && PromptTargetIndex is { } index ? $"→ {index}" : null;
    public bool IsPromptFieldFocused => _isPromptFieldFocused;
    public string? PromptError => _promptError;
    public string PromptPlaceholder => IsTiledPreview && PromptTargetIndex is null
        ? "Ctrl+数字で送信先を選んで入力（Enter で送信）"
        : "エージェントへの指示（Enter で送信）";
    public bool IsPromptAvailable => _sendPrompt is not null;
    public AppSettings Settings { get; private set; } = new();
    public string StatusMessage { get; private set; } = "準備完了";
    public string Query { get => _query; set { _query = value ?? string.Empty; Refresh(); OnChanged(nameof(Query)); OnChanged(nameof(ShowShortcuts)); OnChanged(nameof(ShowShortcutBar)); } }

    public void ClearQuery() => Query = string.Empty;

    public void Load(BookmarkStore store, bool announce = true)
    {
        Settings = store.Settings ?? new AppSettings();
        // Why: Instead of dropping disabled bookmarks at YAML load, adopted filtering at display sites. Reason: saves rewrite the file from the loaded store and would lose hidden entries.
        _all = store.Bookmarks.Where(b => b.Enables).ToArray();
        RebuildShortcutBar();
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
        var chip = ToggleRepressChipTarget;
        var visible = string.IsNullOrEmpty(_query)
            ? filtered.Where(bm => string.IsNullOrWhiteSpace(bm.Shortcut) && bm != chip)
            : filtered;
        foreach (var bm in visible) Results.Add(bm);
        SelectedIndex = Results.Count == 0 ? -1 : Math.Clamp(SelectedIndex, 0, Results.Count - 1);
        RebuildNumberShortcuts();
        OnChanged(nameof(Results));
        OnChanged(nameof(SelectedIndex));
        OnChanged(nameof(Shortcuts));
        OnChanged(nameof(ShowShortcuts));
        ScheduleAutoExecute();
    }

    private void RebuildNumberShortcuts()
    {
        Shortcuts.Clear();
        // Why: 絞り込み中は表示中の候補だけに 1〜9 を振り直し、YAML 指定や AI 抑止に関係なく全候補を数字で選べるようにする（10件目以降は数字なし）
        if (ShortcutAssigner.FilteredNumberLabels(_query, Results.Count) is { } labels)
        {
            for (var i = 0; i < labels.Count; i++)
                if (labels[i] is { } label) Shortcuts.Add(new ShortcutAssignment(Results[i], label, true));
            return;
        }
        foreach (var assignment in ShortcutAssigner.Assign(_all, Settings).Where(a => a.Shortcut is not null))
            Shortcuts.Add(assignment);
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

    private void RebuildShortcutBar()
    {
        ShortcutBar.Clear();
        foreach (var assignment in ShortcutAssigner.Assign(_all, Settings).Where(a => a.Shortcut is not null))
        {
            if (!string.IsNullOrWhiteSpace(assignment.Bookmark.Shortcut)) ShortcutBar.Add(assignment);
        }
        if (ToggleRepressChipTarget is { } target) ShortcutBar.Add(new ShortcutAssignment(target, HotkeyParser.Format(Settings.EffectiveHotkey), false));
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
        // Why: 絞り込み画面は1行1件の表なので、bookmarkListColumns に関わらず↑↓は1件ずつ動かす
        SelectedIndex = GridNavigator.Move(SelectedIndex, Results.Count, 1, command);
        OnChanged(nameof(SelectedIndex));
    }

    public Bookmark? ToggleRepressTarget => _all.FirstOrDefault(bookmark => bookmark.ExecuteOnToggleRepress);

    /// <summary>The toggle-repress target shown as a togglePanel-hotkey chip in the shortcut bar (empty query). A YAML shortcut keeps its own chip instead.</summary>
    private Bookmark? ToggleRepressChipTarget => ToggleRepressTarget is { } target && string.IsNullOrWhiteSpace(target.Shortcut) ? target : null;

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
        ResetPreviewRefresh();
        if (PreviewCaptures.Count == 0) return false;
        SetPromptTargetIndex(null);
        SetPromptFieldFocused(false);
        PreviewCaptures.Clear();
        IsTiledPreview = false;
        OnChanged(nameof(IsPreviewVisible));
        OnChanged(nameof(IsTiledPreview));
        OnChanged(nameof(PreviewColumnCount));
        OnChanged(nameof(PromptTargetLabel));
        OnChanged(nameof(PromptPlaceholder));
        return true;
    }

    public bool ShowHoveredPreview()
    {
        if (PreviewTarget is not { } bookmark) return false;
        var capture = CaptureFromCache(bookmark);
        if (capture is null) return false;
        SetPreview(new[] { capture }, tiled: false, promptTargetIndex: 1);
        _promptError = null;
        OnChanged(nameof(PromptError));
        SetPromptFieldFocused(true);
        return true;
    }

    public bool ShowAllPreviews()
    {
        var agents = _all.Where(bookmark => bookmark.IsAIAgent).ToArray();
        if (agents.Length == 0) return false;
        var captures = agents.Select(CaptureFromCache).OfType<AgentScreenCapture>().ToArray();
        if (captures.Length == 0) return false;
        SetPreview(captures, tiled: captures.Length > 1, promptTargetIndex: captures.Length == 1 ? 1 : null);
        return true;
    }

    public bool SetPromptTarget(int number)
    {
        if (!IsTiledPreview || number < 1 || number > PreviewCaptures.Count) return false;
        SetPromptTargetIndex(number);
        SetPromptFieldFocused(true);
        return true;
    }

    public bool BlurTiledPromptField()
    {
        if (!IsPromptFieldFocused || !IsTiledPreview) return false;
        SetPromptFieldFocused(false);
        return true;
    }

    public void SetPromptFieldFocused(bool focused) => SetPromptFieldFocusedValue(focused);

    public async Task SendPromptToPreviewAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(PromptDraft) || PromptTargetIndex is not { } targetIndex || _sendPrompt is null) return;
        if (BookmarkForPreviewDigit(targetIndex) is not { } bookmark || string.IsNullOrWhiteSpace(PaneIdOf(bookmark)))
        {
            _promptError = "送信先の tmux ペインが見つかりません";
            OnChanged(nameof(PromptError));
            return;
        }

        var paneId = PaneIdOf(bookmark)!;
        var draft = PromptDraft;
        await _promptSendSemaphore.WaitAsync(cancellationToken);
        try
        {
            var result = await _sendPrompt(paneId, draft, cancellationToken);
            if (result.IsSuccess)
            {
                _promptError = null;
                OnChanged(nameof(PromptError));
                if (PromptDraft == draft) PromptDraft = string.Empty;
            }
            else
            {
                _promptError = result.Message;
                OnChanged(nameof(PromptError));
            }
        }
        finally
        {
            _promptSendSemaphore.Release();
        }
    }

    /// <summary>Re-captures the tmux panes shown in the preview and replaces only captures whose text changed. Call periodically while the preview is visible.</summary>
    public async Task RefreshPreviewAsync(CancellationToken cancellationToken = default)
    {
        // Why: Instead of cancelling the previous tick, adopted skipping while a capture is in flight. Reason: wsl.exe captures can exceed the tick interval and would otherwise never land.
        if (_capturePane is null || _previewRefreshInFlight || PreviewCaptures.Count == 0) return;
        var targets = PreviewCaptures
            .Select(capture => (capture.Id, PaneId: _all.FirstOrDefault(b => string.Equals(b.Id, capture.Id, StringComparison.Ordinal)) is { } bookmark ? PaneIdOf(bookmark) : null))
            .Where(target => !string.IsNullOrWhiteSpace(target.PaneId))
            .ToArray();
        if (targets.Length == 0) return;
        var generation = _previewGeneration;
        _previewRefreshInFlight = true;
        string?[] texts;
        try
        {
            texts = await Task.WhenAll(targets.Select(target => _capturePane(target.PaneId!, cancellationToken)));
        }
        catch (Exception)
        {
            // A failed tick keeps the last capture; the next tick retries.
            texts = [];
        }
        if (generation != _previewGeneration) return;
        _previewRefreshInFlight = false;
        for (var t = 0; t < texts.Length; t++)
        {
            if (texts[t] is not { } raw) continue;
            var text = NormalizeCaptureText(raw);
            for (var i = 0; i < PreviewCaptures.Count; i++)
            {
                if (PreviewCaptures[i].Id == targets[t].Id && PreviewCaptures[i].Text != text)
                    PreviewCaptures[i] = PreviewCaptures[i] with { Text = text };
            }
        }
        // Why: Load() replaces _all on each background refresh, so re-read status here to keep the pill from going stale.
        for (var i = 0; i < PreviewCaptures.Count; i++)
        {
            var id = PreviewCaptures[i].Id;
            var status = _all.FirstOrDefault(b => string.Equals(b.Id, id, StringComparison.Ordinal))?.AgentStatus;
            if (PreviewCaptures[i].Status != status)
                PreviewCaptures[i] = PreviewCaptures[i] with { Status = status };
        }
    }

    private void ResetPreviewRefresh()
    {
        _previewGeneration++;
        _previewRefreshInFlight = false;
    }

    private void SetPreview(IReadOnlyList<AgentScreenCapture> captures, bool tiled, int? promptTargetIndex)
    {
        ResetPreviewRefresh();
        PreviewCaptures.Clear();
        var index = 1;
        foreach (var capture in captures)
            PreviewCaptures.Add(capture with { Index = index++ });
        IsTiledPreview = tiled;
        SetPromptTargetIndex(promptTargetIndex);
        OnChanged(nameof(IsPreviewVisible));
        OnChanged(nameof(IsTiledPreview));
        OnChanged(nameof(PreviewColumnCount));
        OnChanged(nameof(PromptTargetLabel));
        OnChanged(nameof(PromptPlaceholder));
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
        var cached = PreviewLayout.TextAbovePrompt(bookmark.State switch
        {
            WslProcessState process => process.ScreenCapture,
            _ => null
        });
        var text = string.IsNullOrWhiteSpace(cached)
            ? string.IsNullOrWhiteSpace(PaneIdOf(bookmark))
                ? "tmux ペインがないため画面キャプチャできません"
                : "キャプチャできませんでした"
            : cached;
        return new AgentScreenCapture(bookmark.Id, bookmark.DisplayLabel, text, Status: bookmark.AgentStatus);
    }

    private static string? PaneIdOf(Bookmark bookmark) => bookmark.State switch
    {
        WslProcessState process => process.TmuxPaneId,
        TmuxPaneState pane => pane.PaneId,
        _ => null
    };

    private static string NormalizeCaptureText(string raw)
    {
        var trimmed = PreviewLayout.TextAbovePrompt(raw);
        return string.IsNullOrWhiteSpace(AnsiText.Strip(trimmed)) ? "キャプチャできませんでした" : trimmed;
    }

    private void SetPromptTargetIndex(int? index)
    {
        if (_promptTargetIndex == index) return;
        _promptTargetIndex = index;
        OnChanged(nameof(PromptTargetIndex));
        OnChanged(nameof(PromptTargetLabel));
        OnChanged(nameof(PromptPlaceholder));
    }

    private void SetPromptFieldFocusedValue(bool focused)
    {
        if (_isPromptFieldFocused == focused) return;
        _isPromptFieldFocused = focused;
        OnChanged(nameof(IsPromptFieldFocused));
    }

    private void OnChanged(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
