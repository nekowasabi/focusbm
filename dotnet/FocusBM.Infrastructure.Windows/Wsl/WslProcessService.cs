using FocusBM.Core;
using System.Text.RegularExpressions;

namespace FocusBM.Infrastructure.Windows.Wsl;

public sealed record WslProcessInfo(
    int Pid,
    int ParentPid,
    string Command,
    string? CurrentDirectory = null,
    string? TmuxPaneId = null,
    string? Terminal = null)
{
    public string AgentName => WslProcessService.GetAgentDisplayName(Command);
    public string AgentCommand => WslProcessService.GetAgentCommand(Command) ?? WslProcessService.GetCommandName(Command);
}

public sealed class WslProcessService : IWslProcessFocusService
{
    private static readonly string[] AllowedCommands = ["claude", "aider", "gemini", "copilot", "codex", "devin", "hermes", "opencode", "pi", "grok", "cursor-agent"];
    private static readonly TimeSpan CommandTimeout = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan PullRequestTimeout = TimeSpan.FromSeconds(5);
    private const string SessionPullRequestScript = """
        import json
        import pathlib
        import sys

        pid = int(sys.argv[1])
        home = pathlib.Path.home()
        registry = home / ".claude" / "sessions" / f"{pid}.json"
        try:
            data = json.loads(registry.read_text())
            if int(data.get("pid", -1)) != pid or not data.get("sessionId"):
                raise ValueError
            session_id = data["sessionId"]
            for index_path in (home / ".claude" / "projects").rglob("sessions-index.json"):
                for entry in json.loads(index_path.read_text()).get("entries", []):
                    if entry.get("sessionId") == session_id and entry.get("prUrl"):
                        print(entry["prUrl"])
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            pass
        """;
    private const string PowerShellAppActivateScript = "$wshell = New-Object -ComObject WScript.Shell; foreach ($target in @('wezterm-gui', 'tmux', 'WezTerm')) { if ($wshell.AppActivate($target)) { exit 0 } }; exit 1";
    private const string ProcessListScript = """
        ps -e -w -o pid=,ppid=,args= |
        while IFS= read -r row; do
          read -r pid ppid command <<< "$row"
          case "$pid" in ''|*[!0-9]*) continue;; esac
          case "$ppid" in ''|*[!0-9]*) continue;; esac
          [ -n "$command" ] || continue
          command_name=${command%% *}
          command_name=${command_name##*/}
          case "$command_name" in
            python|python3|python3.[0-9]*)
              case "$command" in
                *bin/hermes*|*"/hermes "*) command_name="hermes" ;;
              esac
              ;;
          esac
          cwd=""
          pane=""
          terminal=""
          case "$command_name" in
            claude|aider|gemini|copilot|codex|devin|hermes|opencode|pi|grok|grok-[0-9]*|cursor-agent)
              case "$command" in
                *" app-server"*|*" mcp-server"*|*" --chrome-native-host"*|*"opencode serve"*|*" bg-pty-host"*|*" bg-spare"*|*" daemon run"*) ;;
                *)
                  cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
                  probe_pid=$pid
                  depth=0
                  while [ "$probe_pid" -gt 0 ] && [ "$depth" -lt 64 ] && { [ -z "$pane" ] || [ -z "$terminal" ]; }; do
                    if [ -r "/proc/$probe_pid/environ" ]; then
                      while IFS= read -r -d '' variable; do
                        case "$variable" in
                          TMUX_PANE=*)
                            candidate_pane=${variable#TMUX_PANE=}
                            if [[ "$candidate_pane" =~ ^%[0-9]+$ ]] && [ -z "$pane" ]; then pane="$candidate_pane"; fi
                            ;;
                          WT_SESSION=*) [ -z "$terminal" ] && terminal="WindowsTerminal" ;;
                          TERM_PROGRAM=WezTerm) [ -z "$terminal" ] && terminal="WezTerm" ;;
                          VSCODE_IPC_HOOK_CLI=*) [ -z "$terminal" ] && terminal="VSCode" ;;
                          ALACRITTY_*=*) [ -z "$terminal" ] && terminal="Alacritty" ;;
                        esac
                      done < "/proc/$probe_pid/environ"
                    fi
                    next=$(ps -o ppid= -p "$probe_pid" 2>/dev/null | tr -d ' ')
                    case "$next" in ''|*[!0-9]*) break;; esac
                    probe_pid=$next
                    depth=$((depth + 1))
                  done
                  ;;
              esac
              ;;
          esac
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$ppid" "$cwd" "$pane" "$terminal" "$command"
        done
        """;
    private readonly WslSettings _settings;
    private readonly IProcessRunner _runner;
    private readonly WslTmuxService _tmux;
    private readonly IActivationService? _activation;
    private readonly IRestoreTimingSink? _timing;

