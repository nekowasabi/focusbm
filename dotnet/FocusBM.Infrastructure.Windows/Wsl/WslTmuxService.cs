using FocusBM.Core;
using System.Text.RegularExpressions;

namespace FocusBM.Infrastructure.Windows.Wsl;

public sealed class WslTmuxService : ITmuxService, IWslNvimService
{
    // Why: Search both XDG runtime and legacy /tmp sockets because WSL tmux may use TMUX_TMPDIR instead of the default socket.
    private const string ListPanesScript = """
        tmux_bin=$(command -v tmux || true)
        [ -n "$tmux_bin" ] || exit 127
        separator=$(printf '\t')
        for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
          if [ -S "$socket" ]; then
            if "$tmux_bin" -S "$socket" list-panes -a -F "#{session_name}${separator}#{window_index}${separator}#{pane_id}${separator}#{pane_current_command}${separator}#{pane_title}${separator}#{pane_current_path}${separator}#{window_name}"; then
              exit 0
            fi
          fi
        done
        exit 1
        """;
    private const string CapturePaneScript = """
        tmux_bin=$(command -v tmux || true)
        [ -n "$tmux_bin" ] || exit 127
        for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
          if [ -S "$socket" ]; then
            if "$tmux_bin" -S "$socket" capture-pane -p -t "$1" 2>/dev/null; then exit 0; fi
          fi
        done
        exit 1
        """;
    private const string SendExCommandScript = """
        tmux_bin=$(command -v tmux || true)
        [ -n "$tmux_bin" ] || exit 127
        for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
          if [ -S "$socket" ]; then
            if "$tmux_bin" -S "$socket" send-keys -t "$1" Escape; then
              "$tmux_bin" -S "$socket" send-keys -l -t "$1" ":$2" || continue
              "$tmux_bin" -S "$socket" send-keys -t "$1" Enter || continue
              exit 0
            fi
          fi
        done
        exit 1
        """;
    // Why: switch-client -t is a session target; session:window either fails or ignores the window,
    // and `|| continue` then skips select-pane. A pane id (`%N`) is the documented special case that
    // changes session, window, and pane for that client. Always follow with select-window/select-pane
    // so a detached session still moves, matching macOS attached focus.
    private const string SelectPaneScript = """
        detect_terminal_from_pid() {
          pid=$1
          depth=0
          while [ "$pid" -gt 0 ] && [ "$depth" -lt 64 ]; do
            if [ -r "/proc/$pid/environ" ]; then
              while IFS= read -r -d '' variable; do
                case "$variable" in
                  WT_SESSION=*) printf 'WindowsTerminal'; return 0 ;;
                  TERM_PROGRAM=WezTerm) printf 'WezTerm'; return 0 ;;
                  VSCODE_IPC_HOOK_CLI=*) printf 'VSCode'; return 0 ;;
                  ALACRITTY_*=*) printf 'Alacritty'; return 0 ;;
                esac
              done < "/proc/$pid/environ"
            fi
            next=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            case "$next" in ''|*[!0-9]*) return 1;; esac
            pid=$next
            depth=$((depth + 1))
          done
          return 1
        }
        tmux_bin=$(command -v tmux || true)
        [ -n "$tmux_bin" ] || exit 127
        terminal_hint="$2"
        for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
          if [ -S "$socket" ]; then
            target_info=$("$tmux_bin" -S "$socket" display-message -p -t "$1" '#{session_name}|#{window_index}|#{pane_id}' 2>/dev/null) || continue
            session=${target_info%%|*}
            rest=${target_info#*|}
            window=${rest%%|*}
            pane_id=${rest#*|}
            [ -n "$session" ] && [ -n "$window" ] && [ -n "$pane_id" ] || continue
            client=""
            while IFS='|' read -r client_tty client_session client_pid; do
              [ "$client_session" = "$session" ] || continue
              if [ -z "$terminal_hint" ]; then
                client="$client_tty"
                break
              fi
              detected=$(detect_terminal_from_pid "$client_pid" || true)
              if [ "$detected" = "$terminal_hint" ]; then
                client="$client_tty"
                break
              fi
            done < <("$tmux_bin" -S "$socket" list-clients -F '#{client_tty}|#{client_session}|#{client_pid}' 2>/dev/null)
            if [ -n "$terminal_hint" ] && [ -z "$client" ]; then
              continue
            fi
            if [ -n "$client" ]; then
              "$tmux_bin" -S "$socket" switch-client -c "$client" -t "$pane_id" || true
            fi
            "$tmux_bin" -S "$socket" select-window -t "$session:$window" || continue
            if "$tmux_bin" -S "$socket" select-pane -t "$pane_id"; then
              printf '%s\t%s\n' "$session" "$window"
              exit 0
            fi
          fi
        done
        exit 1
        """;
    private const string ListClientTerminalsScript = """
        detect_terminal_from_pid() {
          pid=$1
          depth=0
          while [ "$pid" -gt 0 ] && [ "$depth" -lt 64 ]; do
            if [ -r "/proc/$pid/environ" ]; then
              while IFS= read -r -d '' variable; do
                case "$variable" in
                  WT_SESSION=*) printf 'WindowsTerminal'; return 0 ;;
                  TERM_PROGRAM=WezTerm) printf 'WezTerm'; return 0 ;;
                  VSCODE_IPC_HOOK_CLI=*) printf 'VSCode'; return 0 ;;
                  ALACRITTY_*=*) printf 'Alacritty'; return 0 ;;
                esac
              done < "/proc/$pid/environ"
            fi
            next=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            case "$next" in ''|*[!0-9]*) return 1;; esac
            pid=$next
            depth=$((depth + 1))
          done
          return 1
        }
        tmux_bin=$(command -v tmux || true)
        [ -n "$tmux_bin" ] || exit 127
        for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
          if [ -S "$socket" ]; then
            while IFS='|' read -r client_session client_pid; do
              [ -n "$client_session" ] || continue
              detected=$(detect_terminal_from_pid "$client_pid" || true)
              [ -n "$detected" ] || continue
              printf '%s\t%s\n' "$client_session" "$detected"
            done < <("$tmux_bin" -S "$socket" list-clients -F '#{client_session}|#{client_pid}' 2>/dev/null)
          fi
        done
        exit 0
        """;
    private readonly WslSettings _settings;
    private readonly IProcessRunner _runner;
    private readonly IRestoreTimingSink? _timing;
    public WslTmuxService(WslSettings settings, IProcessRunner runner, IRestoreTimingSink? timing = null)
    {
        _settings = settings;
        _runner = runner;
        _timing = timing;
    }

