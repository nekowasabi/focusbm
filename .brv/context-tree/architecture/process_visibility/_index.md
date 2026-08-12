---
children_hash: 46daefaaad328f8319b003156260b57d586fc40489295167dced1947690411f5
compression_ratio: 0.19664207580768253
condensation_order: 1
covers: [process_visibility.md, session_pull_request_feature.md, sleep_wake_agent_process_visibility_fix.md]
covers_token_total: 3931
summary_level: d1
token_count: 773
type: summary
---
## Process Visibility

Covers FocusBM’s process-enumeration reliability around detached tmux sessions and sleep-wake transitions. The core concern is that focus detection depends on a fresh, correct process list, but wake-up timing can leave results empty or stale; see **Process Visibility** for the canonical overview and **Sleep-Wake Agent Process Visibility Fix** for the concrete mitigation history.

### Main relationships
- **Process Visibility** documents the general behavior:
  - detached tmux sessions may remain invisible or be misclassified
  - sleep/wake transitions can yield empty or stale process lists
  - focus checks depend on provider correctness and process freshness
- **Sleep-Wake Agent Process Visibility Fix** expands the operational fix:
  - `BackgroundRefreshService` listens to screen/system sleep-wake notifications
  - wake triggers a refresh, but it is delayed ~2 seconds to avoid incomplete `NSWorkspace.runningApplications`
  - background cache updates are restricted to visible search items when the panel is active
  - process visibility recovery is refresh-oriented rather than speculative
- **Session Pull Request Feature** is related but separate:
  - it resolves a selected session’s GitHub PR via PID-scoped Claude session data and structured `prUrl`
  - it uses fail-closed behavior, similar in spirit to the process-visibility emphasis on correctness over guessing

### Key implementation themes
- tmux-aware process resolution
- sleep/wake timing sensitivity
- refresh-based recovery after stale/empty results
- main-thread UI updates after background inspection
- strict handling of edge cases instead of inference

### Relevant files and entry drill-down
- **Process Visibility**
  - `Sources/FocusBMLib/TmuxProvider.swift`
  - `Tests/focusbmTests/TmuxProviderTests.swift`
  - Focuses on detached sessions, stale/empty process lists, and provider reliability
- **Sleep-Wake Agent Process Visibility Fix**
  - `hammerspoon/focusbm.lua`
  - `docs/requirements/sleep-wake-empty-process-list.md`
  - `docs/requirements/tmux-detached-session-focus.md`
  - `docs/requirements/zombie-process-refresh-plan.md`
  - `docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`
  - `plan/process-*` and `plan-fix-focus/process-*`
  - Captures the wake-delay mitigation, daemon filtering, basename-aware matching, and empty-list recovery
- **Session Pull Request Feature**
  - `Sources/FocusBMLib/SessionPullRequestResolver.swift`
  - `Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift`
  - `Sources/FocusBMApp/SearchPanel.swift`
  - `Tests/focusbmTests/SessionPullRequestResolverTests.swift`
  - Documents PID-scoped session lookup, structured PR URL validation, and failure-closed resolution

### Shared patterns across the entries
- Prefer structured source-of-truth inputs over guesswork
- Treat stale or conflicting state as failure, not partial success
- Use background resolution for data discovery and UI-thread handoff for visible changes
- Preserve behavior across lifecycle boundaries, especially sleep/wake and detached-terminal states