    public WslProcessService(
        WslSettings settings,
        IProcessRunner runner,
        IActivationService? activation = null,
        IRestoreTimingSink? timing = null)
    {
        _settings = settings;
        _runner = runner;
        _activation = activation;
        _timing = timing;
        _tmux = new WslTmuxService(settings, runner, timing);
    }

    public Task<IReadOnlyList<WslProcessInfo>> ListAIProcessesAsync(CancellationToken cancellationToken = default) =>
        ListAIProcessesAsync(includeTmuxDescendants: false, cancellationToken: cancellationToken);

    public async Task<IReadOnlyList<WslProcessInfo>> ListAIProcessesAsync(bool includeTmuxDescendants, CancellationToken cancellationToken = default) =>
        (await TryListAIProcessesAsync(includeTmuxDescendants, cancellationToken).ConfigureAwait(false)).Processes;

    public async Task<(IReadOnlyList<WslProcessInfo> Processes, bool Succeeded)> TryListAIProcessesAsync(
        bool includeTmuxDescendants = false,
        CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return (Array.Empty<WslProcessInfo>(), false);
        try
        {
            var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", ProcessListScript, "focusbm-wsl-processes"]).ToArray();
            var result = await _runner.RunAsync("wsl.exe", args, CommandTimeout, cancellationToken).ConfigureAwait(false);
            if (result.TimedOut || result.ExitCode != 0) return (Array.Empty<WslProcessInfo>(), false);
            return (Parse(result.StandardOutput, includeTmuxDescendants), true);
        }
        // Why: WSL process discovery is optional; an unavailable or timed-out wsl.exe must not block startup.
        catch { return (Array.Empty<WslProcessInfo>(), false); }
    }

