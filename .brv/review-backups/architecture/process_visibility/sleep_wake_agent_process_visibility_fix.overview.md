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