    public async Task<IReadOnlyList<TmuxPaneInfo>> ListPanesAsync(CancellationToken cancellationToken = default)
    {
        var result = await TryListPanesAsync(cancellationToken).ConfigureAwait(false);
        return result.Panes;
    }

    public async Task<(IReadOnlyList<TmuxPaneInfo> Panes, bool Succeeded)> TryListPanesAsync(CancellationToken cancellationToken = default)
        => await TryListPanesAsync(cancellationToken, includeStatus: false).ConfigureAwait(false);

    public async Task<(IReadOnlyList<TmuxPaneInfo> Panes, bool Succeeded)> TryListPanesAsync(
        CancellationToken cancellationToken,
        bool includeStatus)
    {
        if (!_settings.Enabled) return (Array.Empty<TmuxPaneInfo>(), false);
        var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", ListPanesScript, "focusbm-tmux-list"]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, TimeSpan.FromSeconds(1), cancellationToken).ConfigureAwait(false);
        if (result.TimedOut || result.ExitCode != 0) return (Array.Empty<TmuxPaneInfo>(), false);
        IReadOnlyList<TmuxPaneInfo> panes = ParsePanes(result.StandardOutput);
        if (includeStatus) panes = (await AddStatusesAsync(panes, cancellationToken).ConfigureAwait(false)).ToList();
        return (panes, panes.Count > 0);
    }

