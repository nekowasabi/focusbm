# Process 10: codex リゾルバ対応テスト

## Implementation Brief（コピペ用）

- 背景: P03 で `SessionPullRequestResolver.init()` に `"claude"` と `"codex"` の両方が登録され、`supports(command:)` が `"codex"` で true を返すようになる。この振る舞いと、codex コマンドのリゾルバが cwd 経由で URL を解決すること、`sessionIndex` フォールバックを使わないことをテストで担保する必要がある。
- 目的: `Tests/focusbmTests/SessionPullRequestResolverTests.swift` に codex 対応の確認テストを追加する。
- 変更範囲: `Tests/focusbmTests/SessionPullRequestResolverTests.swift`（既存ファイルへの追記のみ）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）: 定数なし（本 process は登録済みコマンド名の分岐確認のみで、数値定数は使用しない）
- 禁止事項（該当 Don'ts のみ）:
  - 既存のテストメソッド・アサーションを変更しない（追記のみ）
  - 実 gh・実ネットワークに依存するテストを書かない（`pullRequestURLProvider` 相当のモック注入で代替する）
  - 数値リテラル直書き禁止（本 process では数値定数を使わないため該当なし）
- 適用される横断方針（インライン展開）:
  - テストは実 gh・実ネットワークに依存しない（クロージャ/プロバイダ注入でモック）
  - 既存テスト（41件）を壊さない・変更しない
  - テストクラスに docblock を付与し、配下メソッドを正常系/異常系に分類した一覧を記述。各テストメソッドにも担保内容の docblock
  - 数値リテラルは定数参照（テスト内の期待値表明は可）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`SessionPullRequestResolverTests.swift` に以下を追加する: (1) `supports("codex")` が true を返すこと、(2) `supports("aider")` が引き続き false を返すこと（既存テストの維持確認）、(3) codex コマンドのリゾルバインスタンスにモック `pullRequestURLProvider` を注入し、workingDirectory 経由の解決がモック URL を返すこと、(4) codex コマンドでは `sessionIndex` フォールバックが使用されない（呼び出されない）ことをモックで検証する。

## Affected Files

- `Tests/focusbmTests/SessionPullRequestResolverTests.swift`（既存ファイルへのテストメソッド追加のみ）

## Symbol Targets

```yaml
- file: Tests/focusbmTests/SessionPullRequestResolverTests.swift
  symbols:
    - name: SessionPullRequestResolverTests
      kind: test_class
      body_start_line: n/a (既存ファイル、追記箇所は末尾)
      body_end_line: n/a
      line_hint: 末尾に追記
  patch_only: false
  disjoint_guarantee: true  # テストファイル1:1、他 process はこのファイルを触らない
  pre_flight_checks: [git_clean, "P03 完了確認（SessionPullRequestResolver.init() に codex 登録・supports(command:) 実装済みであること）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P10-VG-01 | green | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | Tests/focusbmTests/SessionPullRequestResolverTests.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01 | TEST-GREEN, SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 10
- gate_ids: [P10-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-10.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: 実 gh 呼び出しでなくモック `pullRequestURLProvider` 注入を使う — CI・オフライン環境で決定論的に動かすため。既存パターン（P02 の internal init 経路）をそのまま踏襲する。
- テストクラス docblock には「正常系: supports("codex")==true、codex+cwd 経由解決」「異常系: supports("aider")==false（回帰維持）、codex では sessionIndex 未使用」の分類一覧を明記する。
- 各テストメソッドには担保内容（何を保証するテストか）を1行 docblock として付与する。

## Behavior Specification

対象外: テスト process のため Behavior Specification は実装側 P03 の BEH-03-* を参照。本 process が test_ref として実体化する behavior_id は以下。

| behavior_id | 実装側正本 | 本 process での test_ref |
|---|---|---|
| BEH-03-01 | process-03.md | SessionPullRequestResolverTests.supports_returnsTrue_forCodex（予定名） |

## Red Phase

- [ ] `supports("codex")`・codex+cwd 経由解決・sessionIndex 未使用のテストメソッドを追加する。P03（依存 process）が未完了の時点で追加した場合は、`SessionPullRequestResolver.init()` に codex 未登録のため失敗することを確認する。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P10-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "codex 未登録のため追加テストが失敗する（Red 相当）"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] P03 完了後（`SessionPullRequestResolver.init()` に codex 登録済み・`supports(command:)` 実装済み）に、追加したテストが green になることを確認する。P03 が本 process より先に完了している場合は Red Phase を「Red 省略: 実装先行のため n/a」として扱い、本 Phase から開始してよい。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P10-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] テストメソッド名・docblock の整理（アサーション内容は変えない）
- [ ] `swift test --filter SessionPullRequestResolverTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P10-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

対象外: 自動テストで十分。

## Dependencies

- Requires: P03
- Blocks: P50

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はライブラリ内部リゾルバのユニットテストであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
