using FocusBM.Core;
using Xunit;

namespace FocusBM.App.Wpf.Tests;
public class SearchViewModelTests
{
    [Fact] public void QueryFiltersAndNavigationStaysInRange()
    {
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(BookmarkListColumns:2), new [] { new Bookmark("docs", "Chrome", "work"), new Bookmark("term", "Terminal", "dev") }));
        vm.Query = "doc";
        Assert.Single(vm.Results);
        vm.Move(NavigationCommand.Down);
        Assert.Equal(0, vm.SelectedIndex);
    }

    [Fact]
    public void ClearQuery_RestoresUnfilteredList()
    {
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { new Bookmark("docs", "Chrome", "work"), new Bookmark("term", "Terminal", "dev") }));
        vm.Query = "doc";
        Assert.Single(vm.Results);
        vm.ClearQuery();
        Assert.Equal(string.Empty, vm.Query);
        Assert.Equal(2, vm.Results.Count);
    }

    [Fact]
    public void MoveDown_SelectsTheNextCandidate()
    {
        var first = new Bookmark("first", "notepad", "one");
        var second = new Bookmark("second", "codex @ WezTerm", "two", new WslProcessState(42, "codex"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { first, second }));

        vm.Move(NavigationCommand.Down);

        Assert.Same(second, vm.SelectedBookmark);
    }

    [Fact]
    public async Task RestoreSelectedAsync_UsesTheCandidateSelectedByMoveDown()
    {
        Bookmark? restored = null;
        var first = new Bookmark("first", "notepad", "one");
        var second = new Bookmark("second", "codex @ WezTerm", "two", new WslProcessState(42, "codex"));
        var vm = new SearchPanelViewModel((bookmark, _) =>
        {
            restored = bookmark;
            return Task.FromResult(OperationResult.Success("restored"));
        });
        vm.Load(new BookmarkStore(new AppSettings(), new[] { first, second }));

        vm.Move(NavigationCommand.Down);
        var result = await vm.RestoreSelectedAsync();

        Assert.True(result.IsSuccess);
        Assert.Same(second, restored);
    }

    [Fact]
    public void ToggleRepressTarget_UsesFirstConfiguredBookmarkOutsideResults()
    {
        var first = new Bookmark("first", "Notepad", "one", ExecuteOnToggleRepress: true);
        var second = new Bookmark("second", "Terminal", "two", ExecuteOnToggleRepress: true);
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { first, second, new Bookmark("other", "Chrome", "work") }));
        vm.Query = "other";

        Assert.Same(first, vm.ToggleRepressTarget);
    }

    [Fact]
    public async Task RestoreBookmarkAsync_RestoresConfiguredTargetOutsideResults()
    {
        Bookmark? restored = null;
        var target = new Bookmark("target", "Terminal", "dev", ExecuteOnToggleRepress: true);
        var vm = new SearchPanelViewModel((bookmark, _) => { restored = bookmark; return Task.FromResult(OperationResult.Success("ok")); });
        vm.Load(new BookmarkStore(new AppSettings(), new[] { target, new Bookmark("other", "Chrome", "work") }));
        vm.Query = "other";

        var result = await vm.RestoreBookmarkAsync(vm.ToggleRepressTarget!);

        Assert.True(result.IsSuccess);
        Assert.Same(target, restored);
    }

    [Fact]
    public void Load_DropsWslAgentsThatAreNoLongerPresent()
    {
        var listed = new Bookmark("docs", "Chrome", "work");
        var agent = new Bookmark("wsl:42", "codex @ WezTerm", "dev", new WslProcessState(42, "codex"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { listed, agent }));
        Assert.Contains(vm.Results, bm => bm.Id == "wsl:42");

        vm.Load(new BookmarkStore(new AppSettings(), new[] { listed }), announce: false);

        Assert.DoesNotContain(vm.Results, bm => bm.Id == "wsl:42");
        Assert.Contains(vm.Results, bm => bm.Id == "docs");
    }
}

public class ShortcutViewModelTests
{
    [Fact] public async Task ShortcutRestore_WorksWhenQueryIsEmpty()
    {
        Bookmark? restored = null;
        var vm = new SearchPanelViewModel((bm, _) => { restored = bm; return Task.FromResult(OperationResult.Success("ok")); });
        vm.Load(new BookmarkStore(new AppSettings(), new [] { new Bookmark("docs", "App", "ctx", Shortcut: "d") }));
        var result = await vm.RestoreShortcutAsync("d");
        Assert.NotNull(result);
        Assert.Equal("docs", restored!.Id);
    }

