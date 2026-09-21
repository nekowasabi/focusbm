using FocusBM.Core;
using System.Diagnostics;
using System.Text;

namespace FocusBM.Infrastructure.Windows.Wsl;

/// <summary>One combined snapshot of tmux panes, tmux client terminals, and WSL agent processes.</summary>
public sealed record AgentDiscoverySnapshot(
    IReadOnlyList<TmuxPaneInfo> Panes,
    IReadOnlyDictionary<string, string> SessionTerminals,
    IReadOnlyList<WslProcessInfo> Processes,
    bool TmuxDiscoverySucceeded,
    bool ProcessDiscoverySucceeded)
{
    public static readonly AgentDiscoverySnapshot Empty = new(
        Array.Empty<TmuxPaneInfo>(),
        new Dictionary<string, string>(StringComparer.Ordinal),
        Array.Empty<WslProcessInfo>(),
        TmuxDiscoverySucceeded: false,
        ProcessDiscoverySucceeded: false);
}

/// <summary>
/// Why: Three parallel wsl.exe launches paid ~200ms of spawn overhead per refresh. A persistent
/// bash worker answers each request in one round-trip, so panel refreshes cost script time only.
/// </summary>
public sealed class WslAgentDiscoveryService : IDisposable
{
    private const string WorkerScript = """
        probe_environ() {
          local probe=$1 want_pane=$2 depth=0
          PROBE_PANE=""; PROBE_TERM=""
          while [ "$probe" -gt 0 ] && [ "$depth" -lt 64 ] && { [ -z "$PROBE_TERM" ] || { [ "$want_pane" = 1 ] && [ -z "$PROBE_PANE" ]; }; }; do
            if [ -r "/proc/$probe/environ" ]; then
              while IFS= read -r -d '' variable; do
                case "$variable" in
                  TMUX_PANE=*)
                    candidate_pane=${variable#TMUX_PANE=}
                    if [[ "$candidate_pane" =~ ^%[0-9]+$ ]] && [ -z "$PROBE_PANE" ]; then PROBE_PANE="$candidate_pane"; fi
                    ;;
                  WT_SESSION=*) [ -z "$PROBE_TERM" ] && PROBE_TERM="WindowsTerminal" ;;
                  TERM_PROGRAM=WezTerm) [ -z "$PROBE_TERM" ] && PROBE_TERM="WezTerm" ;;
                  VSCODE_IPC_HOOK_CLI=*) [ -z "$PROBE_TERM" ] && PROBE_TERM="VSCode" ;;
                  ALACRITTY_*=*) [ -z "$PROBE_TERM" ] && PROBE_TERM="Alacritty" ;;
                esac
              done < "/proc/$probe/environ"
            fi
            probe=${PPID_OF[$probe]:-0}
            depth=$((depth + 1))
          done
        }

        while IFS= read -r req; do
          want_tmux=1
          case "$req" in *notmux*) want_tmux=0 ;; esac
          ps_ok=0
          unset PPID_OF; declare -A PPID_OF=()
          row_pid=(); row_ppid=(); row_cmd=(); row_agent=()
          row_cwd=(); row_pane=(); row_term=()
          unset AGENT_PANES; declare -A AGENT_PANES=()
          if psout=$(ps -e -w -o pid=,ppid=,args= 2>/dev/null); then
            ps_ok=1
            while read -r pid ppid command; do
              case "$pid" in ''|*[!0-9]*) continue;; esac
              case "$ppid" in ''|*[!0-9]*) continue;; esac
              [ -n "$command" ] || continue
              PPID_OF[$pid]=$ppid
              command_name=${command%% *}
              command_name=${command_name##*/}
              case "$command_name" in
                python|python3|python3.[0-9]*)
                  case "$command" in
                    *bin/hermes*|*"/hermes "*) command_name="hermes" ;;
                  esac
                  ;;
                node|deno|bun|npx)
                  case "$command" in
                    *bin/codex*|*"/codex "*) command_name="codex" ;;
                  esac
                  ;;
              esac
              is_agent=0
              case "$command_name" in
                claude|aider|gemini|copilot|codex|devin|hermes|opencode|pi|grok|grok-[0-9]*|cursor-agent)
                  case "$command" in
                    *" app-server"*|*" mcp-server"*|*" --chrome-native-host"*|*"opencode serve"*|*" bg-pty-host"*|*" bg-spare"*|*" daemon run"*) ;;
                    *) is_agent=1 ;;
                  esac
                  ;;
              esac
              row_pid+=("$pid"); row_ppid+=("$ppid"); row_cmd+=("$command"); row_agent+=("$is_agent")
            done <<< "$psout"
          fi

          if [ "$ps_ok" = 1 ]; then
            for i in "${!row_pid[@]}"; do
              cwd=""; pane=""; terminal=""
              if [ "${row_agent[$i]}" = 1 ]; then
                cwd=$(cd -P "/proc/${row_pid[$i]}/cwd" 2>/dev/null && printf '%s' "$PWD")
                probe_environ "${row_pid[$i]}" 1
                pane=$PROBE_PANE
                terminal=$PROBE_TERM
                [ -n "$pane" ] && AGENT_PANES[$pane]=1
              fi
              row_cwd[$i]="$cwd"
              row_pane[$i]="$pane"
              row_term[$i]="$terminal"
            done
          fi

          echo "@PANES"
          tmux_bin=""
          panes_ok=0
          clients_ok=0
          pane_dump=""
          capture_socket=""
          if [ "$want_tmux" = 1 ]; then
            tmux_bin=$(command -v tmux || true)
          fi
          if [ -n "$tmux_bin" ]; then
            for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
              if [ -S "$socket" ]; then
                if pane_dump=$("$tmux_bin" -S "$socket" list-panes -a -F $'#{session_name}\t#{window_index}\t#{pane_id}\t#{pane_current_command}\t#{pane_title}\t#{pane_current_path}\t#{window_name}' 2>/dev/null); then
                  panes_ok=1
                  capture_socket=$socket
                  printf '%s\n' "$pane_dump"
                  break
                fi
              fi
            done
          fi

          echo "@CAPTURES"
          if [ "$panes_ok" = 1 ] && [ -n "$tmux_bin" ] && [ -n "$capture_socket" ]; then
            while IFS="$(printf '\t')" read -r sess win paneid cmd title path wname; do
              [ -n "$paneid" ] || continue
              capture=0
              case "$cmd" in
                claude|aider|gemini|copilot|codex|devin|hermes|opencode|pi|grok|grok-*|cursor-agent|agent|node|deno|bun|npx|python|python3|python3.*|uv|uvx|jev-routing) capture=1 ;;
              esac
              [ -n "${AGENT_PANES[$paneid]+x}" ] && capture=1
              [ "$capture" = 1 ] || continue
              printf '<<PANE %s>>\n' "$paneid"
              "$tmux_bin" -S "$capture_socket" capture-pane -p -t "$paneid" 2>/dev/null || true
              printf '\n<<END>>\n'
            done < <(printf '%s\n' "$pane_dump")
          fi

          echo "@CLIENTS"
          if [ -n "$tmux_bin" ]; then
            for socket in /run/user/*/tmux-*/* /tmp/tmux-*/*; do
              if [ -S "$socket" ]; then
                while IFS='|' read -r client_session client_pid; do
                  [ -n "$client_session" ] || continue
                  probe_environ "$client_pid" 0
                  [ -n "$PROBE_TERM" ] || continue
                  printf '%s\t%s\n' "$client_session" "$PROBE_TERM"
                done < <("$tmux_bin" -S "$socket" list-clients -F '#{client_session}|#{client_pid}' 2>/dev/null) && clients_ok=1
              fi
            done
          fi

          echo "@PROCESSES"
          if [ "$ps_ok" = 1 ]; then
            proc_out=""
            for i in "${!row_pid[@]}"; do
              proc_out+="${row_pid[$i]}	${row_ppid[$i]}	${row_cwd[$i]}	${row_pane[$i]}	${row_term[$i]}	${row_cmd[$i]}
        "
            done
            printf '%s' "$proc_out"
          fi
          printf '@STATUS\t%s\t%s\t%s\n' "$ps_ok" "$panes_ok" "$clients_ok"
          printf '\036\n'
        done
        """;
    private const char RecordSeparator = '\x1e';
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(1);
    private const int MaxResponseChars = 1_000_000;
    private readonly WslSettings _settings;
    private readonly IRestoreTimingSink? _timing;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Process? _worker;
    private bool _disposed;

