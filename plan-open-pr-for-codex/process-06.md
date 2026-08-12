# Process 6: BookmarkRow への prLabel 表示

## Implementation Brief（コピペ用）

- 背景: `BookmarkRow.swift`（全101行）の `body`（L34-100）下段 HStack（L85-96）は appName + urlPattern を表示している。`SearchView.swift`（163行）は `BookmarkRow(...)` 呼び出しを2箇所（L48-58 と L80-90 付近）持ち、行データは `(item: SearchItem, label: String?)` タプル。P04 で追加した `SearchViewModel.prLabel(for:)` をこの2箇所から配線し、下段に PR バッジを表示する。
- 目的: `BookmarkRow` に `prLabel: String?` プロパティ（デフォルト nil で既存呼び出し互換）を追加し、下段 HStack に `prLabel` 非 nil のときのみバッジ表示する。`SearchView` の2箇所の呼び出しに `prLabel: viewModel.prLabel(for: pair.item)` を配線する。
- 変更範囲: `Sources/FocusBMApp/BookmarkRow.swift`、`Sources/FocusBMApp/SearchView.swift`、`Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift`（新規）
- ローカル定数表（正本: PLAN.md の ★ Constants。本 process 使用分のみ。生成時転記）: なし（本 process は数値定数を使用しない）
- 禁止事項（該当 Don'ts のみ）:
  - `SearchItem` enum に新規ケースを追加しない（本 process は enum に触れない）
  - PR 取得失敗時に UI 割り込み（NSAlert 等）を出さない — バッジ非表示のみ
  - 既存 appName/urlPattern 表示のレイアウト・行高を変更しない
- 適用される横断方針（インライン展開）:
  - `SearchItem` enum に新規ケースを追加しない（prLabel は `BookmarkRow` の別引数で渡す）
  - PR 取得失敗時に UI 割り込み（NSAlert 等）を出さない — バッジ非表示のみ
  - 数値リテラル直書き禁止（本 process では該当する数値定数なし）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`BookmarkRow` に `prLabel: String? = nil` プロパティを追加し、下段 HStack（L85-96）内の appName/urlPattern 表示と共存する形で、`prLabel` が非 nil の場合のみ `Text(prLabel)` 相当のバッジ要素を追加する。`SearchView` の `BookmarkRow(...)` 呼び出し2箇所（L48-58, L80-90 付近）に `prLabel: viewModel.prLabel(for: pair.item)` を渡す。

## Affected Files

- `Sources/FocusBMApp/BookmarkRow.swift`（`prLabel: String? = nil` プロパティ追加、下段 HStack L85-96 にバッジ表示追加）
- `Sources/FocusBMApp/SearchView.swift`（`BookmarkRow(...)` 呼び出し2箇所 L48-58, L80-90 付近に `prLabel:` 配線）
- `Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift`（新規、全体）

## Symbol Targets