    [Fact] public void ExplicitShortcut_IsOmittedFromResultsWhenQueryEmpty()
    {
        var pinned = new Bookmark("ghost", "Ghostty", "term", Shortcut: "s");
        var listed = new Bookmark("docs", "Chrome", "work");
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { pinned, listed }));
        Assert.DoesNotContain(vm.Results, bm => bm.Id == "ghost");
        Assert.Contains(vm.Results, bm => bm.Id == "docs");
        Assert.Contains(vm.ShortcutBar, a => a.Bookmark.Id == "ghost" && a.Shortcut == "s");
        Assert.True(vm.ShowShortcutBar);
        vm.Query = "ghost";
        Assert.Contains(vm.Results, bm => bm.Id == "ghost");
        Assert.False(vm.ShowShortcutBar);
    }

    [Fact] public async Task CaretShortcut_RestoresBarApp()
    {
        Bookmark? restored = null;
        var vm = new SearchPanelViewModel((bm, _) => { restored = bm; return Task.FromResult(OperationResult.Success("ok")); });
        vm.Load(new BookmarkStore(new AppSettings(), new[] { new Bookmark("ghostty", "Ghostty", "dev", Shortcut: "^s") }));
        var result = await vm.RestoreShortcutAsync("^s");
        Assert.NotNull(result);
        Assert.Equal("ghostty", restored!.Id);
        Assert.Contains(vm.ShortcutBar, a => a.Shortcut == "^s" && a.DisplayLabel == "⌃s");
    }

    [Fact] public void DigitTwo_SelectsFirefoxWithoutLetterShortcut()
    {
        var ghost = new Bookmark("ghostty", "Ghostty", "dev", Shortcut: "^s");
        var nvim = new Bookmark("focusbm-nvim", "Windows Terminal", "dev", new WslNvimState());
        var firefox = new Bookmark("firefox-2", "Firefox", "dev", new BrowserAppState("", UrlPattern: "github.com", TabIndex: 2));
        var github = new Bookmark("github", "Firefox", "dev", new BrowserAppState("", UrlPattern: "github.com"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(ShowAIAgentShortcut: false, BookmarkListColumns: 2), new[] { ghost, nvim, firefox, github }));
        Assert.DoesNotContain(vm.Results, bm => bm.Id == "ghostty");
        Assert.True(vm.SelectByDigit(2));
        Assert.Equal("firefox-2", vm.SelectedBookmark!.Id);
        Assert.True(vm.SelectByDigit(1));
        Assert.Equal("focusbm-nvim", vm.SelectedBookmark!.Id);
    }

    [Fact]
    public void Load_RaisesSettingsChangedAndKeepsListFontSize()
    {
        var vm = new SearchPanelViewModel();
        string? changed = null;
        vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(SearchPanelViewModel.Settings)) changed = e.PropertyName;
        };

        vm.Load(new BookmarkStore(new AppSettings(ListFontSize: 22.0), Array.Empty<Bookmark>()), announce: false);

        Assert.Equal(nameof(SearchPanelViewModel.Settings), changed);
        Assert.Equal(22.0, vm.Settings.EffectiveListFontSize);
    }
}

public class PullRequestViewModelTests
{
    [Fact]
    public async Task PullRequestResolver_UsesSelectedWslAgent()
    {
        var expected = new Uri("https://github.com/org/repo/pull/42");
        var bookmark = new Bookmark("wsl:42", "codex @ WezTerm", "repo", new WslProcessState(42, "codex", WorkingDirectory: "/home/alice/repo"));
        var vm = new SearchPanelViewModel(
            pullRequestResolver: (selected, _) => Task.FromResult<Uri?>(selected == bookmark ? expected : null));
        vm.Load(new BookmarkStore(new AppSettings(), new[] { bookmark }));

        Assert.True(vm.CanResolveSessionPullRequest(bookmark));
        Assert.Equal(expected, await vm.ResolveSessionPullRequestAsync(bookmark));
        vm.ApplyPullRequestCache(new Dictionary<string, string> { ["/home/alice/repo"] = expected.AbsoluteUri });
        Assert.Equal("#42", vm.Results[0].PullRequestLabel);
    }
}

