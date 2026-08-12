---
children_hash: 88619a92f27701c170c222223cafe44f56ad2a4e01301ccd65d05c7092ed81fa
compression_ratio: 0.871875
condensation_order: 3
covers: [architecture/_index.md]
covers_token_total: 640
summary_level: d3
token_count: 558
type: summary
---
# Architecture

FocusBM’s architecture is organized around two core concerns: **process provider filtering** and **process visibility correctness**. The overall pattern is to prefer authoritative process state, filter aggressively but accurately, and recover safely from lifecycle transitions like sleep/wake.

## Process Provider
See **process_provider/_index.md** for the filtering subsystem behind AI agent listings.

- `ProcessProvider` distinguishes interactive agent sessions from helper/daemon processes.
- Filtering is **command-line based**, not binary-name based, so the same executable may be included or excluded depending on launch arguments.
- Candidate discovery starts with `pgrep` for agent commands such as `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- The pipeline then checks tmux ancestry, daemon markers, and other helper-process signals.
- Daemon markers include `app-server`, `mcp-server`, and `--chrome-native-host`.
- Tmux pane processes are excluded from AI agent listings.
- Working-directory resolution prefers `proc_pidinfo` and falls back to `lsof`.
- `sysctl` supports tmux parent-chain inspection, with caching via `tmuxCheckCache`.

## Process Visibility
See **process_visibility/_index.md** for stale lists, detached sessions, and lifecycle-boundary handling.

- Correct focus detection depends on a fresh, correct process list.
- Detached tmux sessions may be invisible or misclassified.
- Sleep/wake transitions can yield empty or stale process lists.
- The canonical visibility behavior is documented in **Process Visibility**.
- The operational recovery path is documented in **Sleep-Wake Agent Process Visibility Fix**.
- **Session Pull Request Feature** is related but separate: it uses PID-scoped Claude session data and structured `prUrl` resolution with fail-closed behavior.

## Shared Architectural Patterns
- Prefer source-of-truth process data over inference.
- Treat stale or conflicting state as failure, not partial success.
- Use refresh-oriented recovery after empty or incomplete results.
- Keep background discovery separate from main-thread UI updates.
- Preserve correctness across lifecycle transitions, especially sleep/wake and detached-terminal states.