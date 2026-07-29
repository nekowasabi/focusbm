---
children_hash: 0efb689c8edc68af9e414fdd0ff258f127d44b6471b4985d6fcc8eaad6f075b2
compression_ratio: 0.5373563218390804
condensation_order: 2
covers: [context.md, process_provider/_index.md, process_visibility/_index.md]
covers_token_total: 1740
summary_level: d2
token_count: 935
type: summary
---
# architecture

FocusBM architecture centers on process detection, filtering, and visibility for focus management. The key concern is distinguishing interactive AI agent processes from helper/daemon processes, while also handling tmux state, working-directory resolution, and wake-time freshness issues.

## Main areas

### process_provider
Responsible for excluding non-interactive helper/daemon processes from AI agent listings while preserving interactive sessions. Filtering is command-line based rather than executable-name based, so the same binary can be included or excluded depending on launch context.

- Discovery starts with `pgrep` matching for agent commands such as `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- Candidates are then checked for tmux ancestry, daemon markers, and interactive vs helper behavior.
- Exclusion rules include tmux pane processes and command-line markers like `app-server`, `mcp-server`, and `--chrome-native-host`.
- Tmux ancestry checks use `sysctl` with a 20-ancestor cap and cycle detection.
- Working-directory resolution prefers `proc_pidinfo`, with `lsof` as a slower fallback.
- `tmuxCheckCache` memoizes tmux checks during a refresh cycle and is cleared by `clearTmuxCheckCache()`.

Drill down:
- `context.md` — topic overview and relation to process visibility
- `daemon_filtering.md` — exact filtering rules, implementation flow, patterns, and tests

### process_visibility
Documents how FocusBM handles process enumeration for focus management, especially when process-provider results are incomplete, empty, or stale. This is tightly coupled to detached tmux sessions and sleep-wake transitions, which can cause focus detection and AI agent visibility to become incorrect.

#### process_visibility.md
Covers the baseline visibility model and provider correctness.

- Flow: `focus check -> process provider query -> process list inspection -> handle detached or stale results`
- Detached tmux sessions can still matter even when not attached normally.
- Sleep-wake transitions can yield empty or stale process lists.
- Relies on tmux session state and timing/freshness of system process data.
- Source/test anchors: `Sources/FocusBMLib/TmuxProvider.swift` and `Tests/focusbmTests/TmuxProviderTests.swift`.

#### sleep_wake_agent_process_visibility_fix.md
Captures the operational fix for wake-related visibility problems.

- `BackgroundRefreshService` listens to both screen and system sleep/wake notifications.
- On sleep, `isSleeping = true`; on wake, `isSleeping = false` and refresh is delayed by `2.0` seconds.
- The delay compensates for `NSWorkspace.runningApplications` being incomplete immediately after wake.
- Background cache updates are limited to visible search items when the panel is active.
- Basename-aware regex matching is used for launcher-invoked binaries.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests cover `processNamePattern` and daemon filtering.

Documented flow:
- `sleep/wake event -> process visibility check -> detached tmux handling -> refresh/recovery`

Shared patterns:
- Process visibility is treated as a correctness issue, not just a UI concern.
- Detached tmux sessions and wake-time enumeration are the main edge cases.
- Delayed refresh and re-querying are used to recover accurate state after wake.
- The process-provider layer reconciles tmux panes, non-tmux AI processes, and terminal-app resolution.

## Related references
- `docs/requirements/tmux-detached-session-focus.md`
- `docs/requirements/zombie-process-refresh-plan.md`
- `docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`
- `plan/` and `plan-fix-focus/` process notes
- `hammerspoon/focusbm.lua`