using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Wsl;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;
public class WslTmuxTests
{
    [Fact] public async Task DisabledCapability_ReturnsEmptyList()
    {
        var svc = new WslTmuxService(new WslSettings(Enabled:false), new FakeRunner());
        Assert.Empty(await svc.ListPanesAsync());
    }
    [Fact] public async Task OptionLikePaneId_IsRejected()
    {
        var svc = new WslTmuxService(new WslSettings(Enabled:true), new FakeRunner());
        var result = await svc.FocusPaneAsync(new TmuxPaneState("s", "w", "--bad"));
        Assert.Equal(OperationStatus.ValidationError, result.Status);
    }

    [Fact] public async Task ListPanes_SearchesRuntimeAndTmpTmuxSockets()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "s\t0\t%1\tclaude\ttitle\n", "", false));
        var svc = new WslTmuxService(new WslSettings(Enabled:true), runner);

        var panes = await svc.ListPanesAsync();

        Assert.Single(panes);
        Assert.Contains("/run/user/*/tmux-*/*", runner.Arguments[9]);
        Assert.Contains("/tmp/tmux-*/*", runner.Arguments[9]);
        Assert.Contains("command -v tmux", runner.Arguments[9]);
        Assert.Contains("pane_current_path", runner.Arguments[9]);
    }

    [Fact] public void FilterPanesByAgent_HidesPanesWithoutAnAiProcess()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("s", "0", "%1", CurrentCommand: "codex"),
            new TmuxPaneInfo("s", "0", "%2", CurrentCommand: "bash")
        };
        var agentsByPane = new Dictionary<string, WslProcessInfo>
        {
            ["%1"] = new WslProcessInfo(42, 1, "codex --task", TmuxPaneId: "%1")
        };

        var filtered = WslTmuxService.FilterPanesByAgent(panes, agentsByPane);

        var pane = Assert.Single(filtered);
        Assert.Equal("%1", pane.PaneId);
    }

    [Fact] public void FilterPanesByAgent_KeepsAgentCommandPanesWhenProcessListIsEmpty()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("dash", "5", "%4", CurrentCommand: "cursor-agent", CurrentDirectory: "/home/alice/focusbm-win"),
            new TmuxPaneInfo("dash", "1", "%0", CurrentCommand: "zsh")
        };

        var filtered = WslTmuxService.FilterPanesByAgent(panes, new Dictionary<string, WslProcessInfo>());

        var pane = Assert.Single(filtered);
        Assert.Equal("%4", pane.PaneId);
    }

    [Fact]
    public void FilterPanesByAgent_HidesHeuristicPanesWhenProcessListHasAgents()
    {
        var panes = new[]
        {
            new TmuxPaneInfo("s", "0", "%1", CurrentCommand: "codex"),
            new TmuxPaneInfo("s", "0", "%2", CurrentCommand: "cursor-agent")
        };
        var agentsByPane = new Dictionary<string, WslProcessInfo>
        {
            ["%1"] = new WslProcessInfo(42, 1, "codex --task", TmuxPaneId: "%1")
        };

        var filtered = WslTmuxService.FilterPanesByAgent(panes, agentsByPane, allowHeuristicFallback: false);

        var pane = Assert.Single(filtered);
        Assert.Equal("%1", pane.PaneId);
    }

    [Theory]
    [InlineData("claude", "", TmuxAgentStatus.Idle)]
    [InlineData("claude", "⏸ plan mode on", TmuxAgentStatus.PlanMode)]
    [InlineData("codex", "⏵⏵ accept edits on", TmuxAgentStatus.AcceptEdits)]
    [InlineData("copilot", "• Working (3s · esc to interrupt)", TmuxAgentStatus.Running)]
    [InlineData("claude", "old output\n❯ ", TmuxAgentStatus.Idle)]
    public void DetectAgentStatus_ParsesTitleAndCapturedContent(string title, string content, TmuxAgentStatus expected) =>
        Assert.Equal(expected, WslTmuxService.DetectAgentStatus(title, content));

    [Fact]
    public async Task TryListPanes_WithStatus_CapturesAgentOutput()
    {
        var runner = new SequenceRunner(
        [
            new ProcessRunResult(0, "s\t0\t%1\tclaude\tClaude\t/home/alice\n", string.Empty, false),
            new ProcessRunResult(0, "• Working (3s · esc to interrupt)\n", string.Empty, false)
        ]);
        var svc = new WslTmuxService(new WslSettings(Enabled: true), runner);

        var result = await svc.TryListPanesAsync(CancellationToken.None, includeStatus: true);

        Assert.True(result.Succeeded);
        Assert.Equal(TmuxAgentStatus.Running, Assert.Single(result.Panes).AgentStatus);
        Assert.Contains("capture-pane", runner.Calls[1].Arguments[9]);
    }

    [Fact]
    public async Task RestoreNvim_FocusesSelectedPaneAndSendsExCommand()
    {
        var runner = new SequenceRunner(
        [
            new ProcessRunResult(0, "s\t2\t%7\tnvim\tNeovim\t/home/alice/project\n", string.Empty, false),
            new ProcessRunResult(0, "s\t2\n", string.Empty, false),
            new ProcessRunResult(0, string.Empty, string.Empty, false)
        ]);
        var svc = new WslTmuxService(new WslSettings(Enabled: true), runner);

        var result = await svc.RestoreAsync(new WslNvimState("/home/alice/project", "write"));

        Assert.True(result.IsSuccess);
        Assert.Equal(3, runner.Calls.Count);
        Assert.Contains("select-pane", runner.Calls[1].Arguments[9]);
        Assert.Equal("%7", runner.Calls[1].Arguments[^2]);
        Assert.Contains("send-keys", runner.Calls[2].Arguments[9]);
        Assert.Equal("write", runner.Calls[2].Arguments[^1]);
    }

    [Theory]
    [InlineData(":write")]
    [InlineData("write\nquit")]
    [InlineData("write\rquit")]
    public async Task RestoreNvim_RejectsUnsafeExCommand(string command)
    {
        var svc = new WslTmuxService(new WslSettings(Enabled: true), new FakeRunner());

        var result = await svc.RestoreAsync(new WslNvimState(ExCommand: command));

        Assert.Equal(OperationStatus.ValidationError, result.Status);
    }

    [Fact] public async Task FocusPaneById_SelectsWindowAndPane()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "s\t3\n", "", false));
        var svc = new WslTmuxService(new WslSettings(Enabled:true), runner);

        var result = await svc.FocusPaneByIdAsync("%7");

        Assert.True(result.IsSuccess);
        var target = Assert.IsType<ActivationTarget.TmuxPane>(result.Target);
        Assert.Equal("s", target.Session);
        Assert.Equal("3", target.Window);
        Assert.Equal("%7", target.PaneId);
        Assert.Contains("select-window", runner.Arguments[9]);
        Assert.Contains("select-pane", runner.Arguments[9]);
        Assert.Contains("list-clients", runner.Arguments[9]);
        Assert.Contains("switch-client", runner.Arguments[9]);
        Assert.Contains("client_session", runner.Arguments[9]);
        Assert.Contains("client_pid", runner.Arguments[9]);
        Assert.Contains("detect_terminal_from_pid", runner.Arguments[9]);
        Assert.Contains("#{pane_id}", runner.Arguments[9]);
        Assert.Contains("switch-client -c \"$client\" -t \"$pane_id\"", runner.Arguments[9]);
        Assert.Contains("select-window -t \"$session:$window\"", runner.Arguments[9]);
        Assert.DoesNotContain("switch-client -c \"$client\" -t \"$session:$window\"", runner.Arguments[9]);
        Assert.DoesNotContain("switch-client -c \"$client\" -t \"$session:$window\" || continue", runner.Arguments[9]);
        Assert.DoesNotContain("$3 == w", runner.Arguments[9]);
        Assert.Equal("%7", runner.Arguments[^2]);
        Assert.Equal(string.Empty, runner.Arguments[^1]);
    }

    [Fact]
    public async Task FocusPaneById_PassesTerminalHintToScript()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "s\t3\n", "", false));
        var svc = new WslTmuxService(new WslSettings(Enabled:true), runner);

        var result = await svc.FocusPaneByIdAsync("%7", "WezTerm");

        Assert.True(result.IsSuccess);
        Assert.Equal("WezTerm", runner.Arguments[^1]);
        Assert.Equal("%7", runner.Arguments[^2]);
        Assert.Contains("detect_terminal_from_pid", runner.Arguments[9]);
        Assert.Contains("terminal_hint=\"$2\"", runner.Arguments[9]);
        Assert.Contains("terminal_hint\" ] && [ -z \"$client\" ]", runner.Arguments[9]);
    }

    [Fact]
    public async Task FocusPaneAsync_PaneId_SelectsByPaneIdNotSessionWindow()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "dev\t0\n", "", false));
        var svc = new WslTmuxService(new WslSettings(Enabled:true), runner);

        var result = await svc.FocusPaneAsync(new TmuxPaneState("dev", "0", "%7"));

        Assert.True(result.IsSuccess);
        Assert.Equal("%7", runner.Arguments[^2]);
        Assert.Contains("client_session", runner.Arguments[9]);
        Assert.Contains("client_pid", runner.Arguments[9]);
        Assert.Contains("#{pane_id}", runner.Arguments[9]);
    }

    private sealed class FakeRunner : IProcessRunner { public Task<ProcessRunResult> RunAsync(string f, IReadOnlyList<string> a, TimeSpan t, CancellationToken c = default) => Task.FromResult(new ProcessRunResult(0, "s\t0\t%1\tclaude\ttitle\n", "", false)); }

    private sealed class RecordingRunner(ProcessRunResult result) : IProcessRunner
    {
        public IReadOnlyList<string> Arguments { get; private set; } = Array.Empty<string>();
        public Task<ProcessRunResult> RunAsync(string f, IReadOnlyList<string> a, TimeSpan t, CancellationToken c = default)
        {
            Arguments = a;
            return Task.FromResult(result);
        }
    }

    private sealed class SequenceRunner(IReadOnlyList<ProcessRunResult> results) : IProcessRunner
    {
        private int _index;
        public List<ProcessCall> Calls { get; } = [];

        public Task<ProcessRunResult> RunAsync(string fileName, IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken = default)
        {
            Calls.Add(new ProcessCall(fileName, arguments, timeout));
            return Task.FromResult(results[Math.Min(_index++, results.Count - 1)]);
        }
    }

    private sealed record ProcessCall(string FileName, IReadOnlyList<string> Arguments, TimeSpan Timeout);

}
