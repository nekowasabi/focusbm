---
children_hash: cd979fe033b2997ccc338cce4e80b252f375d5d818780fc8d302fe8bc1cee070
compression_ratio: 0.8765880217785844
condensation_order: 3
covers: [architecture/_index.md]
covers_token_total: 551
summary_level: d3
token_count: 483
type: summary
---
## architecture/process_visibility

- **Sleep/Wake Agent Process Visibility Fix** — the core architecture topic for FocusBM’s process visibility across sleep/wake transitions, background refresh behavior, and AI agent detection. See `sleep_wake_agent_process_visibility_fix.md` for the detailed implementation record.

### Structural overview
- `BackgroundRefreshService` listens to both screen sleep/wake and system sleep/wake notifications.
- Wake events take the immediate refresh path.
- `SearchViewModel.applyBackgroundCache` updates visible `searchItems` only when the panel is active.
- `ProcessProvider` uses basename-aware regex matching to avoid launcher path misses.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests cover `processNamePattern` matching and daemon filtering.

### Key flow
sleep/wake notification → set `isSleeping` → on wake `refreshAsync` → fetch tmux panes and AI processes → apply background cache only if active → update items

### Rules and matching patterns
- Basename-aware matching: `(^|/)name([[:space:]]|$)` instead of path-sensitive `bin/name`
- Do not surface daemon subcommands as interactive AI agent processes
- Apply background cache updates only when the panel is active
- Regex anchors used in the fix:
  - `(^|/)` for start-of-path or slash boundary
  - `([[:space:]]|$)` for whitespace or end-of-string termination

### Related entities
- `Sources/FocusBMApp/BackgroundRefreshService.swift`
- `Sources/FocusBMApp/SearchViewModel.swift`
- `Sources/FocusBMLib/ProcessProvider.swift`
- `Tests/focusbmTests/ProcessProviderTests.swift`

### Coverage notes
- AI agent command set includes `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`
- Validated cases include launcher-installed binaries like `/opt/homebrew/bin/codex`, app-bundled Codex paths, and daemon-style invocations such as `node /opt/homebrew/bin/codex app-server`