    public async Task<OperationResult> FocusProcessAsync(WslProcessState process, CancellationToken cancellationToken = default)
    {
        var timing = new RestoreTimingScope("wsl:focus", _timing);
        timing.Mark("start");
        if (!_settings.Enabled)
        {
            return OperationResult.VisibleError(OperationStatus.Unsupported, "WSL process focus is disabled");
        }
        if (process.Pid <= 0)
        {
            var terminal = ParseTerminal(process.Terminal);
            var paneId = IsPaneId(process.TmuxPaneId) ? process.TmuxPaneId : null;
            if (terminal is not null)
            {
                timing.Mark("terminal:start");
                var terminalFocus = await FocusTerminalAsync(terminal.Value, cancellationToken).ConfigureAwait(false);
                timing.Mark("terminal:complete", terminalFocus.Status.ToString());
                if (!terminalFocus.IsSuccess) return terminalFocus;
                if (paneId is null) return terminalFocus;

                timing.Mark("tmux:start");
                var paneFocus = await _tmux.FocusPaneByIdAsync(paneId, process.Terminal, cancellationToken).ConfigureAwait(false);
                timing.Mark("tmux:complete", paneFocus.Status.ToString());
                return paneFocus.IsSuccess
                    ? OperationResult.Success($"{terminalFocus.Message}; {paneFocus.Message}", paneFocus.Target)
                    : new OperationResult(OperationStatus.Partial, $"{terminalFocus.Message}; tmux pane switch failed: {paneFocus.Message}", terminalFocus.Target);
            }
            if (IsPaneId(process.TmuxPaneId))
                return await _tmux.FocusPaneByIdAsync(process.TmuxPaneId!, process.Terminal, cancellationToken).ConfigureAwait(false);
            return OperationResult.VisibleError(OperationStatus.ValidationError, "WSL process PID is invalid");
        }

        try
        {
            var terminal = ParseTerminal(process.Terminal);
            var paneId = IsPaneId(process.TmuxPaneId) ? process.TmuxPaneId : null;
            if (terminal is null)
            {
                timing.Mark("probe:start");
                var environment = await _runner.RunAsync("wsl.exe", BuildTerminalEnvironmentArgs(process.Pid), CommandTimeout, cancellationToken).ConfigureAwait(false);
                timing.Mark("probe:complete", environment.TimedOut ? "timeout" : environment.ExitCode.ToString());
                if (environment.TimedOut)
                {
                    return OperationResult.VisibleError(OperationStatus.Timeout, "WSL process terminal detection timed out");
                }
                if (environment.ExitCode != 0)
                {
                    return OperationResult.VisibleError(OperationStatus.NotFound, "WSL process is no longer available");
                }

                var context = ParseProcessContext(environment.StandardOutput);
                terminal = context.Terminal;
                paneId ??= context.TmuxPaneId;
                if (terminal is null)
                {
                    return OperationResult.VisibleError(OperationStatus.Unsupported, "WSL process terminal could not be determined");
                }
            }

            timing.Mark("terminal:start");
            var terminalFocus = await FocusTerminalAsync(terminal.Value, cancellationToken).ConfigureAwait(false);
            timing.Mark("terminal:complete", terminalFocus.Status.ToString());
            if (!terminalFocus.IsSuccess || paneId is null) return terminalFocus;

            timing.Mark("tmux:start");
            var paneFocus = await _tmux.FocusPaneByIdAsync(paneId, process.Terminal, cancellationToken).ConfigureAwait(false);
            timing.Mark("tmux:complete", paneFocus.Status.ToString());
            return paneFocus.IsSuccess
                ? OperationResult.Success($"{terminalFocus.Message}; {paneFocus.Message}", paneFocus.Target)
                : new OperationResult(OperationStatus.Partial, $"{terminalFocus.Message}; tmux pane switch failed: {paneFocus.Message}", terminalFocus.Target);
        }
        catch (InvalidOperationException ex)
        {
            return OperationResult.VisibleError(OperationStatus.ValidationError, Redactor.Mask(ex.Message));
        }
        catch (Exception ex)
        {
            return OperationResult.VisibleError(OperationStatus.Failed, $"WSL process focus failed: {Redactor.Mask(ex.Message)}");
        }
    }

    public async Task<Uri?> ResolvePullRequestUrlAsync(
        string command,
        string? workingDirectory,
        CancellationToken cancellationToken = default,
        int processId = 0)
    {
        var agentCommand = GetAgentCommand(command);
        if (!_settings.Enabled
            || !GitHubPullRequest.SupportsAgent(agentCommand)
            || workingDirectory?.StartsWith("-", StringComparison.Ordinal) == true) return null;

        try
        {
            if (!string.IsNullOrWhiteSpace(workingDirectory))
            {
                var args = BaseArgs(workingDirectory).Concat(["--exec", "gh", "pr", "view", "--json", "url", "--jq", ".url"]).ToArray();
                var result = await _runner.RunAsync("wsl.exe", args, PullRequestTimeout, cancellationToken).ConfigureAwait(false);
                var url = result.TimedOut || result.ExitCode != 0 ? null : GitHubPullRequest.Validate(result.StandardOutput);
                if (url is not null) return url;
            }
            return string.Equals(agentCommand, "claude", StringComparison.OrdinalIgnoreCase)
                ? await ResolveSessionPullRequestUrlAsync(processId, cancellationToken).ConfigureAwait(false)
                : null;
        }
        catch
        {
            return null;
        }
    }

