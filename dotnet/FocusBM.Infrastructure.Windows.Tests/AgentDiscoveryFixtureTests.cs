using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Wsl;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

/// <summary>Regression fixture for the live five-agent panel (session 12 + dash).</summary>
public sealed class AgentDiscoveryFixtureTests
{
    private static readonly IReadOnlyDictionary<string, string> SessionTerminals =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["12"] = "WindowsTerminal",
            ["dash"] = "WezTerm",
        };

    private static readonly TmuxPaneInfo[] LivePanes =
    [
        new("12", "1", "%40", CurrentCommand: "claude", CurrentDirectory: "/home/takets/repos/changelog", WindowName: "claude"),
        new("12", "1", "%42", CurrentCommand: "nvim", Title: "changelog: wezterm_neovim changelogmemo", CurrentDirectory: "/home/takets/repos/changelog", WindowName: "claude"),
        new("dash", "1", "%0", CurrentCommand: "grok", CurrentDirectory: "/home/takets/repos/changelog", WindowName: "grok"),
        new("dash", "2", "%1", CurrentCommand: "claude", CurrentDirectory: "/home/takets/repos/doctrine-mcp", WindowName: "make"),
        new("dash", "3", "%2", CurrentCommand: "cursor-agent", CurrentDirectory: "/home/takets/repos/doctrine-mcp", WindowName: "cursor-agent"),
        new("dash", "5", "%4", CurrentCommand: "cursor-agent", CurrentDirectory: "/home/takets/repos/focusbm-win", WindowName: "cursor-agent"),
        new("dash", "5", "%62", CurrentCommand: "zsh", CurrentDirectory: "/home/takets/repos/focusbm-win", WindowName: "cursor-agent"),
        new("dash", "7", "%57", CurrentCommand: "npm", CurrentDirectory: "/home/takets/repos/dashboard", WindowName: "npm"),
    ];

    private static readonly WslProcessInfo[] LiveProcesses =
    [
        new(8360, 1, "claude --model sonnet", "/home/takets/repos/changelog", "%40", "WezTerm"),
        new(32575, 1, "grok", "/home/takets/repos/changelog", "%0", "WezTerm"),
        new(44252, 1, "claude --model sonnet", "/home/takets/repos/doctrine-mcp", "%1", "WezTerm"),
        new(2798, 1, "cursor-agent --yolo", "/home/takets/repos/doctrine-mcp", "%2", "WezTerm"),
        new(75431, 1, "cursor-agent --yolo", "/home/takets/repos/focusbm-win", "%4", "WezTerm"),
    ];

    private static readonly WslProcessInfo[] NoiseProcesses =
    [
        new(18934, 1, "claude bg-pty-host --bg-pty-host /tmp/foo.sock", "/home/takets/repos/kb"),
        new(22682, 1, "claude daemon run --json-path /tmp/d.json", "/home/takets"),
        new(27742, 1, "node /home/alice/.npm/_npx/copilot-language-server --stdio", "/home/takets", "%42", "WezTerm"),
        new(72111, 1, "claude bg-pty-host --bg-pty-host /tmp/bar.sock", "/home/takets/repos/doctrine-mcp", "%0", "WezTerm"),
    ];

    public static readonly string[] ExpectedDisplayLabels =
    [
        "claude @ Windows Terminal — changelog",
        "grok @ WezTerm — changelog",
        "claude @ WezTerm — doctrine-mcp",
        "Cursor Agent @ WezTerm — doctrine-mcp",
        "Cursor Agent @ WezTerm — focusbm-win",
    ];

    [Fact]
    public void Build_LiveFixture_ShowsOnlyFiveExpectedAgentRows()
    {
        var items = AgentSearchItems.Build(
            LivePanes,
            LiveProcesses.Concat(NoiseProcesses).ToArray(),
            showTmuxAgents: true,
            showWslAgents: true,
            tmuxDiscoverySucceeded: true,
            sessionTerminals: SessionTerminals);

        var agents = items.Where(item => item.IsAIAgent).ToArray();
        Assert.Equal(5, agents.Length);
        Assert.Equal(ExpectedDisplayLabels.OrderBy(label => label, StringComparer.Ordinal).ToArray(),
            agents.Select(agent => agent.AppName).OrderBy(label => label, StringComparer.Ordinal).ToArray());
        Assert.All(agents, agent => Assert.StartsWith("tmux:", agent.Id, StringComparison.Ordinal));
    }

    [Fact]
    public void Build_LiveFixture_Session12ClaudeUsesWindowsTerminalNotWezTerm()
    {
        var bookmark = AgentSearchItems.Build(
                LivePanes, LiveProcesses, true, true, true, SessionTerminals)
            .Single(item => item.Id == "tmux:12:1:%40");

        Assert.Equal("claude @ Windows Terminal — changelog", bookmark.AppName);
        Assert.Equal("WindowsTerminal", Assert.IsType<WslProcessState>(bookmark.State).Terminal);
    }

    [Fact]
    public void Parse_ExcludesDaemonAndLanguageServerNoise()
    {
        const string output = """
            8360	1	/home/takets/repos/changelog	%40	WezTerm	claude --model sonnet
            18934	1	/home/takets/repos/kb			claude bg-pty-host --bg-pty-host /tmp/foo.sock
            22682	1	/home/takets				claude daemon run --json-path /tmp/d.json
            27742	1	/home/takets	%42	WezTerm	node /home/alice/.npm/_npx/copilot-language-server --stdio
            72111	1	/home/takets/repos/doctrine-mcp	%0	WezTerm	claude bg-pty-host --bg-pty-host /tmp/bar.sock
            32575	1	/home/takets/repos/changelog	%0	WezTerm	grok
            """;

        var processes = WslProcessService.Parse(output, includeTmuxDescendants: true);

        Assert.Equal(new[] { 8360, 32575 }, processes.Select(process => process.Pid).OrderBy(pid => pid));
    }

    [Fact]
    public void ParseClientTerminals_MapsSessionsToAttachedTerminals()
    {
        const string output = """
            dash	WezTerm
            12	WindowsTerminal
            """;

        var map = WslTmuxService.ParseClientTerminals(output);

        Assert.Equal("WezTerm", map["dash"]);
        Assert.Equal("WindowsTerminal", map["12"]);
    }

    [Theory]
    [InlineData("WindowsTerminal", "Windows Terminal")]
    [InlineData("WezTerm", "WezTerm")]
    [InlineData("tmux", "tmux")]
    [InlineData(null, "WSL")]
    public void FormatTerminalLabel_HumanizesDisplayNames(string? terminal, string expected) =>
        Assert.Equal(expected, AgentIdentity.FormatTerminalLabel(terminal));
}
