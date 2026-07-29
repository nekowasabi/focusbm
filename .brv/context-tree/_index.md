---
children_hash: 305104f95f709f92600c2bff7ee6a88d301a60c7a24a91719827a3087a2991f5
compression_ratio: 0.8811881188118812
condensation_order: 3
covers: [architecture/_index.md]
covers_token_total: 1010
summary_level: d3
token_count: 890
type: summary
---
## architecture

FocusBM’s architecture is organized around two tightly related concerns: **process provider filtering** and **process visibility correctness**. The core problem is distinguishing interactive AI agent sessions from helper/daemon processes while also handling tmux ancestry, working-directory resolution, and stale or incomplete process state after sleep/wake transitions.

### process_provider
Defines how AI agent processes are discovered and filtered so that only interactive sessions are surfaced.

- Discovery starts with `pgrep` against agent commands such as `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- Filtering is **command-line based**, not executable-name based, so the same binary may be included or excluded depending on launch context.
- Exclusion rules cover tmux pane processes and command-line markers like `app-server`, `mcp-server`, and `--chrome-native-host`.
- Tmux ancestry checks use `sysctl` with a 20-ancestor cap and cycle detection.
- Working-directory resolution prefers `proc_pidinfo`, with `lsof` as a slower fallback.
- `tmuxCheckCache` memoizes tmux checks during a refresh cycle and is cleared by `clearTmuxCheckCache()`.

Drill down:
- `context.md` — overview of the provider and its relation to visibility
- `daemon_filtering.md` — exact filtering rules, implementation flow, patterns, and tests

### process_visibility
Describes how FocusBM handles process enumeration when provider results are stale, empty, or incomplete, especially around detached tmux sessions and wake-time transitions.

#### process_visibility.md
Covers the baseline visibility model and provider correctness.

- Flow: `focus check -> process provider query -> process list inspection -> handle detached or stale results`
- Detached tmux sessions remain relevant even when not attached normally.
- Sleep-wake transitions can produce empty or stale process lists.
- The model depends on tmux session state and the freshness of system process data.
- Source/test anchors: `Sources/FocusBMLib/TmuxProvider.swift` and `Tests/focusbmTests/TmuxProviderTests.swift`.

#### sleep_wake_agent_process_visibility_fix.md
Records the operational fix for wake-related visibility issues.

- `BackgroundRefreshService` listens to both screen and system sleep/wake notifications.
- On sleep, `isSleeping = true`; on wake, `isSleeping = false` and refresh is delayed by `2.0` seconds.
- The delay compensates for `NSWorkspace.runningApplications` being incomplete immediately after wake.
- Background cache updates are limited to visible search items when the panel is active.
- Basename-aware regex matching is used for launcher-invoked binaries.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests cover `processNamePattern` and daemon filtering.

Documented flow:
- `sleep/wake event -> process visibility check -> detached tmux handling -> refresh/recovery`

### Shared patterns
- Process visibility is treated as a correctness problem, not just a UI concern.
- Detached tmux sessions and wake-time enumeration are the main edge cases.
- Delayed refresh plus re-querying is the recovery strategy after wake.
- The process-provider layer reconciles tmux panes, non-tmux AI processes, and terminal-app resolution.

### Related references
- `docs/requirements/tmux-detached-session-focus.md`
- `docs/requirements/zombie-process-refresh-plan.md`
- `docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`
- `plan/` and `plan-fix-focus/` process notes
- `hammerspoon/focusbm.lua`