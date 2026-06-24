---
title: Sleep/Wake Agent Process Visibility Fix
summary: FocusBM now refreshes on wake, suppresses background cache updates while inactive, and uses basename-aware pgrep matching plus daemon-process filtering for AI agents.
tags: []
related: []
keywords: []
createdAt: '2026-06-24T02:15:37.493Z'
updatedAt: '2026-06-24T02:15:37.493Z'
---
## Reason
Document the process visibility fix across sleep/wake, background refresh, and process matching behavior

## Raw Concept
**Task:**
Fix FocusBM sleep/wake behavior and improve AI agent process visibility.

**Changes:**
- BackgroundRefreshService now listens for both screen and system sleep/wake notifications
- Wake events trigger an immediate refresh
- Background cache updates only apply to visible search items when the panel is active
- pgrep matching was changed to basename-aware regex matching to avoid launcher path misses
- Daemon subcommands are excluded from AI process detection
- Tests were added for processNamePattern and daemon filtering behavior

**Files:**
- Sources/FocusBMApp/BackgroundRefreshService.swift
- Sources/FocusBMApp/SearchViewModel.swift
- Sources/FocusBMLib/ProcessProvider.swift
- Tests/focusbmTests/ProcessProviderTests.swift

**Flow:**
sleep or wake notification -> update isSleeping -> on wake refreshAsync -> fetch tmux panes and AI processes -> applyBackgroundCache only if active -> updateItems

**Timestamp:** 2026-06-24T02:15:18.799Z

**Patterns:**
- `(^|/)` - Matches command names at the start of a path or after a slash
- `([[:space:]]|$)` - Requires whitespace or end-of-string after the command name

## Narrative
### Structure
BackgroundRefreshService now tracks sleep state with observers for screensDidSleep, willSleep, screensDidWake, and didWake, and only performs refresh work when the system is awake. SearchViewModel retains caches for floating windows, tmux panes, and AI processes, and applyBackgroundCache is guarded by isActive so hidden panels do not immediately mutate visible searchItems.

### Dependencies
ProcessProvider depends on pgrep, ps, proc_pidinfo, lsof fallback, and tmux ancestry checks. The process matching change reduces launcher path misses, and daemon filtering prevents app-server and mcp-server subcommands from appearing as interactive AI agents.

### Highlights
Wake now forces an immediate refresh, the process matcher recognizes basename matches like /opt/homebrew/bin/codex, and test coverage validates both the regex pattern and daemon exclusion behavior.

### Rules
Use the basename-aware process pattern (^|/)name([[:space:]]|$) instead of bin/name. Do not surface daemon subcommands app-server or mcp-server as AI agent processes. Only apply background cache updates to searchItems when the panel is active.

### Examples
Examples covered by tests include codex, foo.bar, node /opt/homebrew/bin/codex app-server, node /opt/homebrew/bin/codex --full-auto, and /Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled.

## Facts
- **background_refresh_sleep_wake_notifications**: BackgroundRefreshService observes both screen sleep/wake notifications and system sleep/wake notifications. [project]
- **background_refresh_on_wake**: On wake, BackgroundRefreshService triggers an immediate refresh. [project]
- **background_cache_active_guard**: SearchViewModel.applyBackgroundCache updates visible searchItems only when isActive is true. [project]
- **process_name_pattern**: ProcessProvider.processNamePattern uses a basename-aware regex pattern of (^|/)name([[:space:]]|$) instead of bin/name. [project]
- **process_name_pattern_tests**: Tests cover processNamePattern. [project]
- **daemon_subcommand_filter**: ProcessProvider filters out daemon subcommands app-server and mcp-server from AI process listings. [project]
- **ai_agent_commands**: ProcessProvider.aiAgentCommands includes claude, aider, gemini, copilot, codex, and hermes. [project]
