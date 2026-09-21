using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Wsl;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public sealed class AgentSearchItemsTests
{
    [Fact]
    public void Build_PutsRunningTmuxAgentsOnTheSearchPanelWhenProcessListTimesOut()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("dash", "5", "%4", CurrentCommand: "cursor-agent", Title: "Add Directory", CurrentDirectory: "/home/alice/focusbm-win", WindowName: "cursor-agent"),
            new TmuxPaneInfo("dash", "1", "%0", CurrentCommand: "zsh", CurrentDirectory: "/tmp")
        };

        var items = AgentSearchItems.Build(panes, Array.Empty<WslProcessInfo>(), showTmuxAgents: true, showWslAgents: true, tmuxDiscoverySucceeded: true, processDiscoverySucceeded: false);
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(ShowAIAgentShortcut: false), items));

        var shown = Assert.Single(vm.Results);
        Assert.Equal("tmux:dash:5:%4", shown.Id);
        Assert.Contains("focusbm-win", shown.DisplayLabel);
        Assert.True(shown.IsAIAgent);
    }

    [Fact]
    public void Build_HidesUnmappedHeuristicTmuxPanesWhenWslAgentsAvailable()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("dash", "5", "%4", CurrentCommand: "codex", CurrentDirectory: "/home/alice/repo"),
            new TmuxPaneInfo("dash", "6", "%5", CurrentCommand: "cursor-agent", Title: "Add Directory", CurrentDirectory: "/home/alice/focusbm-win")
        };
        var processes = new[] { new WslProcessInfo(42, 1, "codex --project", "/home/alice/repo", "%4", "WezTerm") };

        var items = AgentSearchItems.Build(panes, processes, showTmuxAgents: true, showWslAgents: true, tmuxDiscoverySucceeded: true);

        Assert.Single(items.Where(item => item.Id.StartsWith("tmux:", StringComparison.Ordinal)));
        Assert.Equal("tmux:dash:5:%4", items.Single(item => item.Id.StartsWith("tmux:", StringComparison.Ordinal)).Id);
    }

    [Fact]
    public void Build_HidesDeadTmuxPaneWhenProcessDiscoverySucceededWithZeroAgents()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("12", "1", "%40", CurrentCommand: "claude", CurrentDirectory: "/home/takets/repos/changelog", WindowName: "claude"),
            new TmuxPaneInfo("12", "1", "%42", CurrentCommand: "nvim", CurrentDirectory: "/home/takets/repos/changelog", WindowName: "claude"),
        };

        var items = AgentSearchItems.Build(
            panes,
            Array.Empty<WslProcessInfo>(),
            showTmuxAgents: true,
            showWslAgents: true,
            tmuxDiscoverySucceeded: true,
            processDiscoverySucceeded: true);

        Assert.Empty(items.Where(item => item.IsAIAgent));
    }

    [Fact]
    public void Build_ListsWslAgentWhenProcessDiscoverySucceeds()
    {
        var process = new WslProcessInfo(42, 1, "codex --project", "/home/alice/repo", null, "WezTerm");
        var items = AgentSearchItems.Build(Array.Empty<TmuxPaneInfo>(), new[] { process }, showTmuxAgents: true, showWslAgents: true, tmuxDiscoverySucceeded: false);
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), items));

        var shown = Assert.Single(vm.Results);
        Assert.Equal("wsl:42", shown.Id);
        Assert.Equal("codex @ WezTerm — repo", shown.DisplayLabel);
    }

    [Fact]
    public void Build_MapsPythonWrappedHermesTmuxProcessToSearchPanel()
    {
        var panes = new[] { new TmuxPaneInfo("win-terminal", "2", "%31", CurrentCommand: "python", Title: "prayground: hermes", CurrentDirectory: "/home/alice/prayground") };
        var processes = new[] { new WslProcessInfo(42, 1, "/brew/bin/python /brew/libexec/bin/hermes", "/home/alice/prayground", "%31", "WezTerm") };

        var items = AgentSearchItems.Build(panes, processes, showTmuxAgents: true, showWslAgents: true, tmuxDiscoverySucceeded: true);
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), items));

        var shown = Assert.Single(vm.Results);
        Assert.Equal("tmux:win-terminal:2:%31", shown.Id);
        Assert.Equal("Hermes @ WezTerm — prayground", shown.DisplayLabel);
        Assert.Equal("📨", shown.AgentEmoji);
    }

    [Fact]
    public void Build_MapsDevinCliTmuxProcessToSearchPanel()
    {
        var panes = new[] { new TmuxPaneInfo("dev", "0", "%4", CurrentCommand: "devin", CurrentDirectory: "/home/alice/repo") };
        var processes = new[] { new WslProcessInfo(42, 1, "devin acp", "/home/alice/repo", "%4", "WezTerm") };

        var items = AgentSearchItems.Build(panes, processes, showTmuxAgents: true, showWslAgents: true, tmuxDiscoverySucceeded: true);
        var vm = new SearchPanelViewModel();
        vm.Load(new BookmarkStore(new AppSettings(), items));

        var shown = Assert.Single(vm.Results);
        Assert.Equal("tmux:dev:0:%4", shown.Id);
        Assert.Equal("Devin CLI @ WezTerm — repo", shown.DisplayLabel);
    }
}
