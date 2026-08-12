# Process 100: build/test 全体通過確認

## Implementation Brief（コピペ用）

- 背景: P01〜P06（実装）と P10-13/P50（テスト）が完了した時点で、個別 process の Verification Gates だけでは検出できない全体レベルの整合性崩れ（他 process の変更との組み合わせによるビルド失敗・テスト失敗）が残りうる。全体を通しての `swift build && swift test` 実行により、既存41 + 新規テストが揃って通過することを最終確認する。
- 目的: `swift build && swift test` を実行し、既存41+新規テストが全通過することを確認する。コード変更は行わない。
- 変更範囲: なし（実行のみ）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants）: 定数なし
- 禁止事項（該当 Don'ts のみ）:
  - 本 process ではコードを変更しない（失敗時は該当実装 process へ差し戻す。本 process 内での修正は禁止）
- 適用される横断方針（インライン展開）:
  - 変更は計画の Affected Files 内に限定する（本 process は対象ファイルなし）
  - 数値リテラル直書き禁止（本 process では該当なし）
  - 失敗時 UI 割り込み禁止・fail-closed 方針（本 process の検証対象には含まれないが、上流実装がこの方針を守っていることを本ゲートの green で間接確認する）
- 出力順序: 1) 実装（対象外） 2) セルフレビュー（対象外） 3) 修正（対象外） 4) 再レビュー（対象外） 5) ドキュメント確認（対象外） 6) 品質ゲート実行

## Overview

`swift build && swift test` を実行し、exit code 0 かつ失敗テスト0件であることを確認する。失敗した場合は、失敗テストが属するファイルから該当する実装 process（P01〜P06 または P10-13/P50）を特定し、その process へ差し戻す。本 process 自体はコードを一切変更しない。

## Affected Files

なし（実行のみ）

## Symbol Targets

n/a（実行のみ。pre_flight_checks: [git_clean]）

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P100-VG-01 | green | quality | agent | true | `swift build && swift test` | task_delta 全体 | exit code 0 かつ失敗テスト 0 件 | `swift test` の `Executed N tests` を含む末尾サマリー行を逐語引用 | {failure_class: "quality_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "await_input"} | SC-05 | QUALITY-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 100
- gate_ids: [P100-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-100.appendix.md（実行時に Read しない）

## Implementation Notes

- 失敗時は差し戻し先を機械的に特定できるようにする: `swift test` の失敗出力に含まれるテストファイル名から Conflict Matrix（PLAN-open-pr-for-codex.md）の Process 行を逆引きし、該当 process へ差し戻す。
- Why: 本 process をコード変更なしの純粋実行ゲートとする — 品質確認と修正実装を同一 process に混在させると、どの process が「何を変更したか」の追跡可能性（SCOPE-01）が損なわれるため。

## Behavior Specification

対象外: 実行のみ（コード変更を伴わない品質ゲート）

## Red Phase

対象外: 実行のみ

## Green Phase

- [ ] `swift build && swift test` を実行する
- [ ] exit code 0 かつ失敗テスト 0 件であることを確認する
- [ ] 失敗した場合は、失敗テストの所属ファイルから該当実装 process を特定し、差し戻す（本 process では修正しない）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P100-VG-01
- status: unverified
- command_or_action: swift build && swift test
- exit_code: n/a
- expected: "exit 0, Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

対象外: 実行のみ

## Manual Verification

対象外: 自動で十分

## Dependencies

- Requires: P10, P11, P12, P13, P50
- Blocks: P200

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はビルド/テストコマンドの実行確認のみであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
