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