    private async Task<Uri?> ResolveSessionPullRequestUrlAsync(int processId, CancellationToken cancellationToken)
    {
        if (processId <= 0) return null;
        var args = BaseArgs().Concat(["--exec", "python3", "-c", SessionPullRequestScript, processId.ToString()]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, PullRequestTimeout, cancellationToken).ConfigureAwait(false);
        return result.TimedOut || result.ExitCode != 0
            ? null
            : GitHubPullRequest.Unique(result.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries));
    }


    public static IReadOnlyList<WslProcessInfo> Parse(string output, bool includeTmuxDescendants = false)
    {
        var rows = output.Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(ParseRow)
            .Where(x => x is not null)
            .Select(x => x!)
            .GroupBy(x => x.Pid)
            .Select(group => group.First())
            .ToList();
        var byPid = rows.ToDictionary(x => x.Pid);
        return rows
            .Where(IsAIProcess)
            .Where(x => includeTmuxDescendants || !HasTmuxAncestor(x, byPid))
            .ToList();
    }

    private static WslProcessInfo? ParseRow(string line)
    {
        var tabParts = line.TrimEnd('\r').Split('\t', 6, StringSplitOptions.None);
        if (tabParts.Length >= 6
            && int.TryParse(tabParts[0], out var tabPid)
            && tabPid > 0
            && int.TryParse(tabParts[1], out var tabPpid)
            && tabPpid >= 0)
        {
            return new WslProcessInfo(
                tabPid,
                tabPpid,
                tabParts[5],
                NullIfEmpty(tabParts[2]),
                IsPaneId(tabParts[3]) ? tabParts[3] : null,
                NullIfEmpty(tabParts[4]));
        }
        var parts = line.Trim().Split((char[]?)null, 3, StringSplitOptions.RemoveEmptyEntries);
        return parts.Length == 3 && int.TryParse(parts[0], out var pid) && pid > 0 && int.TryParse(parts[1], out var ppid) && ppid >= 0
            ? new WslProcessInfo(pid, ppid, parts[2])
            : null;
    }

    internal static bool IsAgentProcess(WslProcessInfo process) =>
        GetAgentCommand(process.Command) is not null && !IsDaemonCommandLine(process.Command);

    private static bool IsAIProcess(WslProcessInfo process) => IsAgentProcess(process);

    internal static string GetCommandName(string command)
    {
        var firstToken = command.Split((char[]?)null, 2, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? string.Empty;
        var separator = Math.Max(firstToken.LastIndexOf('/'), firstToken.LastIndexOf('\\'));
        return separator >= 0 ? firstToken[(separator + 1)..] : firstToken;
    }

    internal static string? GetAgentCommand(string command)
    {
        var commandName = GetCommandName(command).ToLowerInvariant();
        if (AllowedCommands.Contains(commandName, StringComparer.OrdinalIgnoreCase)) return commandName;
        if (IsVersionedGrok(commandName)) return "grok";
        if (!IsWrapperRuntime(commandName)) return null;
        if (command.Contains("copilot-language-server", StringComparison.OrdinalIgnoreCase)) return null;

        foreach (var candidate in AllowedCommands)
        {
            if (candidate == "pi")
            {
                if (command.Contains("pi-coding-agent", StringComparison.OrdinalIgnoreCase)
                    || command.Contains("@earendil-works", StringComparison.OrdinalIgnoreCase)
                    || command.Contains("@mariozechner", StringComparison.OrdinalIgnoreCase)) return candidate;
                continue;
            }
            if (candidate == "grok")
            {
                if (Regex.IsMatch(command, @"(^|/)grok-[0-9]", RegexOptions.IgnoreCase)) return candidate;
                continue;
            }
            if (command.Contains("bin/" + candidate, StringComparison.OrdinalIgnoreCase)
                || command.Contains("/" + candidate + " ", StringComparison.OrdinalIgnoreCase)) return candidate;
        }
        return null;
    }

    internal static string GetAgentDisplayName(string command) => GetAgentCommand(command) switch
    {
        "devin" => "Devin CLI",
        "hermes" => "Hermes",
        "opencode" => "OpenCode",
        "pi" => "Pi",
        "grok" => string.Equals(GetCommandName(command), "grok", StringComparison.OrdinalIgnoreCase) ? "grok" : "Grok Build",
        "cursor-agent" => "Cursor Agent",
        var agent when agent is not null => agent,
        _ => GetCommandName(command)
    };

    // Why: Homebrew hermes-agent runs as `python .../bin/hermes`, so Python launchers resolve wrapped agents like node/deno/bun/npx.
    private static bool IsWrapperRuntime(string commandName) =>
        commandName is "node" or "deno" or "bun" or "npx" or "python" or "python3"
        || (commandName.StartsWith("python3.", StringComparison.Ordinal)
            && commandName.Length > "python3.".Length
            && char.IsDigit(commandName["python3.".Length]));

    private static bool IsVersionedGrok(string commandName) =>
        commandName.StartsWith("grok-", StringComparison.OrdinalIgnoreCase)
        && commandName.Length > "grok-".Length
        && char.IsDigit(commandName["grok-".Length]);

    private static bool IsDaemonCommandLine(string commandLine)
    {
        var tokens = commandLine.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Any(token => token is "app-server" or "mcp-server" or "--chrome-native-host" or "bg-pty-host" or "bg-spare")) return true;
        if (commandLine.Contains(" daemon run", StringComparison.OrdinalIgnoreCase)) return true;
        return Regex.IsMatch(commandLine, @"(^|/)opencode\s+serve(\s|$)", RegexOptions.IgnoreCase);
    }

    private static bool HasTmuxAncestor(WslProcessInfo process, IReadOnlyDictionary<int, WslProcessInfo> byPid)
    {
        var parent = process.ParentPid;
        for (var i = 0; i < 64 && byPid.TryGetValue(parent, out var ancestor); i++)
        {
            if (string.Equals(GetCommandName(ancestor.Command), "tmux", StringComparison.OrdinalIgnoreCase)) return true;
            parent = ancestor.ParentPid;
        }
        return false;
    }

    private static string? NullIfEmpty(string value) => string.IsNullOrWhiteSpace(value) ? null : value;
    private static bool IsPaneId(string? value) => value is { Length: > 1 } && value[0] == '%' && int.TryParse(value[1..], out var pane) && pane >= 0;

    private async Task<OperationResult> FocusTerminalAsync(Terminal terminal, CancellationToken cancellationToken)
    {
        var processName = terminal switch
        {
            Terminal.WindowsTerminal => "WindowsTerminal",
            Terminal.WezTerm => "wezterm-gui",
            Terminal.VsCode => "Code",
            Terminal.Alacritty => "alacritty",
            _ => throw new InvalidOperationException("Unsupported terminal")
        };
        if (_activation is not null)
        {
            var native = await _activation.ActivateAsync(new ActivationTarget.App(processName), cancellationToken).ConfigureAwait(false);
            if (native.IsSuccess) return native;
        }
        if (terminal == Terminal.WindowsTerminal)
        {
            try
            {
                var wt = await _runner.RunAsync("wt.exe", ["-w", "0", "focus-tab", "-t", "0"], CommandTimeout, cancellationToken).ConfigureAwait(false);
                if (wt.TimedOut)
                {
                    return OperationResult.VisibleError(OperationStatus.Timeout, "Windows Terminal focus timed out");
                }
                if (wt.ExitCode == 0)
                {
                    return OperationResult.Success("Switched to Windows Terminal", new ActivationTarget.App("WindowsTerminal"));
                }
            }
            catch
            {
                // Fall back to AppActivate when wt.exe is unavailable, matching the reference WSL implementation.
            }
        }

        var script = terminal == Terminal.WezTerm
            ? PowerShellAppActivateScript
            : $"$wshell = New-Object -ComObject WScript.Shell; if ($wshell.AppActivate('{processName}')) {{ exit 0 }} else {{ exit 1 }}";
        // Why: WScript.Shell.AppActivate is used instead of SetForegroundWindow because WSL2-originated focus requests are unreliable with the Win32 API.
        var result = await _runner.RunAsync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], CommandTimeout, cancellationToken).ConfigureAwait(false);
        if (result.TimedOut)
        {
            return OperationResult.VisibleError(OperationStatus.Timeout, $"{processName} focus timed out");
        }
        var displayName = terminal == Terminal.WezTerm ? "WezTerm" : processName;
        return result.ExitCode == 0
            ? OperationResult.Success($"Switched to {displayName}", new ActivationTarget.App(processName))
            : OperationResult.VisibleError(OperationStatus.Failed, $"Failed to focus {displayName}");
    }

    private IReadOnlyList<string> BuildTerminalEnvironmentArgs(int pid)
    {
        var probe = $"""
            pid={pid}; test -r /proc/$pid/environ || exit 1
            printf 'CWD=%s\n' "$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
            depth=0
            while test "$pid" -gt 0 && test "$depth" -lt 64; do
              if test -r "/proc/$pid/environ"; then
                tr '\0' '\n' < "/proc/$pid/environ" | sed -n -e 's/^WT_SESSION=.*/WT_SESSION/p' -e 's/^TERM_PROGRAM=WezTerm$/TERM_PROGRAM=WezTerm/p' -e 's/^VSCODE_IPC_HOOK_CLI=.*/VSCODE_IPC_HOOK_CLI/p' -e 's/^ALACRITTY_[^=]*=.*/ALACRITTY/p' -e 's/^TMUX_PANE=%[0-9][0-9]*$/&/p'
              fi
              next=$(ps -o ppid= -p "$pid" | tr -d ' ')
              test -n "$next" || exit 0
              pid=$next
              depth=$((depth + 1))
            done
            """;
        return BaseArgs().Concat(["--exec", "/bin/bash", "-lc", probe, "focusbm-terminal-probe"]).ToArray();
    }

    private static Terminal? DetectTerminal(string output)
    {
        var markers = output.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (markers.Contains("WT_SESSION", StringComparer.Ordinal)) return Terminal.WindowsTerminal;
        if (markers.Contains("TERM_PROGRAM=WezTerm", StringComparer.Ordinal)) return Terminal.WezTerm;
        if (markers.Contains("VSCODE_IPC_HOOK_CLI", StringComparer.Ordinal)) return Terminal.VsCode;
        if (markers.Contains("ALACRITTY", StringComparer.Ordinal)) return Terminal.Alacritty;
        return null;
    }

    private static Terminal? ParseTerminal(string? value) =>
        Enum.TryParse<Terminal>(value, true, out var terminal) ? terminal : null;

    private static ProcessContext ParseProcessContext(string output)
    {
        var markers = output.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var paneMarker = markers.FirstOrDefault(marker => marker.StartsWith("TMUX_PANE=", StringComparison.Ordinal));
        var paneId = paneMarker is not null && IsPaneId(paneMarker["TMUX_PANE=".Length..]) ? paneMarker["TMUX_PANE=".Length..] : null;
        return new ProcessContext(DetectTerminal(output), paneId);
    }

    private sealed record ProcessContext(Terminal? Terminal, string? TmuxPaneId);

    private enum Terminal
    {
        WindowsTerminal,
        WezTerm,
        VsCode,
        Alacritty
    }

    private IReadOnlyList<string> BaseArgs(string? workingDirectory = null)
    {
        var distro = _settings.Distribution ?? "Ubuntu";
        var user = _settings.User ?? Environment.UserName;
        if (_settings.AllowedDistributions is { Count: > 0 } && !_settings.AllowedDistributions.Contains(distro)) throw new InvalidOperationException("WSL distribution is not allowlisted");
        if (_settings.AllowedUsers is { Count: > 0 } && !_settings.AllowedUsers.Contains(user)) throw new InvalidOperationException("WSL user is not allowlisted");
        return ["--distribution", distro, "--user", user, "--cd", workingDirectory ?? "~"];
    }
}
