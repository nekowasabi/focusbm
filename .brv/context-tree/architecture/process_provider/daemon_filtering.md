---
title: Daemon Filtering
summary: ProcessProvider filters non-interactive daemon processes (app-server, mcp-server, --chrome-native-host) from AI agent listings using command-line marker detection
tags: []
related: [architecture/process_visibility/sleep_wake_agent_process_visibility_fix.md]
keywords: []
createdAt: '2026-06-27T06:13:00.431Z'
updatedAt: '2026-06-27T06:13:00.431Z'
---
## Reason
Document ProcessProvider daemon subcommand filtering including --chrome-native-host addition

## Raw Concept
**Task:**
Filter non-interactive daemon/helper processes from AI agent process listings in FocusBM

**Changes:**
- Added --chrome-native-host to daemonSubcommands to exclude Claude Code Chrome native host helper processes
- Added ProcessProviderTests coverage for claude --chrome-native-host filtering
- Adopted command-line marker filtering approach instead of changing pgrep pattern

**Files:**
- Sources/FocusBMLib/ProcessProvider.swift
- Tests/focusbmTests/ProcessProviderTests.swift

**Flow:**
listNonTmuxAIProcesses -> findProcessesByName -> skip tmux processes -> getCommandLineArgs -> isDaemonCommandLine check -> skip if daemon -> collect remaining

**Timestamp:** 2026-06-27

**Patterns:**
- `(^|/)claude([[:space:]]|$)` - pgrep pattern for matching claude process basename
- `(^|/)aider([[:space:]]|$)` - pgrep pattern for matching aider process basename
- `(^|/)gemini([[:space:]]|$)` - pgrep pattern for matching gemini process basename
- `(^|/)copilot([[:space:]]|$)` - pgrep pattern for matching copilot process basename
- `(^|/)codex([[:space:]]|$)` - pgrep pattern for matching codex process basename
- `(^|/)hermes([[:space:]]|$)` - pgrep pattern for matching hermes process basename

## Narrative
### Structure
ProcessProvider is a Swift struct in Sources/FocusBMLib/ProcessProvider.swift that detects AI agent processes running outside tmux. It uses pgrep with regex patterns to find processes by command name, then filters out tmux processes and daemon/helper subprocesses.

### Dependencies
Uses pgrep for process discovery, ps for command-line args and TTY, proc_pidinfo (Darwin API) for working directory with lsof fallback, sysctl for parent PID traversal (avoids subprocess spawn)

### Highlights
daemonSubcommands = ["app-server", "mcp-server", "--chrome-native-host"] — command-line markers for non-interactive helper processes. isDaemonCommandLine() checks if commandLine contains " " + subcommand (space-prefixed match to avoid partial matches). Same executable can run interactively or as a helper — filtering is done on command-line args, not process name. tmuxCheckCache memoization avoids repeated sysctl calls within same refresh cycle. getWorkingDirectory uses proc_pidinfo (Darwin API, ~1ms) with lsof fallback (~100-300ms). aiAgentCommands: claude, aider, gemini, copilot, codex, hermes.

### Rules
Rule 1: Processes in tmux panes are excluded from AI agent listings.
Rule 2: Processes matching daemonSubcommands (app-server, mcp-server, --chrome-native-host) are excluded.
Rule 3: Daemon detection uses command-line string matching with space prefix (contains(" " + subcommand)).
Rule 4: tmux parent chain traversal is capped at 20 ancestors with cycle detection.
Rule 5: Memoization cache is cleared at the start of each refresh cycle via clearTmuxCheckCache().
