---
title: Sleep-Wake Agent Process Visibility Fix
summary: Documents the sleep-wake agent process visibility issue, including detached tmux session handling, empty process list symptoms, and refresh-oriented mitigation steps.
tags: []
related: [architecture/process_provider/context.md, architecture/process_visibility/sleep_wake_agent_process_visibility_fix.md]
keywords: []
createdAt: '2026-07-01T23:56:45.567Z'
updatedAt: '2026-07-06T02:28:51.939Z'
---
## Reason
Curate process visibility behavior during sleep/wake transitions and detached tmux sessions

## Raw Concept
**Task:**
Document the sleep-wake agent process visibility fix and related process-list behavior.

**Changes:**
- Captured process visibility and reattachment behavior for tmux-detached sessions
- Recorded launchd-managed respawn and sleep/wake agent process handling
- Preserved focus on SourceKit-LSP, dock, and menu bar processes during lifecycle events
- BackgroundRefreshService listens for both screen and system sleep/wake notifications
- Wake triggers immediate refresh
- Background cache updates are limited to visible search items when the panel is active
- Added basename-aware regex matching for launcher-invoked binaries
- Excluded daemon subcommands app-server and mcp-server from AI process detection
- Added tests for processNamePattern and daemon filtering
- Captured the empty process list symptom during sleep/wake handling
- Captured detached tmux session visibility behavior
- Captured refresh-oriented mitigation notes

**Files:**
- docs/requirements/tmux-detached-session-focus.md
- docs/requirements/zombie-process-refresh-plan.md
- docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md
- plan/process-01.md
- plan/process-02.md
- plan/process-03.md
- plan/process-10.md
- plan/process-11.md
- plan/process-12.md
- plan/process-50.md
- plan/process-100.md
- plan/process-200.md
- plan/process-300.md
- plan-fix-focus/process-01.md
- plan-fix-focus/process-10.md
- plan-fix-focus/process-200.md
- plan-fix-focus/process-300.md
- hammerspoon/focusbm.lua

**Flow:**
sleep/wake event -> process visibility check -> detached tmux handling -> refresh/recovery

**Timestamp:** 2026-07-06T02:28:37.513Z

## Narrative
### Structure
Covers process visibility behavior around sleep/wake transitions, especially when tmux sessions are detached.

### Dependencies
Depends on observing process lists after wake events and validating whether detached sessions remain visible.

### Highlights
Focuses on the empty process list symptom and how refresh behavior is used to recover visibility.

### Rules
- BackgroundRefreshService listens for both screen and system sleep/wake notifications.
- Wake-triggered immediate refresh.
- Background cache updates are limited to visible search items when the panel is active.
- Basename-aware regex matching for launcher-invoked binaries.
- Exclusion of daemon subcommands app-server and mcp-server from AI process detection.
- Tests cover processNamePattern and daemon filtering.

### Examples
- `codex`
- `foo.bar`
- `node /opt/homebrew/bin/codex app-server`
- `node /opt/homebrew/bin/codex --full-auto`
- `/Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled`

## Facts
- **process_visibility**: FocusBM sleep/wake empty AI agent process list fix [project]
- **process_visibility**: - Delayed wake background refresh by about 2 seconds to wait for `NSWorkspace.runningApplications` [project]
- **refresh**: - Delayed wake background refresh by about 2 seconds to wait for `NSWorkspace.runningApplications` [project]
- **process_visibility**: - Documented the stratified analysis in `docs/requirements/sleep-wake-empty-process-list.md` [project]
- **process_visibility**: - `showTmuxAgents: Bool?` [project]
- **process_visibility**: - `tmuxPane(TmuxPane)` [project]
- **process_visibility**: - `aiProcess(ProcessProvider.AIProcess)` [project]
- **process_visibility**: - For `tmuxPane`, uses `resolvedNodeCommand ?? command` [project]
- **process_visibility**: - Maps command to emoji via `TmuxProvider.agentCommandToEmoji` [project]
- **process_visibility**: - Only for `tmuxPane` [project]
- **process_visibility**: - `tmuxPane` delegates to `p.isAIAgent` [project]
- **process_visibility**: - `aiProcess` returns `true` [project]
- **process_visibility**: - `tmux:<displayName>` [project]
- **refresh**: ## `Sources/FocusBMApp/BackgroundRefreshService.swift` [project]
- **process_visibility**: - Service periodically refreshes tmux/process info in the background [project]
- **refresh**: - Service periodically refreshes tmux/process info in the background [project]
- **refresh**: - Default refresh interval: `15` seconds [project]
- **refresh**: - On refresh: [project]
- **process_visibility**: - Skips if sleeping [project]
- **process_visibility**: - Reads `currentShowTmuxAgents` [project]
- **process_visibility**: - If tmux agents are enabled: [project]
- **process_visibility**: - `TmuxProvider.listAIAgentPanes(settings:)` [project]
- **process_visibility**: - `ProcessProvider.listNonTmuxAIProcesses()` [project]
- **process_visibility**: - Applies results on the main queue via `applyBackgroundCache(tmuxPanes:aiProcesses:)` [project]
- **process_visibility**: - Sleep/wake handling: [project]
- **process_visibility**: - Sleep notifications: [project]
- **process_visibility**: - `NSWorkspace.screensDidSleepNotification` [project]
- **process_visibility**: - `NSWorkspace.willSleepNotification` [project]
- **process_visibility**: - Wake notifications: [project]
- **process_visibility**: - `NSWorkspace.screensDidWakeNotification` [project]
- **process_visibility**: - `NSWorkspace.didWakeNotification` [project]
- **process_visibility**: - On sleep: `isSleeping = true` [project]
- **process_visibility**: - On wake: `isSleeping = false` and refresh is delayed by `2.0` seconds [project]
- **refresh**: - On wake: `isSleeping = false` and refresh is delayed by `2.0` seconds [project]
- **process_visibility**: - Wake-delay rationale: [project]
- **process_visibility**: - `NSWorkspace.runningApplications` can still be incomplete immediately after wake [project]
- **refresh**: - Delayed refresh avoids caching an empty result too early [project]
- **process_visibility**: ## `docs/requirements/sleep-wake-empty-process-list.md` [project]
- **process_visibility**: | プロセス取得層 | `ProcessProvider.listNonTmuxAIProcesses()` はスキャン時に tmux 外の AI エージェント候補を再取得する。強制リロードはこの既存経路を再利用できる。 | 高 | [project]
- **process_visibility**: | ターミナル解決層 | `TmuxProvider.findTerminalAppForTTY()` が `NSWorkspace.shared.runningApplications` に依存するため、復帰直後にターミナルアプリの突合が失敗しうる。 | 高 | [project]
- **refresh**: - パネル表示中は `SearchViewModel.refreshForPanelAsync()` を直接実行する。 [project]
- **process_visibility**: 3. 補助対策: wake 通知直後の `BackgroundRefreshService` 更新を約 2 秒遅延する。 [project]
- **refresh**: 3. 補助対策: wake 通知直後の `BackgroundRefreshService` 更新を約 2 秒遅延する。 [project]
