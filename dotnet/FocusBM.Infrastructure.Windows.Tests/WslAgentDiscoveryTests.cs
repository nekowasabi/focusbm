using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Wsl;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public sealed class WslAgentDiscoveryTests
{
    [Fact]
    public void Parse_SplitsSectionsAndFlags()
    {
        const string output = """
            @PANES
            dash	1	%0	grok	title	/home/takets/repos/changelog	grok
            12	1	%40	claude	title2	/home/takets/repos/doctrine-mcp	claude
            @CLIENTS
            dash	WezTerm
            12	WindowsTerminal
            @PROCESSES
            8360	1	/home/takets/repos/changelog	%40	WezTerm	claude --model sonnet
            32575	1	/home/takets/repos/changelog	%0	WezTerm	grok
            18934	1	/home/takets/repos/kb			claude bg-pty-host --bg-pty-host /tmp/foo.sock
            @STATUS	1	1	1
            
            """;

        var snapshot = WslAgentDiscoveryService.Parse(output, includeTmuxDescendants: true);

        Assert.True(snapshot.TmuxDiscoverySucceeded);
        Assert.True(snapshot.ProcessDiscoverySucceeded);
        Assert.Equal(2, snapshot.Panes.Count);
        Assert.Equal("dash", snapshot.Panes[0].Session);
        Assert.Equal("WezTerm", snapshot.SessionTerminals["dash"]);
        Assert.Equal("WindowsTerminal", snapshot.SessionTerminals["12"]);
        Assert.Equal(new[] { 8360, 32575 }, snapshot.Processes.Select(p => p.Pid).OrderBy(p => p));
    }

    [Fact]
    public void Parse_AttachesCachedPaneCaptureWithoutLiveWsl()
    {
        const string output = """
            @PANES
            dash	5	%52	cursor-agent	Preview On Hover	/home/takets/repos/focusbm-win	cursor-agent
            @CAPTURES
            <<PANE %52>>
            ❯ 1. continue
              2. something else
            <<END>>
            @CLIENTS
            dash	WezTerm
            @PROCESSES
            42	1	/home/takets/repos/focusbm-win	%52	WezTerm	cursor-agent --yolo
            @STATUS	1	1	1
            
            """;

        var snapshot = WslAgentDiscoveryService.Parse(output);

        var pane = Assert.Single(snapshot.Panes);
        Assert.Equal("%52", pane.PaneId);
        Assert.Contains("❯ 1. continue", pane.CaptureText);
        var bookmark = AgentSearchItems.CreateTmuxBookmark(pane, snapshot.Processes[0]);
        var state = Assert.IsType<WslProcessState>(bookmark.State);
        Assert.Contains("❯ 1. continue", state.ScreenCapture);
    }

    [Fact]
    public void Parse_KeepsLaterPaneCaptureWhenEarlierCaptureContainsAtMention()
    {
        const string output = """
            @PANES
            dash	3	%2	cursor-agent	Preview On Hover	/tmp/cursor	cursor-agent
            dash	8	%53	node	Respond to hello	/tmp/codex	node
            @CAPTURES
            <<PANE %2>>
            @codebase
            cursor screen
            <<END>>
            <<PANE %53>>
            › hello from codex
            <<END>>
            @CLIENTS
            dash	WezTerm
            @PROCESSES
            1	1	/tmp/cursor	%2	WezTerm	cursor-agent --yolo
            2	1	/tmp/codex	%53	WezTerm	node /opt/bin/codex --yolo
            @STATUS	1	1	1
            
            """;

        var snapshot = WslAgentDiscoveryService.Parse(output);

        Assert.True(snapshot.ProcessDiscoverySucceeded);
        var codex = Assert.Single(snapshot.Panes, pane => pane.PaneId == "%53");
        Assert.Contains("hello from codex", codex.CaptureText);
        var cursor = Assert.Single(snapshot.Panes, pane => pane.PaneId == "%2");
        Assert.Contains("@codebase", cursor.CaptureText);
        var bookmark = AgentSearchItems.CreateTmuxBookmark(codex, snapshot.Processes.Single(process => process.Pid == 2));
        var state = Assert.IsType<WslProcessState>(bookmark.State);
        Assert.Contains("hello from codex", state.ScreenCapture);
    }

    [Fact]
    public void Parse_MissingStatusReturnsEmpty()
    {
        var snapshot = WslAgentDiscoveryService.Parse("@PANES\ndash\t1\t%0\n@PROCESSES\n20 1 codex\n");

        Assert.False(snapshot.TmuxDiscoverySucceeded);
        Assert.False(snapshot.ProcessDiscoverySucceeded);
        Assert.Empty(snapshot.Panes);
        Assert.Empty(snapshot.Processes);
    }

    [Fact]
    public void Parse_PsFailureFlagPropagates()
    {
        const string output = "@PANES\n@CLIENTS\n@PROCESSES\n@STATUS\t0\t0\t0\n\x1e\n";

        var snapshot = WslAgentDiscoveryService.Parse(output);

        Assert.False(snapshot.ProcessDiscoverySucceeded);
        Assert.False(snapshot.TmuxDiscoverySucceeded);
    }

    [Fact]
    public void Parse_EmptyTmuxSectionsYieldZeroPanes()
    {
        const string output = "@PANES\n@CLIENTS\n@PROCESSES\n42\t1\t/home/x\t%3\tWezTerm\tcodex\n@STATUS\t1\t0\t0\n\x1e\n";

        var snapshot = WslAgentDiscoveryService.Parse(output);

        Assert.False(snapshot.TmuxDiscoverySucceeded);
        Assert.True(snapshot.ProcessDiscoverySucceeded);
        Assert.Empty(snapshot.SessionTerminals);
        var process = Assert.Single(snapshot.Processes);
        Assert.Equal(42, process.Pid);
        Assert.Equal("%3", process.TmuxPaneId);
    }
}
