using FocusBM.Core;
using Xunit;

namespace FocusBM.Core.Tests;

public class CoreModelTests
{
    [Fact] public void BookmarkThreeArgConstructor_RemainsCompatible()
    {
        var bm = new Bookmark("docs", "Safari", "work");
        Assert.Equal("docs", bm.Id);
        Assert.Null(bm.State);
    }
    [Fact] public void DynamicProcessBookmark_UsesHumanLabel()
    {
        var bm = new Bookmark("wsl:42", "codex @ WezTerm", "tmux pane %7", new WslProcessState(42, "codex"));

        Assert.Equal("codex @ WezTerm", bm.DisplayLabel);
        Assert.DoesNotContain("wsl:", bm.DisplayLabel);
    }
    [Fact] public void DynamicProcessBookmark_AppendsWorkingDirectoryLeaf()
    {
        var bm = new Bookmark(
            "wsl:42",
            "codex @ WezTerm",
            "tmux pane %7",
            new WslProcessState(42, "codex", WorkingDirectory: "/home/alice/repos/focusbm-win"));

        Assert.Equal("codex @ WezTerm — focusbm-win", bm.DisplayLabel);
    }
    [Fact] public void FormatAppName_IncludesTerminalAndDirectoryLeaf()
    {
        Assert.Equal("codex @ WezTerm — focusbm-win", AgentIdentity.FormatAppName("codex", "WezTerm", "/home/alice/repos/focusbm-win/"));
        Assert.Equal("claude @ WSL", AgentIdentity.FormatAppName("claude", "WSL", null));
        Assert.Equal("claude @ WSL", AgentIdentity.FormatAppName("claude", "WSL", "~"));
        Assert.Equal("codex @ tmux — project", AgentIdentity.FormatAppName("codex", "tmux", @"C:\Users\alice\project"));
    }
    [Fact] public void DynamicProcessBookmark_DoesNotDuplicateDirectoryAlreadyInAppName()
    {
        var bm = new Bookmark(
            "wsl:42",
            "codex @ WezTerm — focusbm-win",
            "dev",
            new WslProcessState(42, "codex", WorkingDirectory: "/home/alice/repos/focusbm-win"));

        Assert.Equal("codex @ WezTerm — focusbm-win", bm.DisplayLabel);
    }
    [Fact] public void DynamicProcessBookmark_UsesAgentEmoji()
    {
        var bm = new Bookmark("wsl:42", "Grok Build @ WezTerm", "", new WslProcessState(42, "grok"));

        Assert.Equal("🔫", bm.AgentEmoji);
    }
    [Theory]
    [InlineData("claude", "🤖")]
    [InlineData("claude --dangerously-skip-permissions", "🤖")]
    [InlineData("codex", "📖")]
    [InlineData("node /usr/local/lib/node_modules/@openai/codex/bin/codex", "📖")]
    [InlineData("devin", "☕")]
    [InlineData("hermes", "📨")]
    [InlineData("/brew/bin/python /brew/libexec/bin/hermes", "📨")]
    [InlineData("grok", "🔫")]
    [InlineData("grok-1.0.4-linux-x64", "🔫")]
    [InlineData("cursor-agent", "➡️")]
    [InlineData("/usr/bin/cursor-agent --use-system-ca index.js --yolo", "➡️")]
    [InlineData("pi", "π")]
    [InlineData("node /usr/local/bin/pi", "π")]
    public void AgentEmoji_IdentifiesClaudeCodexAndGrok(string command, string emoji)
    {
        var bm = new Bookmark("wsl:1", "agent", "", new WslProcessState(1, command));
        Assert.Equal(emoji, bm.AgentEmoji);
    }
    [Fact] public void AgentEmoji_NonAgentBookmark_IsNull()
    {
        Assert.Null(new Bookmark("docs", "Chrome", "work").AgentEmoji);
    }
    [Fact] public void AppSettings_ListFontSize_UsesConfiguredValue()
    {
        Assert.Equal(14, new AppSettings().EffectiveListFontSize);
        Assert.Equal(22, new AppSettings(ListFontSize: 22.0).EffectiveListFontSize);
    }
    [Fact] public void AppSettings_TwoColumnsDefaultPanelWidthIs800()
    {
        Assert.Equal(800, new AppSettings(BookmarkListColumns: 2).EffectivePanelWidth);
        Assert.Equal(500, new AppSettings().EffectivePanelWidth);
        Assert.Equal(640, new AppSettings(PanelWidth: 640).EffectivePanelWidth);
        Assert.Equal(400, new AppSettings().EffectivePanelHeight);
        Assert.Equal(1000, new AppSettings(PanelHeight: 1000).EffectivePanelHeight);
    }
    [Theory]
    [InlineData(null, 2, 0)]
    [InlineData(1, 2, 0)]
    [InlineData(2, 2, 1)]
    [InlineData(0, 2, 0)]
    [InlineData(9, 2, 0)]
    public void DisplayTarget_OneIsPrimary_InvalidFallsBackToPrimary(int? displayNumber, int count, int expected) =>
        Assert.Equal(expected, DisplayTarget.ResolveIndex(displayNumber, count));
    [Fact]
    public void PreviewLayout_OmittedSize_UsesMonitorMaximumAndCenters()
    {
        var (width, height) = PreviewLayout.SizeOnMonitor(1920, 1080, null, null);
        Assert.Equal(1920, width);
        Assert.Equal(1080, height);
        var (x, y) = PreviewLayout.CenterOrigin(1920, 1080, width, height);
        Assert.Equal(0, x);
        Assert.Equal(0, y);
    }
    [Fact]
    public void PreviewLayout_YamlSize_IsClampedAndCenteredOnMonitor()
    {
        var (width, height) = PreviewLayout.SizeOnMonitor(1920, 1080, 800, 600);
        Assert.Equal(800, width);
        Assert.Equal(600, height);
        var (x, y) = PreviewLayout.CenterOrigin(1920, 1080, width, height);
        Assert.Equal(560, x);
        Assert.Equal(240, y);
        var clamped = PreviewLayout.SizeOnMonitor(800, 600, 9999, 9999);
        Assert.Equal((800d, 600d), clamped);
    }
    [Fact]
    public void PreviewLayout_Tiled_FillsMonitorIgnoringYamlSize()
    {
        var size = PreviewLayout.SizeOnMonitor(1920, 1080, 800, 600, fillMonitor: true);
        Assert.Equal((1920d, 1080d), size);
        var origin = PreviewLayout.CenterOrigin(1920, 1080, size.Width, size.Height);
        Assert.Equal((0d, 0d), origin);
    }

