---
children_hash: dc9b118430c281380780d0e7e0c532af49d2d2ba89fc4fb6a24575686c48aaab
compression_ratio: 0.27177582714382176
condensation_order: 1
covers: [process_visibility.md, sleep_wake_agent_process_visibility_fix.md]
covers_token_total: 2962
summary_level: d1
token_count: 805
type: summary
---
# Process Visibility

This set of entries documents how FocusBM handles process enumeration for focus management, especially around detached tmux sessions and sleep-wake transitions. The core concern is that process-provider results can be incomplete, empty, or stale, which directly affects focus detection and AI agent visibility.

## Main Topics

### process_visibility.md
Covers the baseline process visibility model for focus management and provider correctness. The key flow is: **focus check -> process provider query -> process list inspection -> handle detached or stale results**.

Key points:
- Detached tmux sessions may still matter for focus logic even when they are not attached in the usual way.
- Sleep-wake transitions can produce empty or stale process lists.
- The topic depends on tmux session state and timing/freshness of system process data.
- Source/test references: `Sources/FocusBMLib/TmuxProvider.swift` and `Tests/focusbmTests/TmuxProviderTests.swift`.

Drill down for:
- provider reliability details
- detached-session visibility behavior
- stale/empty process-list handling

### sleep_wake_agent_process_visibility_fix.md
Captures the concrete mitigation work for the sleep-wake process visibility issue. This is the more operational entry, connecting lifecycle events, refresh behavior, and daemon/process filtering.

Key decisions and behaviors:
- `BackgroundRefreshService` listens to both screen and system sleep/wake notifications.
- On sleep, `isSleeping = true`; on wake, `isSleeping = false` and refresh is delayed by `2.0` seconds.
- The delay exists because `NSWorkspace.runningApplications` may still be incomplete immediately after wake.
- Background cache updates are limited to visible search items when the panel is active.
- The system uses basename-aware regex matching for launcher-invoked binaries.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests cover `processNamePattern` and daemon filtering.

Documented flow:
- **sleep/wake event -> process visibility check -> detached tmux handling -> refresh/recovery**

Supporting references and context:
- Related docs include `docs/requirements/tmux-detached-session-focus.md`, `docs/requirements/zombie-process-refresh-plan.md`, `docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`, and the `plan/` + `plan-fix-focus/` process notes.
- `hammerspoon/focusbm.lua` is part of the implementation surface.

## Shared Patterns Across Both Entries
- Process visibility is treated as a correctness issue for focus management, not just a UI concern.
- Detached tmux sessions and wake-time process enumeration are the two dominant edge cases.
- Refresh timing is central: immediate queries can be wrong after wake, so delayed refresh and re-querying are used to recover accuracy.
- The process-provider layer is responsible for reconciling tmux panes, non-tmux AI processes, and terminal-app resolution.

## Where to Drill Down
- **process_visibility.md** — conceptual overview of process-provider reliability and stale/empty results
- **sleep_wake_agent_process_visibility_fix.md** — concrete wake handling, refresh strategy, daemon filtering, and implementation details