    public static IReadOnlyList<TmuxPaneInfo> ParsePanes(string output) =>
        output.Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.Split('\t'))
            .Where(parts => parts.Length >= 3)
            .Select(parts => new TmuxPaneInfo(
                parts[0],
                parts[1],
                parts[2],
                parts.Length > 3 ? Redactor.Mask(parts[3]) : null,
                parts.Length > 4 ? Redactor.Mask(parts[4]) : null,
                null,
                parts.Length > 5 ? Redactor.Mask(parts[5]) : null,
                parts.Length > 6 ? Redactor.Mask(parts[6]) : null))
            .ToList();

    public static IReadOnlyDictionary<string, string> ParseClientTerminals(string output)
    {
        var map = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = line.TrimEnd('\r').Split('\t', 2);
            if (parts.Length == 2 && !string.IsNullOrWhiteSpace(parts[0]))
                map[parts[0]] = parts[1];
        }
        return map;
    }

    public async Task<(IReadOnlyDictionary<string, string> Terminals, bool Succeeded)> TryListClientTerminalsAsync(CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return (new Dictionary<string, string>(StringComparer.Ordinal), false);
        var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", ListClientTerminalsScript, "focusbm-tmux-clients"]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, TimeSpan.FromSeconds(1), cancellationToken).ConfigureAwait(false);
        if (result.TimedOut || result.ExitCode != 0) return (new Dictionary<string, string>(StringComparer.Ordinal), false);
        var terminals = ParseClientTerminals(result.StandardOutput);
        return (terminals, terminals.Count > 0);
    }

    // Why: Prefer a mapped AI PID when the process list succeeded, but still show panes whose command or title is an agent so a timed-out ps walk cannot empty the panel.
    public static IReadOnlyList<TmuxPaneInfo> FilterPanesByAgent(
        IEnumerable<TmuxPaneInfo> panes,
        IReadOnlyDictionary<string, WslProcessInfo> agentsByPane,
        bool allowHeuristicFallback = true) =>
        panes.Where(pane => agentsByPane.ContainsKey(pane.PaneId) || (allowHeuristicFallback && LooksLikeAgent(pane))).ToArray();

    public static TmuxAgentStatus DetectAgentStatus(string? title, string? content)
    {
        var captured = DetectCapturedStatus(content);
        if (captured is not null) return captured.Value;

        title ??= string.Empty;
        if (title.Contains('⏸')) return TmuxAgentStatus.PlanMode;
        if (title.Contains('⏵')) return TmuxAgentStatus.AcceptEdits;
        if (title.Any(ch => ch is >= '\u2800' and <= '\u28FF')) return TmuxAgentStatus.Running;
        if (new[] { '✳', '✢', '✽', '✶', '✻', '✷', '✸', '✹', '✺', '✵' }.Any(title.Contains)) return TmuxAgentStatus.Running;
        var lower = title.ToLowerInvariant();
        return lower.Contains("working") || lower.Contains("generating") || lower.Contains("thinking") || lower.Contains("streaming")
            ? TmuxAgentStatus.Running
            : TmuxAgentStatus.Idle;
    }

    private static TmuxAgentStatus? DetectCapturedStatus(string? content)
    {
        if (string.IsNullOrWhiteSpace(content)) return null;
        var lines = content.Split('\n');
        var lower = content.ToLowerInvariant().Replace("⏵⏵", "⏵", StringComparison.Ordinal);
        TmuxAgentStatus? mode = lower.Contains("plan mode on") ? TmuxAgentStatus.PlanMode
            : lower.Contains("accept edits on") ? TmuxAgentStatus.AcceptEdits
            : null;

        if (lines.Any(line =>
            line.Contains("esc to interrupt", StringComparison.OrdinalIgnoreCase)
            || line.Contains("ctrl+c to interrupt", StringComparison.OrdinalIgnoreCase)
            || Regex.IsMatch(line, @"^\s*[•✢✽✶✻·]\s+(working|generating|thinking|streaming)", RegexOptions.IgnoreCase)))
            return TmuxAgentStatus.Running;

        for (var i = lines.Length - 1; i >= 0; i--)
        {
            var line = lines[i];
            var trimmed = line.Trim();
            var lowerLine = trimmed.ToLowerInvariant();
            foreach (var marker in new[] { "allow once", "allow always", "deny", "continue?", "proceed?", "approval", "approve", "permission", "y/n", "yes/no", "to navigate", "enter to select", "press enter", "select an option" })
            {
                if (lowerLine.Contains(marker, StringComparison.Ordinal)) return mode ?? TmuxAgentStatus.PlanMode;
            }
            if (Regex.IsMatch(trimmed, @"❯\s+\d+\.")) return mode ?? TmuxAgentStatus.PlanMode;
            if (trimmed.StartsWith("❯", StringComparison.Ordinal) || trimmed.StartsWith("›", StringComparison.Ordinal) || trimmed == ">") return mode ?? TmuxAgentStatus.Idle;
        }
        return mode;
    }

    private async Task<IReadOnlyList<TmuxPaneInfo>> AddStatusesAsync(
        IReadOnlyList<TmuxPaneInfo> panes,
        CancellationToken cancellationToken)
    {
        var result = panes.ToArray();
        for (var i = 0; i < result.Length; i++)
        {
            if (!LooksLikeAgent(result[i])) continue;
            string? content;
            try
            {
                content = await CapturePaneContentAsync(result[i].PaneId, cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                content = null;
            }
            var status = DetectAgentStatus(result[i].Title, content);
            result[i] = result[i] with { Status = status.ToString(), AgentStatus = status, CaptureText = content };
        }
        return result;
    }

    private async Task<string?> CapturePaneContentAsync(string paneId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(paneId) || paneId.StartsWith("-", StringComparison.Ordinal)) return null;
        var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", CapturePaneScript, "focusbm-tmux-capture", paneId]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, TimeSpan.FromSeconds(3), cancellationToken).ConfigureAwait(false);
        return result.TimedOut || result.ExitCode != 0 ? null : Redactor.Mask(result.StandardOutput);
    }

    private async Task<OperationResult> SendExCommandAsync(string paneId, string exCommand, CancellationToken cancellationToken)
    {
        var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", SendExCommandScript, "focusbm-tmux-send", paneId, exCommand]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, TimeSpan.FromSeconds(3), cancellationToken).ConfigureAwait(false);
        if (result.TimedOut) return OperationResult.VisibleError(OperationStatus.Timeout, "Neovim Ex command send timed out");
        return result.ExitCode == 0
            ? OperationResult.Success("Ex command sent")
            : OperationResult.VisibleError(OperationStatus.Failed, "Neovim Ex command send failed");
    }

    private static bool IsValidExCommand(string command) =>
        !command.StartsWith(":", StringComparison.Ordinal)
        && !command.Any(ch => ch is '\r' or '\n' or '\0');

    private static bool LooksLikeAgent(TmuxPaneInfo pane)
    {
        if (WslProcessService.GetAgentCommand(pane.CurrentCommand ?? string.Empty) is not null) return true;
        var command = WslProcessService.GetCommandName(pane.CurrentCommand ?? string.Empty);
        if (command is "bash" or "sh" or "zsh" or "fish" or "dash" or "tcsh" or "csh" or "ksh" or "nu") return false;
        var title = pane.Title ?? string.Empty;
        return new[] { "claude", "aider", "gemini", "codex", "copilot", "hermes", "opencode", "grok", "cursor-agent", "cursor agent", "openai", "ai agent" }
            .Any(marker => title.Contains(marker, StringComparison.OrdinalIgnoreCase));
    }

    public async Task<OperationResult> FocusPaneAsync(TmuxPaneState pane, CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return OperationResult.VisibleError(OperationStatus.Unsupported, "WSL/tmux capability disabled");
        if (LooksLikeOption(pane.Session) || LooksLikeOption(pane.Window) || LooksLikeOption(pane.PaneId)) return OperationResult.VisibleError(OperationStatus.ValidationError, "tmux target must not look like an option");
        if (IsPaneId(pane.PaneId)) return await FocusPaneByIdAsync(pane.PaneId, cancellationToken: cancellationToken).ConfigureAwait(false);
        var target = $"{pane.Session}:{pane.Window}.{pane.PaneId}";
        return await FocusPaneInternalAsync(target, new ActivationTarget.TmuxPane(pane.Session, pane.Window, pane.PaneId), cancellationToken).ConfigureAwait(false);
    }

    public async Task<OperationResult> RestoreAsync(WslNvimState nvim, CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return OperationResult.VisibleError(OperationStatus.Unsupported, "WSL/tmux capability disabled");
        if (!IsValidExCommand(nvim.ExCommand)) return OperationResult.VisibleError(OperationStatus.ValidationError, "Neovim Ex command is invalid");

        var listed = await TryListPanesAsync(cancellationToken).ConfigureAwait(false);
        var candidates = listed.Panes.Where(pane => string.Equals(pane.CurrentCommand, "nvim", StringComparison.Ordinal)).ToArray();
        var pane = !string.IsNullOrWhiteSpace(nvim.WorkingDirectory)
            ? candidates.FirstOrDefault(candidate => string.Equals(candidate.CurrentDirectory, nvim.WorkingDirectory, StringComparison.Ordinal))
            : null;
        pane ??= candidates.FirstOrDefault();
        if (pane is null) return OperationResult.VisibleError(OperationStatus.NotFound, "WSL tmux Neovim pane was not found");

        var focused = await FocusPaneByIdAsync(pane.PaneId, cancellationToken: cancellationToken).ConfigureAwait(false);
        if (!focused.IsSuccess) return focused;
        if (string.IsNullOrEmpty(nvim.ExCommand)) return focused with { Message = "WSL tmux Neovim pane focused" };

        var sent = await SendExCommandAsync(pane.PaneId, nvim.ExCommand, cancellationToken).ConfigureAwait(false);
        return sent.IsSuccess
            ? OperationResult.Success("WSL tmux Neovim pane focused and Ex command sent", focused.Target)
            : new OperationResult(OperationStatus.Partial, $"{focused.Message}; Ex command send failed: {sent.Message}", focused.Target);
    }

    public async Task<OperationResult> FocusPaneByIdAsync(string paneId, string? terminal = null, CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled) return OperationResult.VisibleError(OperationStatus.Unsupported, "WSL/tmux capability disabled");
        if (!IsPaneId(paneId)) return OperationResult.VisibleError(OperationStatus.ValidationError, "tmux pane ID is invalid");
        var result = await FocusPaneProcessAsync(paneId, terminal, cancellationToken).ConfigureAwait(false);
        if (result.TimedOut) return OperationResult.VisibleError(OperationStatus.Timeout, "tmux focus timed out");
        if (result.ExitCode != 0) return OperationResult.VisibleError(OperationStatus.Failed, FailureMessage(result));
        var parts = result.StandardOutput.Trim().Split('\t', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 2
            ? OperationResult.Success("tmux pane focused", new ActivationTarget.TmuxPane(parts[0], parts[1], paneId))
            : OperationResult.VisibleError(OperationStatus.Failed, "tmux target metadata was not returned");
    }

    private async Task<OperationResult> FocusPaneInternalAsync(string target, ActivationTarget.TmuxPane activationTarget, CancellationToken cancellationToken)
    {
        var result = await FocusPaneProcessAsync(target, terminal: null, cancellationToken).ConfigureAwait(false);
        if (result.TimedOut) return OperationResult.VisibleError(OperationStatus.Timeout, "tmux focus timed out");
        return result.ExitCode == 0 ? OperationResult.Success("tmux pane focused", activationTarget) : OperationResult.VisibleError(OperationStatus.Failed, FailureMessage(result));
    }

    private async Task<ProcessRunResult> FocusPaneProcessAsync(string target, string? terminal, CancellationToken cancellationToken)
    {
        var timing = new RestoreTimingScope("tmux:focus", _timing);
        timing.Mark("start");
        var args = BaseArgs().Concat(["--exec", "/bin/bash", "-lc", SelectPaneScript, "focusbm-tmux-select", target, terminal ?? ""]).ToArray();
        var result = await _runner.RunAsync("wsl.exe", args, TimeSpan.FromSeconds(3), cancellationToken).ConfigureAwait(false);
        timing.Mark("complete", result.TimedOut ? "timeout" : result.ExitCode.ToString());
        return result;
    }

    private IReadOnlyList<string> BaseArgs()
    {
        var distro = _settings.Distribution ?? "Ubuntu";
        var user = _settings.User ?? Environment.UserName;
        if (_settings.AllowedDistributions is { Count: > 0 } && !_settings.AllowedDistributions.Contains(distro)) throw new InvalidOperationException("WSL distribution is not allowlisted");
        if (_settings.AllowedUsers is { Count: > 0 } && !_settings.AllowedUsers.Contains(user)) throw new InvalidOperationException("WSL user is not allowlisted");
        return new [] { "--distribution", distro, "--user", user, "--cd", "~" };
    }

    private static bool LooksLikeOption(string s) => string.IsNullOrWhiteSpace(s) || s.StartsWith('-') || s.Contains('\0');
    private static bool IsPaneId(string s) => s.Length > 1 && s[0] == '%' && int.TryParse(s[1..], out var value) && value >= 0;
    private static string FailureMessage(ProcessRunResult result) => string.IsNullOrWhiteSpace(result.StandardError) ? "tmux pane focus failed" : Redactor.Mask(result.StandardError);
}
