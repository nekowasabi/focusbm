# Process 50: 既存ショートカットテスト回帰確認

## Implementation Brief（コピペ用）

- 背景: `Tests/FocusBMAppTests/SessionPullRequestShortcutTests.swift` は既存のショートカット（cmd+p 等）の挙動を検証するテストであり、P02/P03 でリゾルバに command 注入・codex 登録が加わった後も、既存の "claude" 用途の挙動が壊れていないことを確認する必要がある。
- 目的: `SessionPullRequestShortcutTests.swift` を変更せずに実行し、全通過することを確認する。
- 変更範囲: なし（実行のみ。テストファイル・実装ファイルいずれも編集しない）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants）: 定数なし
- 禁止事項（該当 Don'ts のみ）:
  - `SessionPullRequestShortcutTests.swift` を一切変更しない（1文字も編集しない）
  - テストが失敗した場合にテスト側を修正しない。実装側の互換性破壊とみなし、P02/P03 に差し戻す
- 適用される横断方針（インライン展開）:
  - 既存テスト（41件）を壊さない・変更しない
  - 失敗時はテストを直すのでなく実装側の互換性破壊として P02/P03 に差し戻す
- 出力順序: 1) 実装（本 process では実行のみのため n/a） 2) セルフレビュー（結果確認） 3) 修正（該当なし。失敗時は P02/P03 へ差し戻し） 4) 再レビュー（該当なし） 5) ドキュメント確認 6) 品質ゲート実行

## Overview

`SessionPullRequestShortcutTests.swift` に変更を加えず、P02/P03（リゾルバの command 注入・codex 登録）完了後に `swift test --filter SessionPullRequestShortcutTests` を実行する。全テストが通過することを確認する回帰確認 process。失敗した場合はテストを修正するのではなく、実装側（P02/P03）の互換性破壊として差し戻す。

## Affected Files

- 変更なし（`Tests/FocusBMAppTests/SessionPullRequestShortcutTests.swift` は実行対象のみ、編集しない）

## Symbol Targets

symbol_targets: n/a（変更なし・実行のみ）

```yaml
- file: Tests/FocusBMAppTests/SessionPullRequestShortcutTests.swift
  symbols: []
  patch_only: true  # 本 process はファイルへの書き込みを一切行わない
  disjoint_guarantee: n/a
  pre_flight_checks: [git_clean, "P03 完了確認（SessionPullRequestResolver への command 注入・codex 登録が完了していること）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P50-VG-01 | green | test | agent | true | `swift test --filter SessionPullRequestShortcutTests` | Tests/FocusBMAppTests/SessionPullRequestShortcutTests.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-05 | TEST-GREEN, SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 50
- gate_ids: [P50-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-50.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: テストを直さず実装側に差し戻す規定を採用 — `SessionPullRequestShortcutTests.swift` は "claude" 用途の既存契約を表現しており、この契約はリゾルバ変更（P02/P03）によって壊されてはならない。テスト側を「合わせて修正」すると、既存ユーザーへの実際の挙動破壊を見逃すリスクがあるため、失敗は常に実装側の回帰として扱う。
- 本 process は新規実装を行わない。P02/P03 完了後の確認ステップとしてのみ機能する。

## Behavior Specification

対象外: 変更なしの回帰実行のみ。検証対象の振る舞いは既存 `SessionPullRequestShortcutTests.swift` が表現する契約（P02/P03 で変更されるリゾルバに対する既存 "claude" 用途の互換性）であり、本 process はそれを無変更のまま実行して確認する。

## Red Phase

対象外: 変更なしの回帰実行のみ。

## Green Phase

- [ ] `swift test --filter SessionPullRequestShortcutTests` を実行し、全テストが通過することを確認する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P50-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestShortcutTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

対象外: 変更なしの回帰実行のみ。

## Manual Verification

対象外: 自動テストで十分。

## Dependencies

- Requires: P03
- Blocks: P100

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process は既存テストの無変更回帰実行のみであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