public class AgentScreenPreviewTests
{
    [Fact]
    public void ShowHoveredPreview_UsesCachedScreenCaptureInstantly()
    {
        var bookmark = new Bookmark(
            "tmux:0:1:%52",
            "cursor-agent @ WezTerm",
            "pane",
            new WslProcessState(42, "cursor-agent", TmuxPaneId: "%52", ScreenCapture: "❯ prompt"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { bookmark }));
        vm.HoveredIndex = 0;

        Assert.True(vm.ShowHoveredPreview());
        Assert.True(vm.IsPreviewVisible);
        Assert.Equal("❯ prompt", Assert.Single(vm.PreviewCaptures).Text);
        Assert.False(vm.IsTiledPreview);

        Assert.True(vm.DismissPreview());
        Assert.False(vm.IsPreviewVisible);
        Assert.Empty(vm.PreviewCaptures);
        Assert.False(vm.DismissPreview());
    }

    [Fact]
    public void ShowHoveredPreview_DropsBlankPaddingBelowPrompt()
    {
        var bookmark = new Bookmark(
            "tmux:0:1:%2",
            "claude @ WezTerm",
            "pane",
            new WslProcessState(1, "claude", TmuxPaneId: "%2", ScreenCapture: "❯ prompt\n\n\n          \n"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { bookmark }));
        vm.HoveredIndex = 0;

        Assert.True(vm.ShowHoveredPreview());
        Assert.Equal("❯ prompt", Assert.Single(vm.PreviewCaptures).Text);
    }

    [Fact]
    public void ShowHoveredPreview_MissingCache_DoesNotThrow()
    {
        var bookmark = new Bookmark(
            "tmux:0:1:%52",
            "cursor-agent @ WezTerm",
            "pane",
            new WslProcessState(42, "cursor-agent", TmuxPaneId: "%52"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { bookmark }));
        vm.HoveredIndex = 0;

        Assert.True(vm.ShowHoveredPreview());
        Assert.Equal("キャプチャできませんでした", Assert.Single(vm.PreviewCaptures).Text);
    }

    [Fact]
    public void ShowAllPreviews_TilesCachedCaptures()
    {
        var first = new Bookmark("tmux:a", "claude", "one", new WslProcessState(1, "claude", TmuxPaneId: "%1", ScreenCapture: "pane %1"));
        var second = new Bookmark("tmux:b", "codex", "two", new WslProcessState(2, "codex", TmuxPaneId: "%2", ScreenCapture: "pane %2"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), new[] { first, second }));

        Assert.True(vm.ShowAllPreviews());
        Assert.True(vm.IsTiledPreview);
        Assert.Equal(new[] { "pane %1", "pane %2" }, vm.PreviewCaptures.Select(capture => capture.Text).ToArray());
        Assert.Equal(new[] { 1, 2 }, vm.PreviewCaptures.Select(capture => capture.Index).ToArray());
        Assert.StartsWith("1  ", vm.PreviewCaptures[0].NumberedTitle);
        Assert.Same(first, vm.BookmarkForPreviewDigit(1));
        Assert.Same(second, vm.BookmarkForPreviewDigit(2));
        Assert.Null(vm.BookmarkForPreviewDigit(3));
    }

    [Fact]
    public void BookmarkForPreviewDigit_IgnoresShortcutAssignmentWhenPreviewIsOpen()
    {
        var first = new Bookmark("tmux:a", "claude", "one", new WslProcessState(1, "claude", TmuxPaneId: "%1", ScreenCapture: "pane %1"));
        var second = new Bookmark("tmux:b", "codex", "two", new WslProcessState(2, "codex", TmuxPaneId: "%2", ScreenCapture: "pane %2"));
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(ShowAIAgentShortcut: false), new[] { first, second }));
        Assert.True(vm.ShowAllPreviews());
        Assert.False(vm.SelectByDigit(1));
        Assert.Same(first, vm.BookmarkForPreviewDigit(1));
    }

    [Fact]
    public void PreviewFontFamily_UsesPreviewFontThenFallsBackToListFont()
    {
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(FontName: "Fira Code"), Array.Empty<Bookmark>()));
        Assert.Equal("Fira Code", vm.PreviewFontFamily);
        Assert.Equal(14, vm.PreviewFontSize);

        vm.Load(new BookmarkStore(new AppSettings(FontName: "Fira Code", PreviewFontName: "JetBrains Mono", PreviewFontSize: 18), Array.Empty<Bookmark>()));
        Assert.Equal("JetBrains Mono", vm.PreviewFontFamily);
        Assert.Equal(18, vm.PreviewFontSize);
    }
}
