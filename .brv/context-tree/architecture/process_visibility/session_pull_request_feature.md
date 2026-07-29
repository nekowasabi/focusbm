---
title: Session Pull Request Feature
summary: FocusBM opens the selected session’s GitHub PR by resolving a PID-scoped Claude session registry entry and matching structured prUrl values, while rejecting invalid or conflicting candidates.
tags: []
related: [architecture/process_provider/context.md, architecture/process_visibility/process_visibility.md, architecture/process_visibility/sleep_wake_agent_process_visibility_fix.md]
keywords: []
createdAt: '2026-07-29T02:44:26.766Z'
updatedAt: '2026-07-29T02:44:26.766Z'
---
## Reason
Document the FocusBM feature that opens a PR for the selected session and its failure-closed behavior

## Raw Concept
**Task:**
Document the selected-session Pull Request opening feature for FocusBM

**Changes:**
- Added session-linked PR opening for FocusBM
- Implemented PID-scoped Claude session registry lookup
- Validated GitHub PR URLs and rejected conflicting candidates
- Set openSessionPullRequest default hotkey to cmd+p

**Files:**
- Sources/FocusBMLib/SessionPullRequestResolver.swift
- Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift
- Sources/FocusBMApp/SearchPanel.swift
- Tests/focusbmTests/SessionPullRequestResolverTests.swift

**Flow:**
hotkey press -> background resolve by pid/sessionId -> scan sessions-index files -> validate structured prUrl -> close panel and open browser once on success; otherwise return nil and keep panel open

**Timestamp:** 2026-07-29T02:43:51.524Z

**Author:** FocusBM

**Patterns:**
- `^https://github.com/[^/]+/[^/]+/pull/[1-9][0-9]*$` - Valid GitHub PR URL format

## Narrative
### Structure
SessionPullRequestResolver delegates to ClaudeSessionPullRequestResolver for claude commands, while SearchPanel resolves the URL on a background queue and closes the panel only after a validated URL exists.

### Dependencies
Depends on ~/.claude/sessions/<pid>.json for pid/sessionId lookup and ~/.claude/projects/**/sessions-index.json for structured prUrl discovery. The implementation also depends on injected browser opening and main-thread UI updates.

### Highlights
The resolver fails closed on missing, corrupt, mismatched, invalid, or conflicting URLs; unsupported agents such as codex are not registered. Validation is restricted to HTTPS GitHub pull URLs with a positive numeric PR number.

### Rules
session text を走査して推測しない
structured `prUrl` のみを信用する
複数候補は競合として失敗扱い
失敗時はパネルを閉じない
PR解決はバックグラウンド、UI操作はメインスレッド
Codex については現時点で resolver を登録しない

### Examples
Example valid URL: https://github.com/acme/focusbm/pull/42. Example rejected URLs include http://github.com/acme/focusbm/pull/42, https://example.com/acme/focusbm/pull/42, and https://github.com/acme/focusbm/issues/42.

## Facts
- **session_pull_request_feature**: FocusBM adds a feature to open the Pull Request linked to the currently selected session. [project]
- **claude_session_registry**: Claude Code resolution starts from ~/.claude/sessions/<pid>.json using exact pid and sessionId values. [project]
- **pr_url_resolution**: The resolver scans ~/.claude/projects/**/sessions-index.json and only accepts structured prUrl values from matching sessionId entries. [project]
- **valid_pr_url_format**: Only GitHub PR URLs of the form https://github.com/{owner}/{repo}/pull/{number} are valid. [convention]
- **fail_closed_pr_resolution**: Missing, corrupt, invalid, or conflicting candidate URLs return nil and fail closed. [convention]
- **open_session_pr_hotkey**: The default hotkey for opening the session pull request is cmd+p. [project]
- **codex_support_status**: Codex does not yet have a registered resolver because PID support and structured PR URL contract are not confirmed. [project]
- **verification_results**: swift test passed 364 tests and swift build succeeded. [project]
