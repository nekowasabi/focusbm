using FocusBM.Core;
using FocusBM.Infrastructure.Windows.Wsl;
using Xunit;

namespace FocusBM.Infrastructure.Windows.Tests;

public sealed class WslProcessTests
{
    [Fact]
    public void Parse_FiltersDaemonsAndTmuxDescendants()
    {
        const string output = """
            1 0 /sbin/init
            10 1 /usr/bin/tmux server
            11 10 claude --inside-tmux
            20 1 claude --outside
            21 1 codex app-server
            22 1 codex mcp-server
            23 1 /usr/bin/aider --outside
            24 1 /usr/bin/codex --outside
            25 1 /usr/bin/claude-helper --outside
            malformed
            """;

        var processes = WslProcessService.Parse(output);

        Assert.Equal(new[] { 20, 23, 24 }, processes.Select(process => process.Pid));
    }

    [Fact]
    public void Parse_CanIncludeTmuxDescendantsForTmuxDiscoveryFallback()
    {
        const string output = "10 1 /usr/bin/tmux server\n11 10 claude --inside-tmux\n20 1 claude --outside\n";

        var processes = WslProcessService.Parse(output, includeTmuxDescendants: true);

        Assert.Equal(new[] { 11, 20 }, processes.Select(process => process.Pid));
    }

    [Fact]
    public void Parse_IgnoresMalformedRowsAndDuplicatePids()
    {
        const string output = "42 1 claude first\n42 1 claude duplicate\n0 0 claude invalid\n-1 1 codex invalid\nnot-a-row\n43 nope codex\n";

        var processes = WslProcessService.Parse(output);

        var process = Assert.Single(processes);
        Assert.Equal(42, process.Pid);
        Assert.Equal("claude first", process.Command);
    }

    [Fact]
    public void Parse_ExtractsDirectoryPaneAndTerminalMetadata()
    {
        const string output = "42\t1\t/home/alice/project\t%7\tWezTerm\tcodex --project\n";

        var process = Assert.Single(WslProcessService.Parse(output));

        Assert.Equal("/home/alice/project", process.CurrentDirectory);
        Assert.Equal("%7", process.TmuxPaneId);
        Assert.Equal("WezTerm", process.Terminal);
        Assert.Equal("codex", process.AgentName);
    }

    [Fact]
    public void Parse_RecognizesNewAgentsAndNodeWrappers()
    {
        const string output = """
            20 1 /usr/bin/opencode
            21 1 /usr/bin/pi
            22 1 /usr/bin/grok-1.0.4-linux-x64
            23 1 node /usr/local/lib/node_modules/@openai/codex/bin/codex
            24 1 node /usr/local/lib/node_modules/pi-coding-agent/dist/index.js
            25 1 node /opt/grok-1.0.4-linux-x64
            26 1 opencode serve
            29 1 devin --task review
            27 1 /usr/bin/cursor-agent --use-system-ca index.js --yolo
            28 1 node /usr/local/lib/node_modules/cursor-agent/bin/cursor-agent --yolo
            """;

        var processes = WslProcessService.Parse(output);

        Assert.Equal(new[] { 20, 21, 22, 23, 24, 25, 29, 27, 28 }, processes.Select(process => process.Pid));
        Assert.Equal(new[] { "OpenCode", "Pi", "Grok Build", "codex", "Pi", "Grok Build", "Devin CLI", "Cursor Agent", "Cursor Agent" }, processes.Select(process => process.AgentName));
        Assert.Equal(new[] { "opencode", "pi", "grok", "codex", "pi", "grok", "devin", "cursor-agent", "cursor-agent" }, processes.Select(process => process.AgentCommand));
    }

