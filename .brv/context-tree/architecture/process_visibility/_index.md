---
children_hash: 478baa8e2dc59fb39a7e13abc4bd81c38fe15003c5dd0f2ca718711b8180121f
compression_ratio: 0.34443099273607747
condensation_order: 1
covers: [sleep_wake_agent_process_visibility_fix.md]
covers_token_total: 1652
summary_level: d1
token_count: 569
type: summary
---
## architecture/process_visibility

### Sleep/Wake Agent Process Visibility Fix
FocusBM’s process visibility behavior was corrected across sleep/wake handling, background refresh, and AI agent detection. See `sleep_wake_agent_process_visibility_fix.md` for the full implementation details.

#### Core changes
- `BackgroundRefreshService` now listens to both screen and system sleep/wake notifications.
- Wake events trigger an immediate refresh.
- `SearchViewModel.applyBackgroundCache` only updates visible `searchItems` when the panel is active.
- `ProcessProvider` switched to basename-aware regex matching to avoid launcher path misses.
- Daemon subcommands `app-server` and `mcp-server` are excluded from AI process detection.
- Tests were added for `processNamePattern` and daemon filtering behavior.

#### Key flow
sleep or wake notification → update `isSleeping` → on wake `refreshAsync` → fetch tmux panes and AI processes → apply background cache only if active → update items

#### Important rules and patterns
- Use basename-aware matching: `(^|/)name([[:space:]]|$)` instead of path-sensitive `bin/name`.
- Do not surface daemon subcommands as interactive AI agent processes.
- Only apply background cache updates when the panel is active.
- Pattern anchors used in the fix:
  - `(^|/)` for start-of-path or slash boundary
  - `([[:space:]]|$)` for whitespace or end-of-string termination

#### Related entities
- `Sources/FocusBMApp/BackgroundRefreshService.swift`
- `Sources/FocusBMApp/SearchViewModel.swift`
- `Sources/FocusBMLib/ProcessProvider.swift`
- `Tests/focusbmTests/ProcessProviderTests.swift`

#### Coverage and examples
- AI agent command set includes `claude`, `aider`, `gemini`, `copilot`, `codex`, and `hermes`.
- Validated cases include launcher-installed binaries like `/opt/homebrew/bin/codex`, app-bundled Codex paths, and daemon-style invocations such as `node /opt/homebrew/bin/codex app-server`.

#### Structure notes
- **Reason**: documents the sleep/wake and process visibility fix.
- **Raw Concept**: captures task, changes, files, flow, regex patterns, and timestamp.
- **Narrative**: describes structure, dependencies, highlights, rules, and examples.
- **Facts**: distills the project behaviors and test coverage into reusable facts.