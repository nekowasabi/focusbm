---
children_hash: 886423059331dc3bada7a1ad1de894581ff0ec3cd314d945a4e9853f80b1bfd4
compression_ratio: 0.9162072767364939
condensation_order: 3
covers: [architecture/_index.md]
covers_token_total: 907
summary_level: d3
token_count: 831
type: summary
---
# Architecture Domain Overview

The **architecture** domain documents FocusBM’s process-detection and visibility stack: how the app identifies AI agent processes, filters daemon/helper noise, resolves working directories and tmux state, and keeps visibility accurate across sleep/wake transitions.

## Primary cluster: `process_visibility`
Drill down into **`process_visibility/sleep_wake_agent_process_visibility_fix.md`** for the canonical fix.

This cluster centers on a sleep/wake visibility bug: after wake, `NSWorkspace.runningApplications` can briefly return incomplete or empty data, which affects both **tmux-backed agents** and general process discovery.

### Runtime behavior and refresh flow
- **`BackgroundRefreshService`** subscribes to:
  - `NSWorkspace.screensDidSleepNotification`
  - `NSWorkspace.willSleepNotification`
  - `NSWorkspace.screensDidWakeNotification`
  - `NSWorkspace.didWakeNotification`
- Sleep sets `isSleeping = true`.
- Wake sets `isSleeping = false` and delays refresh by **2.0 seconds** to avoid caching incomplete state too early.
- Background refresh runs on a default **15-second** interval.
- When the panel is active, cache updates are limited to **visible search items**.
- Main-queue cache application happens through **`applyBackgroundCache(tmuxPanes:aiProcesses:)`**.

### Process detection and filtering
- AI detection distinguishes between:
  - `tmuxPane(TmuxPane)`
  - `aiProcess(ProcessProvider.AIProcess)`
- `tmuxPane` classification delegates to `p.isAIAgent`.
- `aiProcess` is always treated as AI-related.
- tmux command resolution uses **`resolvedNodeCommand ?? command`**.
- **`TmuxProvider.agentCommandToEmoji`** maps agent labels.
- Basename-aware regex matching supports launcher-invoked binaries.
- Daemon subcommands **`app-server`** and **`mcp-server`** are excluded from AI process detection.

### Architectural relationship
The fix connects three layers:
1. **Process discovery** via `ProcessProvider.listNonTmuxAIProcesses()`
2. **Tmux resolution** via `TmuxProvider.listAIAgentPanes(settings:)` and terminal matching
3. **Wake recovery** via delayed background refresh after sleep/wake events

### Core design pattern
The system prefers **reusing existing scan paths** instead of introducing a separate force-reload mechanism. The delayed wake refresh exists because process and terminal resolution may be incomplete immediately after wake.

## Drill-down references
- **`process_visibility/sleep_wake_agent_process_visibility_fix.md`** — canonical fix summary
- **`docs/requirements/sleep-wake-empty-process-list.md`** — empty-process-list analysis
- **`docs/requirements/tmux-detached-session-focus.md`** — detached tmux visibility requirements
- **`docs/requirements/zombie-process-refresh-plan.md`** — refresh-oriented recovery plan
- **`docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`** — related resume/missing-dispatch findings
- **`plan/process-01.md`, `process-02.md`, `process-03.md`, `process-10.md`, `process-11.md`, `process-12.md`, `process-50.md`, `process-100.md`, `process-200.md`, `process-300.md`** — staged process evolution
- **`plan-fix-focus/process-01.md`, `process-10.md`, `process-200.md`, `process-300.md`** — fix-focused planning
- **`hammerspoon/focusbm.lua`** — Hammerspoon-side visibility and refresh behavior