    [Theory]
    [InlineData("❯ prompt\n\n   \n", "❯ prompt")]
    [InlineData("line\n", "line")]
    [InlineData("keep\n\nmiddle\n\n", "keep\n\nmiddle")]
    [InlineData("\n  \n", "")]
    public void PreviewLayout_TrimTrailingBlankLines_StopsAtPrompt(string input, string expected) =>
        Assert.Equal(expected, PreviewLayout.TrimTrailingBlankLines(input));
    [Fact]
    public void AppSettings_PreviewFont_FallsBackToListFont()
    {
        Assert.Equal(14, new AppSettings().EffectivePreviewFontSize);
        Assert.Equal(18, new AppSettings(PreviewFontSize: 18).EffectivePreviewFontSize);
        Assert.Equal("Fira Code", new AppSettings(FontName: "Fira Code").EffectivePreviewFontName);
        Assert.Equal("JetBrains Mono", new AppSettings(FontName: "Fira Code", PreviewFontName: "JetBrains Mono").EffectivePreviewFontName);
    }
    [Fact] public void CmdMappingDefault_IsUndecided()
    {
        Assert.Equal(CmdMapping.Undecided, new AppSettings().CmdMapping);
    }
    [Fact] public void AppSettings_NormalizesColumnsToOneOrTwo()
    {
        Assert.Equal(1, new AppSettings(BookmarkListColumns: 0).NormalizedColumns);
        Assert.Equal(2, new AppSettings(BookmarkListColumns: 3).NormalizedColumns);
    }
    [Fact] public void ListNameAndDetail_SplitAgentDirectoryFromTerminal()
    {
        var agent = new Bookmark("wsl:1", "claude @ WezTerm — focusbm", "", new WslProcessState(1, "claude", "WezTerm", WorkingDirectory: "/home/u/repos/focusbm"));
        Assert.Equal("focusbm", agent.ListName);
        Assert.Equal("claude @ WezTerm", agent.ListDetail);

        var browser = new Bookmark("gh-focusbm", "chrome", "", new BrowserAppState("https://github.com"));
        Assert.Equal("gh-focusbm", browser.ListName);
        Assert.Equal("chrome", browser.ListDetail);

        var noDirectory = new Bookmark("wsl:2", "codex @ WSL", "", new WslProcessState(2, "codex"));
        Assert.Equal("codex @ WSL", noDirectory.ListName);
        Assert.Equal("", noDirectory.ListDetail);
    }
}

public class PanelVisibilityTests
{
    [Fact] public void Deactivate_HidesOnlyWhenIdleAndVisible()
    {
        Assert.True(PanelVisibility.ShouldHideOnDeactivate(isVisible: true, allowClose: false, suppressDeactivate: false));
        Assert.False(PanelVisibility.ShouldHideOnDeactivate(isVisible: true, allowClose: false, suppressDeactivate: true));
        Assert.False(PanelVisibility.ShouldHideOnDeactivate(isVisible: false, allowClose: false, suppressDeactivate: false));
        Assert.False(PanelVisibility.ShouldHideOnDeactivate(isVisible: true, allowClose: true, suppressDeactivate: false));
    }
}

public class AgentRefreshScheduleTests
{
    [Fact] public void Interval_IsFasterWhileThePanelIsVisible()
    {
        Assert.Equal(TimeSpan.FromSeconds(3), AgentRefreshSchedule.Interval(panelVisible: true));
        Assert.Equal(TimeSpan.FromSeconds(15), AgentRefreshSchedule.Interval(panelVisible: false));
        Assert.True(AgentRefreshSchedule.VisibleInterval < AgentRefreshSchedule.HiddenInterval);
    }
}
