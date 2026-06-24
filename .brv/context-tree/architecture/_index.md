---
children_hash: af086825f961463875920f66cf520e4f9dede2edbde760852ee5f6e4dffa38da
compression_ratio: 0.7617554858934169
condensation_order: 2
covers: [process_visibility/_index.md]
covers_token_total: 638
summary_level: d2
token_count: 486
type: summary
---
## architecture/process_visibility

- **Sleep/Wake Agent Process Visibility Fix** — documents the fix for FocusBM’s process visibility across sleep/wake transitions, background refresh behavior, and AI agent detection. Drill down into `sleep_wake_agent_process_visibility_fix.md` for implementation details.

### Structural overview
- `BackgroundRefreshService` now listens to both screen sleep/wake and system sleep/wake notifications.
- Wake events trigger an immediate refresh path.
- `SearchViewModel.applyBackgroundCache` only updates visible `searchItems` when the panel is active.
- `ProcessProvider` now uses basename-aware regex matching to avoid launcher path misses.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests cover `processNamePattern` behavior and daemon filtering.

### Key flow
sleep/wake notification → update `isSleeping` → on wake `refreshAsync` → fetch tmux panes and AI processes → apply background cache only if active → update items

### Rules and matching patterns
- Use basename-aware matching: `(^|/)name([[:space:]]|$)` instead of path-sensitive `bin/name`.
- Do not surface daemon subcommands as interactive AI agent processes.
- Only apply background cache updates when the panel is active.
- Regex anchors used in the fix:
  - `(^|/)` for start-of-path or slash boundary
  - `([[:space:]]|$)` for whitespace or end-of-string termination

### Related entities
- `Sources/FocusBMApp/BackgroundRefreshService.swift`
- `Sources/FocusBMApp/SearchViewModel.swift`
- `Sources/FocusBMLib/ProcessProvider.swift`
- `Tests/focusbmTests/ProcessProviderTests.swift`

### Coverage notes
- AI agent command set includes `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- Validated cases include launcher-installed binaries like `/opt/homebrew/bin/codex`, app-bundled Codex paths, and daemon-style invocations such as `node /opt/homebrew/bin/codex app-server`.