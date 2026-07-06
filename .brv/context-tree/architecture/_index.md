---
children_hash: 84d0368c085ec138769fc2b2146ef7436404b7f76e8f5f6a8ad74e6ad0ad37d3
compression_ratio: 0.7732718894009216
condensation_order: 2
covers: [context.md, process_visibility/_index.md]
covers_token_total: 1085
summary_level: d2
token_count: 839
type: summary
---
# Architecture Domain Overview

The **architecture** domain covers FocusBM’s process-detection and visibility machinery, especially how the app identifies AI agent processes, handles daemon/helper exclusions, resolves working directories, and keeps process state accurate across sleep/wake transitions.

## Main cluster: `process_visibility`
Primary drill-down: **`process_visibility/sleep_wake_agent_process_visibility_fix.md`**

This cluster documents the sleep/wake visibility fix for AI process discovery. The core issue is that wake events can temporarily return incomplete or empty `NSWorkspace.runningApplications` results, which affects both **tmux-backed agents** and general process visibility.

### Key runtime behavior
- **`BackgroundRefreshService`** listens to:
  - `NSWorkspace.screensDidSleepNotification`
  - `NSWorkspace.willSleepNotification`
  - `NSWorkspace.screensDidWakeNotification`
  - `NSWorkspace.didWakeNotification`
- Sleep sets `isSleeping = true`.
- Wake sets `isSleeping = false` and delays refresh by **2.0 seconds** to avoid caching incomplete data too early.
- Background refresh runs on a default **15-second** interval.
- When the panel is active, cache updates are limited to **visible search items**.
- Main-queue refresh is applied through **`applyBackgroundCache(tmuxPanes:aiProcesses:)`**.

### Process detection and filtering
- AI detection distinguishes between:
  - `tmuxPane(TmuxPane)`
  - `aiProcess(ProcessProvider.AIProcess)`
- `tmuxPane` detection delegates to `p.isAIAgent`.
- `aiProcess` is always treated as AI-related.
- tmux command resolution uses **`resolvedNodeCommand ?? command`**.
- **`TmuxProvider.agentCommandToEmoji`** maps agent labels.
- Basename-aware regex matching supports launcher-invoked binaries.
- Daemon subcommands **`app-server`** and **`mcp-server`** are excluded from AI process detection.

### Architectural relationship
The fix ties together three layers:
1. **Process discovery** via `ProcessProvider.listNonTmuxAIProcesses()`
2. **Tmux resolution** via `TmuxProvider.listAIAgentPanes(settings:)` and terminal matching
3. **Wake recovery** via delayed background refresh after sleep/wake events

### Important pattern
The system prefers **reusing existing scan paths** instead of adding a separate force-reload mechanism. The delayed wake refresh exists because process and terminal resolution can be incomplete immediately after wake.

## Related drill-down entries
Use these for detail:
- **`process_visibility/sleep_wake_agent_process_visibility_fix.md`** — canonical fix summary
- **`docs/requirements/sleep-wake-empty-process-list.md`** — empty-process-list analysis
- **`docs/requirements/tmux-detached-session-focus.md`** — detached tmux visibility requirements
- **`docs/requirements/zombie-process-refresh-plan.md`** — refresh-oriented recovery plan
- **`docs/reports/doctrine-mcp-dispatch-resume-missing-20260702.md`** — related resume/missing-dispatch findings
- **`plan/process-01.md`, `process-02.md`, `process-03.md`, `process-10.md`, `process-11.md`, `process-12.md`, `process-50.md`, `process-100.md`, `process-200.md`, `process-300.md`** — staged process evolution
- **`plan-fix-focus/process-01.md`, `process-10.md`, `process-200.md`, `process-300.md`** — fix-focused planning
- **`hammerspoon/focusbm.lua`** — Hammerspoon-side visibility/refresh behavior