    [Fact]
    public void Parse_RecognizesPythonWrappedHermes()
    {
        const string output = """
            42	1	/home/alice/prayground	%31	WezTerm	/home/linuxbrew/.linuxbrew/Cellar/hermes-agent/2026.9.7/libexec/bin/python /home/linuxbrew/.linuxbrew/Cellar/hermes-agent/2026.9.7/libexec/bin/hermes
            43 1 python3 /opt/tools/bin/hermes --flag
            44 1 python3.13 /opt/tools/bin/hermes
            45 1 python /home/alice/bin/not-an-agent
            """;

        var processes = WslProcessService.Parse(output);

        Assert.Equal(new[] { 42, 43, 44 }, processes.Select(process => process.Pid));
        Assert.Equal(new[] { "hermes", "hermes", "hermes" }, processes.Select(process => process.AgentCommand));
        Assert.Equal("Hermes", processes[0].AgentName);
        Assert.Equal("/home/alice/prayground", processes[0].CurrentDirectory);
        Assert.Equal("%31", processes[0].TmuxPaneId);
        Assert.Equal("WezTerm", processes[0].Terminal);
    }

    [Fact]
    public void Parse_RecognizesDevinCliWithLiveTmuxMetadata()
    {
        const string output = "3316227\t2040\t/home/takets/repos/focusbm-win\t%4\tWezTerm\tdevin acp\n";

        var process = Assert.Single(WslProcessService.Parse(output, includeTmuxDescendants: true));

        Assert.Equal("devin", process.AgentCommand);
        Assert.Equal("Devin CLI", process.AgentName);
        Assert.Equal("%4", process.TmuxPaneId);
        Assert.Equal("WezTerm", process.Terminal);
    }

    [Fact]
    public async Task ListAIProcesses_UsesFixedWslArgumentsAndTimeout()
    {
        var runner = new FakeRunner(new ProcessRunResult(0, "20 1 codex --outside\n", string.Empty, false));
        var service = new WslProcessService(new WslSettings(Enabled: true, Distribution: "Ubuntu", User: "alice"), runner);

        var processes = await service.ListAIProcessesAsync();

        Assert.Single(processes);
        Assert.Equal("wsl.exe", runner.FileName);
        Assert.Equal(new[] { "--distribution", "Ubuntu", "--user", "alice", "--cd", "~", "--exec", "/bin/bash", "-lc" }, runner.Arguments.Take(9));
        Assert.Contains("ps -e -w -o pid=,ppid=,args=", runner.Arguments[9]);
        Assert.Contains("/proc/$pid/cwd", runner.Arguments[9]);
        Assert.Contains("cursor-agent", runner.Arguments[9]);
        Assert.Contains("devin", runner.Arguments[9]);
        Assert.Contains("bin/hermes", runner.Arguments[9]);
        Assert.DoesNotContain("|node|deno|bun|npx)", runner.Arguments[9]);
        Assert.Equal(TimeSpan.FromSeconds(1), runner.Timeout);
    }

    [Fact]
    public async Task ListAIProcesses_FailureReturnsEmpty()
    {
        var runner = new FakeRunner(new ProcessRunResult(1, string.Empty, "failed", false));
        var service = new WslProcessService(new WslSettings(Enabled: true), runner);

        Assert.Empty(await service.ListAIProcessesAsync());
    }

    [Fact]
    public async Task ListAIProcesses_TimeoutReturnsEmpty()
    {
        var runner = new FakeRunner(new ProcessRunResult(-1, string.Empty, "timeout", true));
        var service = new WslProcessService(new WslSettings(Enabled: true), runner);

        Assert.Empty(await service.ListAIProcessesAsync());
    }

    [Fact]
    public async Task ResolvePullRequest_UsesWorkingDirectoryAndValidatesUrl()
    {
        var runner = new FakeRunner(new ProcessRunResult(0, "https://github.com/org/repo/pull/42\n", string.Empty, false));
        var service = new WslProcessService(new WslSettings(Enabled: true, Distribution: "Ubuntu", User: "alice"), runner);

        var url = await service.ResolvePullRequestUrlAsync("codex", "/home/alice/repo");

        Assert.Equal("https://github.com/org/repo/pull/42", url!.AbsoluteUri);
        Assert.Equal(new[] { "--distribution", "Ubuntu", "--user", "alice", "--cd", "/home/alice/repo", "--exec", "gh", "pr", "view", "--json", "url", "--jq", ".url" }, runner.Arguments);
        Assert.Equal(TimeSpan.FromSeconds(5), runner.Timeout);
    }

