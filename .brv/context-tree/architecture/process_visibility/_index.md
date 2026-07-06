---
children_hash: fefa3e3ea14b99838485a0e40498498cadd553a4ace2db8b3b53774aa9eb99ef
compression_ratio: 0.5393063583815029
condensation_order: 1
covers: [sleep_wake_agent_process_visibility_fix.md]
covers_token_total: 1730
summary_level: d1
token_count: 933
type: summary
---
## Sleep-Wake Agent Process Visibility Fix

This cluster documents how FocusBM handles AI process visibility across sleep/wake transitions, with special attention to detached tmux sessions, empty process lists, and refresh-based recovery. Primary drill-down entry: **`sleep_wake_agent_process_visibility_fix.md`**.

### Core behavior
- Sleep/wake events are treated as a visibility problem in the process provider pipeline: wake can temporarily produce incomplete or empty `NSWorkspace.runningApplications` results.
- Detached tmux sessions are a key edge case; visibility must be re-established after wake rather than assumed stable.
- The mitigation strategy is refresh-oriented: wake triggers a delayed refresh so process discovery can repopulate correctly.

### Runtime architecture and rules
- **`BackgroundRefreshService`** listens to both screen and system sleep/wake notifications:
  - sleep: `NSWorkspace.screensDidSleepNotification`, `NSWorkspace.willSleepNotification`
  - wake: `NSWorkspace.screensDidWakeNotification`, `NSWorkspace.didWakeNotification`
- On sleep, `isSleeping = true`.
- On wake, `isSleeping = false` and refresh is delayed by **2.0 seconds** to avoid caching an empty or incomplete result too early.
- Background refresh periodically updates tmux/process information, with a default interval of **15 seconds**.
- When the panel is active, background cache updates are restricted to **visible search items**.
- Refresh on the main queue is applied via `applyBackgroundCache(tmuxPanes:aiProcesses:)`.

### Process detection details
- AI process detection distinguishes between:
  - `tmuxPane(TmuxPane)`
  - `aiProcess(ProcessProvider.AIProcess)`
- For tmux panes, command resolution uses `resolvedNodeCommand ?? command`.
- Tmux agent labels are mapped through `TmuxProvider.agentCommandToEmoji`.
- `tmuxPane` detection delegates to `p.isAIAgent`; `aiProcess` always returns `true`.
- Basename-aware regex matching was added for launcher-invoked binaries.
- Daemon subcommands **`app-server`** and **`mcp-server`** are excluded from AI process detection.

### Related documentation and implementation sources
Use these entries for deeper detail:
- **`sleep_wake_agent_process_visibility_fix.md`** — canonical summary of the fix and mitigation flow.
- **`docs/requirements/sleep-wake-empty-process-list.md`** — stratified analysis of the empty-process-list problem.
- **`docs/requirements/tmux-detached-session-focus.md`** — detached tmux session visibility requirements.
- **`docs/requirements/zombie-process-refresh-plan.md`** — refresh-oriented recovery plan.
- **`docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`** — related resume/missing-dispatch findings.
- **`plan/process-01.md`, `process-02.md`, `process-03.md`, `process-10.md`, `process-11.md`, `process-12.md`, `process-50.md`, `process-100.md`, `process-200.md`, `process-300.md`** — staged process work and evolution.
- **`plan-fix-focus/process-01.md`, `process-10.md`, `process-200.md`, `process-300.md`** — fix-focused process plan.
- **`hammerspoon/focusbm.lua`** — Hammerspoon-side behavior tied to process visibility and refresh.

### Key relationship summary
The fix links three layers:
1. **Process discovery** via `ProcessProvider.listNonTmuxAIProcesses()`
2. **Tmux resolution** via `TmuxProvider.listAIAgentPanes(settings:)` and terminal matching
3. **Wake recovery** via delayed background refresh after sleep/wake events

### Important observed pattern
- The system prefers **reusing existing scan paths** rather than inventing a separate force-reload mechanism.
- Wake timing matters: the delay exists specifically because the process list and terminal app resolution can be incomplete immediately after wake.