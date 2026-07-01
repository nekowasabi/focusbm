---
children_hash: 381854dd0b705511a9172ad45e97a6e9cff706c7b23d1f89e41f41ef13c54cea
compression_ratio: 0.8556701030927835
condensation_order: 3
covers: [architecture/_index.md]
covers_token_total: 485
summary_level: d3
token_count: 415
type: summary
---
# Architecture

FocusBM architecture knowledge centers on process detection, filtering, and visibility. The main concerns are daemon/helper exclusion, AI agent process listing, tmux process detection, and working-directory resolution. Drill down into the child entries for implementation details.

## Child entry overview

### `process_visibility/_index.md`
Structural summary for the sleep/wake process-visibility fix. This entry identifies `sleep_wake_agent_process_visibility_fix.md` as the canonical source and treats other variants as duplicates or condensed forms.

Key behavior changes:
- `BackgroundRefreshService` listens to both screen sleep/wake and system sleep/wake notifications.
- Wake triggers an immediate refresh.
- When the panel is active, background cache updates are limited to visible search items only.
- AI process detection uses basename-aware regex matching so launcher-invoked binaries are matched correctly.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.

Implementation pattern:
- sleep/wake → visibility evaluation → agent filtering → fix application

Preserved regex anchors:
- `(^|/)`
- `([[:space:]]|$)`

Validation coverage includes tests for `processNamePattern` and daemon filtering, with example process names such as `codex`, `foo.bar`, `node /opt/homebrew/bin/codex app-server`, `node /opt/homebrew/bin/codex --full-auto`, and `/Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled`.

Drill down to `sleep_wake_agent_process_visibility_fix.md` for the full canonical write-up, including front matter, Reason, Raw Concept, Narrative, and Facts.