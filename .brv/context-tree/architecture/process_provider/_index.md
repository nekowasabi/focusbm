---
children_hash: f4de6d29d00dc35d3cccbd2c3365a9267fbfa61458fd526be7c34be2dce67c4e
compression_ratio: 0.7011834319526628
condensation_order: 1
covers: [context.md, daemon_filtering.md]
covers_token_total: 1014
summary_level: d1
token_count: 711
type: summary
---
# process_provider

Structural overview of the ProcessProvider daemon filtering subsystem for AI agent process listings in FocusBM.

## Core responsibility
- `process_provider` covers how `ProcessProvider` excludes non-interactive helper/daemon processes from listings while preserving interactive agent processes.
- The filtering is centered on command-line markers, not executable names, so the same binary can be treated differently depending on how it was launched.

## Key entry points
- See `context.md` for the topic-level overview of the process discovery pipeline and related visibility work.
- See `daemon_filtering.md` for the detailed filtering rules, implementation flow, patterns, and tests.

## Processing model
- Process discovery starts with `pgrep`-based matching for AI agent commands such as `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- Candidate processes are then:
  1. checked against tmux ancestry,
  2. inspected for command-line daemon markers,
  3. excluded if they match helper/daemon criteria,
  4. retained only if they appear to be interactive agent processes.

## Filtering rules and behavior
- tmux pane processes are excluded from AI agent listings.
- Daemon/helper subcommands are excluded when the command line contains:
  - `app-server`
  - `mcp-server`
  - `--chrome-native-host`
- Detection uses space-prefixed substring matching, e.g. `contains(" " + subcommand)`, to avoid partial matches.
- The same executable may be interactive or helper-driven; the command line determines inclusion.

## Implementation details
- `ProcessProvider` uses `pgrep` regex patterns to locate candidate processes by basename.
- Tmux parent-chain detection relies on `sysctl` and is capped at 20 ancestors with cycle detection.
- Working directory resolution prefers `proc_pidinfo` and falls back to `lsof`.
- `tmuxCheckCache` memoizes tmux checks within a refresh cycle and is cleared by `clearTmuxCheckCache()`.

## Performance and dependencies
- `proc_pidinfo` is the fast path for working directory lookup.
- `lsof` fallback is slower and used only when necessary.
- `sysctl` is used to avoid spawning subprocesses during tmux ancestry checks.
- The subsystem depends on `pgrep`, `ps`, Darwin process APIs, and parent-chain inspection.

## Tests and related changes
- `daemon_filtering.md` documents the addition of `--chrome-native-host` to daemon filtering and the corresponding `ProcessProviderTests` coverage.
- The related process visibility work is linked from `architecture/process_visibility/process_visibility.md` and `architecture/process_visibility/sleep_wake_agent_process_visibility_fix.md`.

## Drill-down map
- `context.md` — overall ProcessProvider topic and its relation to process visibility.
- `daemon_filtering.md` — exact filtering flow, patterns, rules, and implementation notes.