# Topic: process_provider

## Overview
Covers the ProcessProvider daemon subcommand filtering mechanism that excludes non-interactive helper processes (app-server, mcp-server, --chrome-native-host) from AI agent process listings.

## Key Concepts
- Daemon subcommand filtering via command-line markers
- pgrep-based process discovery with regex patterns
- tmux parent chain detection via sysctl
- Working directory resolution (proc_pidinfo + lsof fallback)
- Memoization cache for tmux checks

## Related Topics
- architecture/process_visibility - for agent process visibility fixes
