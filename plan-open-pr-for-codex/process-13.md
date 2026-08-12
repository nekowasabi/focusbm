# Process 13: BookmarkRow バッジ表示テスト

## Implementation Brief（コピペ用）

- 背景: P06 で `BookmarkRow` に `prLabel: String?`（デフォルト nil）が追加され、`SearchView` の呼び出し2箇所に配線される。`prLabel` が nil の場合にバッジ要素が存在しないこと、`"#123"` のような値がある場合にテキストが存在することを検証する必要があるが、SwiftUI ビューの単体検証は ViewInspector 等の依存追加なしには難しい。
- 目的: `Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift` に、`prLabel` の決定ロジック（表示文字列生成、nil/非nil の分岐）を検証対象としたテストを追加する。
- 変更範囲: `Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift`（新規）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）: 定数なし（本 process は `prLabel` の nil/非nil 分岐確認のみで、数値定数は使用しない）
- 禁止事項（該当 Don'ts のみ）:
  - ViewInspector 等の新規テスト依存を追加しない
  - SwiftUI ビュー階層の視覚的検証（スナップショット等）を本 process の自動テストで行わない（P06 の Manual Verification に委ねる）
  - 数値リテラル直書き禁止（本 process では数値定数を使わないため該当なし）
- 適用される横断方針（インライン展開）:
  - テストは実 gh・実ネットワークに依存しない（`prLabel` は文字列/nilの直接注入で完結する）
  - 既存テスト（41件）を壊さない・変更しない
  - テストクラスに docblock を付与し、配下メソッドを正常系/異常系に分類した一覧を記述。各テストメソッドにも担保内容の docblock
  - 数値リテラルは定数参照（テスト内の期待値表明は可）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`BookmarkRowPRLabelTests.swift` を新設し、SwiftUI ビュー階層そのものではなく `prLabel` の決定ロジック（表示文字列生成: `SearchViewModel.prLabel(for:)` が返す値がそのまま `BookmarkRow` の `prLabel` プロパティへ渡ること、`nil`/`"#123"` の値そのものの妥当性）を検証対象とする。`BookmarkRow` が `prLabel: String?` プロパティを受け取り、デフォルト値が nil であることをコンパイル・インスタンス化レベルで確認する。ビジュアルなバッジ有無の目視確認は P06 の Manual Verification（executor: human）シナリオに委ねる。

## Affected Files

- `Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift`（新規）

## Symbol Targets

```yaml
- file: Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift
  symbols:
    - name: BookmarkRowPRLabelTests
      kind: test_class
      body_start_line: n/a (新規ファイル)
      body_end_line: n/a
      line_hint: n/a
  patch_only: false
  disjoint_guarantee: true  # テストファイル1:1、他 process はこのファイルを触らない
  pre_flight_checks: [git_clean, "P06 完了確認（BookmarkRow.prLabel: String?（デフォルト nil）実装済みであること）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P13-VG-01 | green | test | agent | true | `swift test --filter BookmarkRowPRLabelTests` | Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift | exit code == 0 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-03 | TEST-GREEN, SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 13
- gate_ids: [P13-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-13.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: ViewInspector 等の SwiftUI ビュー検証ライブラリを導入しない — 新規テスト依存の追加は横断方針で禁止されており、既存41件のテストスイートの依存関係を変えないため。代わりに `prLabel` プロパティの値そのもの（nil/非nil、フォーマット済み文字列）をロジックレベルで検証する。
- Why: 視覚的なバッジ有無確認を自動テストの対象外とする — SwiftUI ビュー階層の単体検証はライブラリなしでは困難であり、無理に自動化すると壊れやすい実装詳細への依存（View の内部構造への直接アクセス等）が発生するため。視覚確認は P06 の Manual Verification（executor: human）シナリオへ委ねる。
- テストクラス docblock には「正常系: prLabel="#123"のときの文字列妥当性、prLabel デフォルト値がnilであること」「異常系: prLabel=nilのときの非表示相当の状態確認」の分類一覧を明記する。

## Behavior Specification

対象外: テスト process のため Behavior Specification は実装側 P06 の BEH-06-* を正本とする。本 process が test_ref として実体化する behavior_id は以下。

| behavior_id | 実装側正本 | 本 process での test_ref |
|---|---|---|
| BEH-06-01 | process-06.md | BookmarkRowPRLabelTests.prLabel_defaultsToNil |
| BEH-06-02 | process-06.md | BookmarkRowPRLabelTests.prLabel_acceptsFormattedString |

## Red Phase

- [ ] `prLabel` のデフォルト値確認・フォーマット済み文字列受け取りのテストメソッドを追加する。P06（依存 process）が未完了の時点で追加した場合は、`BookmarkRow.prLabel` 未実装のためコンパイルエラーまたは失敗になることを確認する。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P13-VG-01
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "BookmarkRow.prLabel 未実装のため追加テストが失敗する（Red 相当）"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] P06 完了後に、追加したテストが green になることを確認する。P06 が本 process より先に完了している場合は Red Phase を「Red 省略: 実装先行のため n/a」として扱い、本 Phase から開始してよい。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P13-VG-01
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] テストメソッド名・docblock の整理（アサーション内容は変えない）
- [ ] `swift test --filter BookmarkRowPRLabelTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P13-VG-01
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

対象外: 自動テストで十分（視覚的なバッジ表示確認は P06 の Manual Verification シナリオに委ねる）。

## Dependencies

- Requires: P06
- Blocks: P50

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process は SwiftUI ビューのプロパティ受け渡しロジックのユニットテストであり、Visual Verification は ViewInspector 等の依存追加禁止のため対象外（視覚確認は P06 の Manual Verification へ委ねる）。HTTP サーバーには該当しない。
