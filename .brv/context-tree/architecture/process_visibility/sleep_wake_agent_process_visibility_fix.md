---
title: Sleep/Wake Agent Process Visibility Fix
summary: FocusBM now refreshes on wake, suppresses background cache updates while inactive, and uses basename-aware pgrep matching plus daemon-process filtering for AI agents.
tags: []
related: []
keywords: []
createdAt: '2026-06-24T02:15:37.493Z'
updatedAt: '2026-06-24T02:15:37.493Z'
consolidated_at: '2026-06-24T02:30:53.262Z'
consolidated_from: [{date: '2026-06-24T02:30:53.263Z', path: architecture/process_visibility/sleep_wake_agent_process_visibility_fix.abstract.md, reason: 'These three files describe the same FocusBM sleep/wake and process visibility fix at different verbosity levels. The main markdown file is the richest source, while the abstract and overview are condensed duplicates that overlap heavily with it.'}, {date: '2026-06-24T02:30:53.263Z', path: architecture/process_visibility/sleep_wake_agent_process_visibility_fix.overview.md, reason: 'These three files describe the same FocusBM sleep/wake and process visibility fix at different verbosity levels. The main markdown file is the richest source, while the abstract and overview are condensed duplicates that overlap heavily with it.'}]
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

- FocusBM’s process visibility behavior was fixed across sleep/wake handling, background refresh, and AI agent detection.
- BackgroundRefreshService now observes both screen and system sleep/wake notifications, and wake events trigger an immediate refresh.
- SearchViewModel only applies background cache updates to visible search items when the panel is active, preventing inactive UI mutation.
- ProcessProvider changed from path-sensitive matching to basename-aware regex matching, reducing misses for launcher-installed binaries.
- Daemon subcommands such as app-server and mcp-server are excluded from AI process detection so they do not appear as interactive agents.
- Tests were added/updated to validate the process-name regex and daemon filtering behavior.
- Notable pattern rules include `(^|/)` for start-or-slash matching and `([[:space:]]|$)` for command-name termination.

- Structure / sections summary:
  - **Reason** states the purpose: document the sleep/wake and process visibility fix.
  - **Raw Concept** lists the concrete task, code changes, files affected, event flow, regex patterns, and timestamp.
  - **Narrative** expands on structure, dependencies, highlights, rules, and examples.
  - **Facts** enumerates the main implemented behaviors and test coverage in concise project facts.

- Notable entities / decisions:
  - Key components: `BackgroundRefreshService`, `SearchViewModel`, `ProcessProvider`, and `ProcessProviderTests`.
  - Refresh flow: sleep/wake notification → `isSleeping` update → on wake `refreshAsync` → fetch tmux panes and AI processes → apply cache only if active → update items.
  - AI agent command set includes `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
  - Example cases mention `codex`, `foo.bar`, launcher-path binaries like `/opt/homebrew/bin/codex`, and app-bundled Codex paths.