    [Fact]
    public async Task ResolveClaudePullRequest_FallsBackToSessionIndexWhenGhFails()
    {
        var runner = new SequenceRunner(
        [
            new ProcessRunResult(0, "https://github.com/org/repo/pull/42\n", string.Empty, false)
        ]);
        var service = new WslProcessService(new WslSettings(Enabled: true), runner);

        var url = await service.ResolvePullRequestUrlAsync("claude", null, processId: 42);

        Assert.Equal("https://github.com/org/repo/pull/42", url!.AbsoluteUri);
        Assert.Equal("python3", runner.Calls[0].Arguments[7]);
        Assert.Contains("sessionId", runner.Calls[0].Arguments[9]);
    }

    [Fact]
    public async Task FocusProcess_UsesPowerShellAppActivateForWezTerm()
    {
        var runner = new SequenceRunner(
        [
            new ProcessRunResult(0, "TERM_PROGRAM=WezTerm\n", string.Empty, false),
            new ProcessRunResult(0, string.Empty, string.Empty, false)
        ]);
        var service = new WslProcessService(new WslSettings(Enabled: true, Distribution: "Ubuntu", User: "alice"), runner);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "claude"));

        Assert.True(result.IsSuccess);
        Assert.Equal(2, runner.Calls.Count);
        Assert.Equal("wsl.exe", runner.Calls[0].FileName);
        Assert.Contains("pid=42", runner.Calls[0].Arguments[9]);
        Assert.Equal("powershell.exe", runner.Calls[1].FileName);
        Assert.Equal(new[] { "-NoProfile", "-NonInteractive", "-Command" }, runner.Calls[1].Arguments.Take(3));
        Assert.Contains("'wezterm-gui'", runner.Calls[1].Arguments[3]);
        Assert.Contains("AppActivate($target)", runner.Calls[1].Arguments[3]);
        Assert.Contains("'tmux'", runner.Calls[1].Arguments[3]);
    }

    [Fact]
    public async Task FocusProcess_UnknownTerminalDoesNotActivateAnApp()
    {
        var runner = new SequenceRunner([new ProcessRunResult(0, string.Empty, string.Empty, false)]);
        var service = new WslProcessService(new WslSettings(Enabled: true), runner);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "claude"));

        Assert.Equal(OperationStatus.Unsupported, result.Status);
        Assert.Single(runner.Calls);
    }

    [Fact]
    public async Task FocusProcess_FocusesTerminalThenTmuxPane()
    {
        var runner = new SequenceRunner(
        [
            new ProcessRunResult(0, "TERM_PROGRAM=WezTerm\nTMUX_PANE=%7\n", string.Empty, false),
            new ProcessRunResult(0, string.Empty, string.Empty, false),
            new ProcessRunResult(0, "0\t3\n", string.Empty, false)
        ]);
        var service = new WslProcessService(new WslSettings(Enabled: true), runner);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "codex"));

        Assert.True(result.IsSuccess);
        Assert.Equal(OperationStatus.Success, result.Status);
        Assert.Contains("tmux pane focused", result.Message);
        Assert.Equal(3, runner.Calls.Count);
        Assert.Equal("wsl.exe", runner.Calls[2].FileName);
        Assert.Contains("select-window", runner.Calls[2].Arguments[9]);
        Assert.Contains("select-pane", runner.Calls[2].Arguments[9]);
        Assert.Contains("switch-client -c \"$client\" -t \"$pane_id\"", runner.Calls[2].Arguments[9]);
        Assert.DoesNotContain("switch-client -c \"$client\" -t \"$session:$window\"", runner.Calls[2].Arguments[9]);
        Assert.Equal(string.Empty, runner.Calls[2].Arguments[^1]);
    }

    [Fact]
    public async Task FocusProcess_PidZeroWithTerminal_ActivatesTerminalBeforeTmux()
    {
        var runner = new SequenceRunner([new ProcessRunResult(0, "dev\t0\n", string.Empty, false)]);
        var activation = new FakeActivation();
        var service = new WslProcessService(new WslSettings(Enabled: true), runner, activation);

        var result = await service.FocusProcessAsync(new WslProcessState(0, "codex", "WezTerm", "%7", "dev", "0"));

        Assert.True(result.IsSuccess);
        Assert.Equal("wezterm-gui", Assert.IsType<ActivationTarget.App>(activation.Target).AppName);
        var tmux = Assert.Single(runner.Calls);
        Assert.Equal("WezTerm", tmux.Arguments[^1]);
        Assert.Equal("%7", tmux.Arguments[^2]);
    }

    [Fact]
    public async Task FocusProcess_PidZeroWithTerminalOnly_ReturnsTerminalFocus()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "", "", false));
        var activation = new FakeActivation();
        var service = new WslProcessService(new WslSettings(Enabled: true), runner, activation);

        var result = await service.FocusProcessAsync(new WslProcessState(0, "codex", "WezTerm", TmuxSession: "dev", TmuxWindow: "0"));

        Assert.True(result.IsSuccess);
        Assert.Empty(runner.Calls);
        Assert.Equal("wezterm-gui", Assert.IsType<ActivationTarget.App>(activation.Target).AppName);
    }

    [Fact]
    public async Task FocusProcess_UsesCachedContextWithoutTerminalProbe()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "", "", false));
        var activation = new FakeActivation();
        var service = new WslProcessService(new WslSettings(Enabled: true), runner, activation);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "codex", "WezTerm"));

        Assert.True(result.IsSuccess);
        Assert.Empty(runner.Calls);
        Assert.Equal("wezterm-gui", Assert.IsType<ActivationTarget.App>(activation.Target).AppName);
    }

    [Fact]
    public async Task FocusProcess_WindowsTerminal_UsesActivationNotWtExe()
    {
        var runner = new RecordingRunner(new ProcessRunResult(0, "", "", false));
        var activation = new FakeActivation();
        var service = new WslProcessService(new WslSettings(Enabled: true), runner, activation);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "codex", "WindowsTerminal"));

        Assert.True(result.IsSuccess);
        Assert.Empty(runner.Calls);
        Assert.Equal("WindowsTerminal", Assert.IsType<ActivationTarget.App>(activation.Target).AppName);
    }

    [Fact]
    public async Task FocusProcess_CachedTmuxSession_SelectsPaneByIdNotSessionWindow()
    {
        var runner = new SequenceRunner([new ProcessRunResult(0, "dev\t0\n", string.Empty, false)]);
        var activation = new FakeActivation();
        var service = new WslProcessService(new WslSettings(Enabled: true), runner, activation);

        var result = await service.FocusProcessAsync(new WslProcessState(42, "codex", "WezTerm", "%7", "dev", "0"));

        Assert.True(result.IsSuccess);
        var tmux = Assert.Single(runner.Calls);
        Assert.Equal("WezTerm", tmux.Arguments[^1]);
        Assert.Equal("%7", tmux.Arguments[^2]);
        Assert.DoesNotContain("dev:0.%7", tmux.Arguments);
        Assert.Contains("client_session", tmux.Arguments[9]);
        Assert.Contains("client_pid", tmux.Arguments[9]);
        Assert.Contains("#{pane_id}", tmux.Arguments[9]);
    }

    private sealed class FakeRunner(ProcessRunResult result) : IProcessRunner
    {
        public string? FileName { get; private set; }
        public IReadOnlyList<string> Arguments { get; private set; } = Array.Empty<string>();
        public TimeSpan Timeout { get; private set; }

        public Task<ProcessRunResult> RunAsync(string fileName, IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken = default)
        {
            FileName = fileName;
            Arguments = arguments;
            Timeout = timeout;
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

    private sealed class RecordingRunner : IProcessRunner
    {
        public List<ProcessCall> Calls { get; } = [];

        public RecordingRunner(ProcessRunResult result) => Result = result;

        private ProcessRunResult Result { get; }

        public Task<ProcessRunResult> RunAsync(string fileName, IReadOnlyList<string> arguments, TimeSpan timeout, CancellationToken cancellationToken = default)
        {
            Calls.Add(new ProcessCall(fileName, arguments, timeout));
            return Task.FromResult(Result);
        }
    }

    private sealed class FakeActivation : IActivationService
    {
        public ActivationTarget? Target { get; private set; }

        public Task<OperationResult> ActivateAsync(ActivationTarget target, CancellationToken cancellationToken = default)
        {
            Target = target;
            return Task.FromResult(OperationResult.Success("activated", target));
        }
    }
}
