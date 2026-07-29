- FocusBM adds a “open selected session’s Pull Request” feature that resolves a GitHub PR from the currently selected session and opens it in the browser.
- Resolution is PID-scoped and starts from `~/.claude/sessions/&lt;pid&gt;.json`, using exact `pid` and `sessionId` matching before searching for PR data.
- The resolver only trusts structured `prUrl` fields from `~/.claude/projects/**/sessions-index.json`; it does not infer PRs from session text.
- Validation is strict: only HTTPS GitHub PR URLs matching `https://github.com/{owner}/{repo}/pull/{number}` are accepted.
- The system fails closed on missing, corrupt, mismatched, invalid, or conflicting candidates: it returns `nil` and keeps the panel open rather than guessing.
- SearchPanel performs resolution on a background queue, closes the panel only after a validated URL is found, and then opens the browser on success.
- Default hotkey is `cmd+p`; unsupported agents such as Codex are not registered yet because PID support and the structured PR URL contract are not confirmed.

Structure / sections summary:
- Front matter provides title, summary, tags, related documents, and timestamps.
- `Reason` explains that the document exists to describe the PR-opening feature and its failure-closed behavior.
- `Raw Concept` lists the implementation changes, affected files, flow, and validation pattern.
- `Narrative` is organized into Structure, Dependencies, Highlights, Rules, and Examples, describing resolver delegation, file dependencies, fail-closed behavior, and accepted/rejected URLs.
- `Facts` enumerates the core product and implementation facts, including the hotkey, URL format, Codex support status, and test/build verification.

Notable entities, patterns, or decisions:
- `SessionPullRequestResolver` delegates to `ClaudeSessionPullRequestResolver` for Claude commands.
- Browser opening and panel closing depend on injected browser-opening logic and main-thread UI updates.
- The regex pattern `^https://github.com/[^/]+/[^/]+/pull/[1-9][0-9]*$` is the canonical PR URL validator.
- The architecture explicitly separates background PR resolution from UI-thread actions.
- Verification notes report `swift test` passed 364 tests and `swift build` succeeded.