```yaml
- file: Sources/FocusBMApp/BookmarkRow.swift
  symbols:
    - name: prLabel
      kind: property
      body_start_line: n/a (新規追加)
      body_end_line: n/a
      line_hint: プロパティ宣言部（body 前）
    - name: body
      kind: computed_property
      body_start_line: 34
      body_end_line: 100
      line_hint: 90 (SYMBOL_LINE_TOLERANCE=20行 許容、下段HStackはL85-96)
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks: [git_clean, "BookmarkRow 呼び出し2箇所の再 grep 確認"]
- file: Sources/FocusBMApp/SearchView.swift
  symbols:
    - name: body
      kind: computed_property
      body_start_line: 48
      body_end_line: 90
      line_hint: 58 と 80 (BookmarkRow呼び出し2箇所, SYMBOL_LINE_TOLERANCE=20行 許容)
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks: [git_clean, "BookmarkRow 呼び出し2箇所の再 grep 確認"]
- file: Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift
  symbols:
    - name: BookmarkRowPRLabelTests
      kind: test_class
      body_start_line: n/a (新規ファイル)
      body_end_line: n/a
      line_hint: n/a
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks: [git_clean]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P06-VG-01 | red | test | agent | true | `swift test --filter BookmarkRowPRLabelTests` | Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift | exit code != 0（prLabel 未実装のため想定理由で失敗） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-08, BEH-06-01 | TEST-RED |
| P06-VG-02 | green | test | agent | true | `swift test --filter BookmarkRowPRLabelTests` | Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift, Sources/FocusBMApp/BookmarkRow.swift, Sources/FocusBMApp/SearchView.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-08, BEH-06-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 06
- gate_ids: [P06-VG-01, P06-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN.md の ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-06.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: prLabel を SearchItem に持たせない — `FocusBMLib` の純データ enum に App 層の表示都合を混ぜないため（P04 の設計を引き継ぐ）。
- Why: `prLabel: String? = nil` のデフォルト引数 — `SearchView` 以外に `BookmarkRow` の呼び出し元が存在した場合でもコンパイルエラーにならず、既存呼び出しの挙動（バッジなし）を変えないため。
- バッジの色・フォント・具体的なレイアウト（既存 appName/urlPattern との配置順）は Left to Implementation とし、行高を変えないことのみを制約とする。

## Behavior Specification

- System Type: transformation

| behavior_id | 入力 | 出力 | pre_state | post_state | invariants | test_ref |
|---|---|---|---|---|---|---|
| BEH-06-01 | `prLabel: "#123"` | 下段に "#123" テキストが表示される | バッジ要素なし | バッジ要素あり | 既存 appName/urlPattern 表示と共存、行高不変 | BookmarkRowPRLabelTests.body_showsBadge_whenPrLabelProvided |
| BEH-06-02 | `prLabel: nil`（デフォルト） | バッジ要素なし（余白残留なし） | バッジ要素なし | バッジ要素なし | 既存呼び出し元の見た目を変えない | BookmarkRowPRLabelTests.body_hidesBadge_whenPrLabelNil |

### Correctness Criteria

- SC-08: `prLabel` が非 nil のときのみバッジ要素が描画され、nil のときは既存レイアウトと同一（余白追加なし）。

### Left to Implementation

- バッジの色（secondary 色等）・フォント（等幅等）
- 下段 HStack 内でのバッジの配置順（appName/urlPattern との前後関係）

## Frontend Constraints

- cleanup なし。
- state リセットなし。
- エラー時は既存表示維持（prLabel が nil のままバッジ非表示）。

## Visual Verification

visual_scope: true のため本セクションを core に含める。

- 対象: SearchPanel（ホットキー cmd+ctrl+b で表示）
- 基本フロー: パネル表示 → snapshot → 15秒待機後再表示 → snapshot → screenshot 保存
- 確認観点 No.1（レイアウト/文言）: バッジが下段に収まり行高が変わらない
- 合否基準: PR がある cwd の行に "#<数字>" テキストが表示され、PR がない行には表示されない
- スクリーンショット保存先: `plan-open-pr-for-codex/screenshots/process-06-{連番}.png`
- 注記: メニューバーアプリのためブラウザ自動化不可。executor: human の実機確認に落とす（下記 Manual Verification 参照）。

## Red Phase

- [ ] `Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift` を作成し、BEH-06-01〜02 に対応するテストを書く（`prLabel` プロパティ未実装のためコンパイルエラーまたはテスト失敗になることを確認）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P06-VG-01
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "テストが prLabel 未実装により失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `Sources/FocusBMApp/BookmarkRow.swift` に `prLabel` プロパティとバッジ表示を実装し、`Sources/FocusBMApp/SearchView.swift` の2箇所に配線して Red Phase のテストを通す

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P06-VG-02
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 命名・重複コードの整理（挙動を変えない）
- [ ] `swift test --filter BookmarkRowPRLabelTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P06-VG-02
- status: unverified
- command_or_action: swift test --filter BookmarkRowPRLabelTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: `BookmarkRow(prLabel: "#123")` を生成し、view 階層に "#123" テキストが含まれることを `swift test` の出力（ViewInspector 等が使えない場合はスナップショット/文字列表現ベースのアサーション）で確認する。
- シナリオ2（executor: human）: 実機で cmd+ctrl+b により SearchPanel を開き、PR のある cwd の行に "#<数字>" バッジが表示され、行高が既存表示と変わらないことを目視確認する。15秒待機後に再表示し、バックグラウンド解決結果が反映されることも確認する。screenshot は `plan-open-pr-for-codex/screenshots/process-06-{連番}.png` に保存する。
- executor: human のみ残った場合は unverified として報告する。

## Dependencies

- Requires: P04
- Blocks: P13

対象外: HTTP Status Coverage — 本 process は SwiftUI の画面表示であり、HTTP サーバー API には該当しない（gh CLI の exit code で扱う）。
