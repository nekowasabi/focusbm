---
children_hash: 510d67aa8f64b3a3d3da318b397eaea63f14fab8b5154bcac8c10b3556731615
compression_ratio: 0.32847990681421085
condensation_order: 2
covers: [context.md, process_provider/_index.md, process_visibility/_index.md]
covers_token_total: 1717
summary_level: d2
token_count: 564
type: summary
---
# Architecture

FocusBM architecture centers on reliable process detection, filtering, and visibility. The main themes are distinguishing interactive agent processes from helper/daemon processes, handling tmux ancestry correctly, and recovering cleanly from sleep/wake state changes.

## Process provider
See **process_provider/_index.md** for the filtering subsystem that powers AI agent listings.

- `ProcessProvider` filters non-interactive helper/daemon processes while preserving interactive agent sessions.
- Filtering is command-line based, not binary-name based, so the same executable may be included or excluded depending on launch arguments.
- Candidate discovery starts with `pgrep` matching for agent commands like `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- The pipeline then checks tmux ancestry, inspects daemon markers, and excludes helper processes.
- Daemon markers include `app-server`, `mcp-server`, and `--chrome-native-host`.
- Tmux pane processes are excluded from AI agent listings.
- Working directory resolution prefers `proc_pidinfo` and falls back to `lsof`.
- `sysctl` is used for tmux parent-chain inspection with caching via `tmuxCheckCache`.

## Process visibility
See **process_visibility/_index.md** for correctness around stale lists, detached sessions, and lifecycle boundaries.

- Focus detection depends on a fresh, correct process list.
- Detached tmux sessions can remain invisible or be misclassified.
- Sleep/wake transitions can produce empty or stale process lists.
- The canonical visibility behavior is documented in **Process Visibility**.
- The operational mitigation is documented in **Sleep-Wake Agent Process Visibility Fix**.
- Related but separate is **Session Pull Request Feature**, which uses PID-scoped Claude session data and structured `prUrl` resolution with fail-closed behavior.

## Shared architectural patterns
- Prefer source-of-truth process data over inference.
- Treat stale or conflicting state as failure, not partial success.
- Use refresh-oriented recovery after empty or incomplete results.
- Keep background discovery separate from main-thread UI updates.
- Preserve correctness across lifecycle transitions, especially sleep/wake and detached-terminal states.