    public WslAgentDiscoveryService(WslSettings settings, IRestoreTimingSink? timing = null)
    {
        _settings = settings;
        _timing = timing;
    }

    public async Task<AgentDiscoverySnapshot> TryDiscoverAsync(
        bool includeTmuxDescendants = true,
        bool includeTmux = true,
        CancellationToken cancellationToken = default)
    {
        if (!_settings.Enabled || _disposed) return AgentDiscoverySnapshot.Empty;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var request = includeTmux ? "go" : "go notmux";
            var output = await RequestAsync(request, cancellationToken).ConfigureAwait(false)
                ?? (cancellationToken.IsCancellationRequested ? null : await RequestAsync(request, cancellationToken).ConfigureAwait(false));
            return output is null
                ? AgentDiscoverySnapshot.Empty
                : Parse(output, includeTmuxDescendants);
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task<string?> RequestAsync(string request, CancellationToken cancellationToken)
    {
        var timing = new RestoreTimingScope("process:wsl-discovery", _timing);
        timing.Mark("start");
        var worker = EnsureWorker();
        if (worker is null)
        {
            timing.Mark("spawn-failed");
            return null;
        }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(RequestTimeout);
        try
        {
            await worker.StandardInput.WriteLineAsync(request).ConfigureAwait(false);
            await worker.StandardInput.FlushAsync().ConfigureAwait(false);
            var builder = new StringBuilder();
            var buffer = new char[8192];
            var read = 0;
            while (builder.Length < MaxResponseChars)
            {
                read = await worker.StandardOutput.ReadAsync(buffer.AsMemory(0, buffer.Length), timeout.Token).ConfigureAwait(false);
                if (read == 0) break;
                builder.Append(buffer, 0, read);
                var tail = builder.Length - 1;
                if (builder[tail] == RecordSeparator || (builder[tail] == '\n' && tail > 0 && builder[tail - 1] == RecordSeparator))
                {
                    timing.Mark("complete");
                    return builder.ToString();
                }
            }
            timing.Mark(read == 0 ? "eof" : "oversize");
            KillWorker();
            return null;
        }
        catch
        {
            KillWorker();
            timing.Mark("failed");
            return null;
        }
    }

    private Process? EnsureWorker()
    {
        if (_worker is { HasExited: false }) return _worker;
        DisposeWorker();
        if (_disposed) return null;
        try
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo("wsl.exe")
                {
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    StandardInputEncoding = Encoding.UTF8,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                }
            };
            foreach (var arg in BuildWorkerArgs()) process.StartInfo.ArgumentList.Add(arg);
            process.Start();
            _ = process.StandardError.ReadToEndAsync();
            _worker = process;
            return process;
        }
        catch
        {
            return null;
        }
    }

    private IReadOnlyList<string> BuildWorkerArgs()
    {
        var distro = _settings.Distribution ?? "Ubuntu";
        var user = _settings.User ?? Environment.UserName;
        if (_settings.AllowedDistributions is { Count: > 0 } && !_settings.AllowedDistributions.Contains(distro)) throw new InvalidOperationException("WSL distribution is not allowlisted");
        if (_settings.AllowedUsers is { Count: > 0 } && !_settings.AllowedUsers.Contains(user)) throw new InvalidOperationException("WSL user is not allowlisted");
        return ["--distribution", distro, "--user", user, "--cd", "~", "--exec", "/bin/bash", "-lc", WorkerScript, "focusbm-agent-discovery"];
    }

    private void KillWorker()
    {
        try { if (_worker is { HasExited: false }) _worker.Kill(entireProcessTree: true); } catch { }
        DisposeWorker();
    }

    private void DisposeWorker()
    {
        try { _worker?.StandardInput.Close(); } catch { }
        _worker?.Dispose();
        _worker = null;
    }

    public void Dispose()
    {
        _disposed = true;
        var worker = _worker;
        _worker = null;
        if (worker is null) return;
        try { worker.StandardInput.Close(); } catch { }
        try { if (!worker.WaitForExit(1000) && !worker.HasExited) worker.Kill(entireProcessTree: true); } catch { }
        worker.Dispose();
    }

    public static AgentDiscoverySnapshot Parse(string output, bool includeTmuxDescendants = true)
    {
        var panes = new StringBuilder();
        var clients = new StringBuilder();
        var processes = new StringBuilder();
        var captures = new Dictionary<string, StringBuilder>(StringComparer.Ordinal);
        var section = 0;
        var processOk = false;
        var sawStatus = false;
        string? capturePaneId = null;
        foreach (var rawLine in output.Split('\n'))
        {
            var line = rawLine.TrimEnd('\r', RecordSeparator);
            // Why: Cursor/Codex screens contain `@file` lines; treating them as protocol dropped later pane captures.
            var inCaptureBody = section == 4 && capturePaneId is not null;
            if (!inCaptureBody && line.StartsWith('@') && !line.StartsWith("@@", StringComparison.Ordinal))
            {
                if (line == "@PANES") section = 1;
                else if (line == "@CLIENTS") section = 2;
                else if (line == "@PROCESSES") section = 3;
                else if (line == "@CAPTURES") section = 4;
                else if (line.StartsWith("@STATUS\t", StringComparison.Ordinal))
                {
                    var flags = line.Split('\t');
                    processOk = flags.Length > 1 && flags[1] == "1";
                    sawStatus = true;
                    section = 0;
                }
                else section = 0;
                continue;
            }
            switch (section)
            {
                case 1: panes.Append(rawLine).Append('\n'); break;
                case 2: clients.Append(rawLine).Append('\n'); break;
                case 3: processes.Append(rawLine).Append('\n'); break;
                case 4:
                    if (line.StartsWith("<<PANE ", StringComparison.Ordinal) && line.EndsWith(">>", StringComparison.Ordinal))
                    {
                        capturePaneId = line[7..^2];
                        if (!string.IsNullOrWhiteSpace(capturePaneId))
                            captures[capturePaneId] = new StringBuilder();
                    }
                    else if (line == "<<END>>")
                    {
                        capturePaneId = null;
                    }
                    else if (capturePaneId is not null && captures.TryGetValue(capturePaneId, out var body))
                    {
                        if (body.Length > 0) body.Append('\n');
                        body.Append(rawLine.TrimEnd('\r', RecordSeparator));
                    }
                    break;
            }
        }
        if (!sawStatus) return AgentDiscoverySnapshot.Empty;
        var paneList = WslTmuxService.ParsePanes(panes.ToString());
        if (captures.Count > 0)
        {
            paneList = paneList.Select(pane =>
            {
                if (!captures.TryGetValue(pane.PaneId, out var body)) return pane;
                var text = Redactor.Mask(body.ToString());
                var status = WslTmuxService.DetectAgentStatus(pane.Title, text);
                return pane with { CaptureText = text, Status = status.ToString(), AgentStatus = status };
            }).ToList();
        }
        return new AgentDiscoverySnapshot(
            paneList,
            WslTmuxService.ParseClientTerminals(clients.ToString()),
            WslProcessService.Parse(processes.ToString(), includeTmuxDescendants),
            TmuxDiscoverySucceeded: paneList.Count > 0,
            ProcessDiscoverySucceeded: processOk);
    }
}
