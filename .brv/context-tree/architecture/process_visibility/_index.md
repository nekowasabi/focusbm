---
children_hash: 9b9ed40e8089ad77cb1366a6075dfe5faad8662b94084dbc8f2d008908ecc1c8
compression_ratio: 0.8004115226337448
condensation_order: 1
covers: [sleep_wake_agent_process_visibility_fix.md]
covers_token_total: 486
summary_level: d1
token_count: 389
type: summary
---
# Process Visibility Sleep/Wake Fix

## Overview
`sleep_wake_agent_process_visibility_fix.md` is the canonical document for the sleep/wake process-visibility fix. The child entries are duplicates or condensed variants, so drill down only if you need alternate phrasing from the abstract/overview.

## Core behavior changes
- `BackgroundRefreshService` now listens to both **screen sleep/wake** and **system sleep/wake** notifications.
- On wake, the service triggers an **immediate refresh**.
- When the panel is active, background cache updates are limited to **visible search items** only.
- AI process detection uses **basename-aware regex matching** so launcher-invoked binaries are matched correctly.
- Daemon subcommands **`app-server`** and **`mcp-server`** are excluded from AI process detection.

## Important implementation details
- The fix is structured as a pipeline:
  - **sleep/wake**
  - **visibility evaluation**
  - **agent filtering**
  - **fix application**
- Preserved regex patterns:
  - `(^|/)`
  - `([[:space:]]|$)`

## Tests and validation
- Includes tests for:
  - `processNamePattern`
  - daemon filtering
- Test examples preserved in the canonical file include:
  - `codex`
  - `foo.bar`
  - `node /opt/homebrew/bin/codex app-server`
  - `node /opt/homebrew/bin/codex --full-auto`
  - `/Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled`

## Drill-down entry
- `sleep_wake_agent_process_visibility_fix.md` — canonical source with full front matter, Reason, Raw Concept, Narrative, and Facts.