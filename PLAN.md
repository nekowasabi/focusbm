---
title: "ブックマーク絞り込み画面の横2列表示トグル対応"
status: planning
created: "2026-04-22"
---

# Commander's Intent

## Purpose
ブックマーク件数の増加に伴い縦1列レイアウトでは一覧性と管理性が低下するため、`bookmarks.yml` から切替可能な横2列表示を提供する。パネル占有サイズが大きくなる副作用を設定でオプトインさせ、既存ユーザーの体験を破壊しない。

## End State
`bookmarks.yml` に `bookmarkListColumns: 2` を設定すると絞り込み画面が横2列で描画され、左右矢印と数字キーが2D選択に追従する。未設定/`1`/不正値ではこれまで通り縦1列。ViewModel レベル振る舞いが Swift Testing で自動担保されている。

## Key Tasks
- `AppSettings` に `bookmarkListColumns: Int?` を追加し YAML round-trip を担保
- `SearchViewModel` に `moveLeft/moveRight/selectByDigit` を切り出し、1D↔2D 変換ロジックを集約
- `SearchView` を `LazyVStack`/`LazyVGrid` 切替構造に変更し、`SearchPanel` のキー経路を VM 呼び出しに統一

## Constraints
- 未指定時は既存動作（1列）を維持し、旧 yml の破壊的変更を禁止
- 不正値（0, 3以上, 文字列等）は安全に nil 扱い→1列フォールバック
- 親セッションでは Read/Grep/Glob を行わず、調査・実装はサブエージェント委譲
- キーバインドは既存の `↑↓` / hjkl / 数字キー(1-9) を壊さず左右拡張
- 新規設定キー追加のみで、既存設定の意味論は不変

---

# Progress Map

| Process | Title | Status | File |
|---------|-------|--------|------|
| 1 | AppSettings に bookmarkListColumns フィールド追加 | ☑ done | [→ plan/process-01.md](plan/process-01.md) |
| 2 | YAMLStorage マイグレーションと不正値フォールバック | ☑ done | [→ plan/process-02.md](plan/process-02.md) |
| 3 | SearchViewModel ロジック引き上げ+2D選択遷移 | ☑ done | [→ plan/process-03.md](plan/process-03.md) |
| 4 | SearchView の LazyVStack/LazyVGrid 切替 | ☑ done | [→ plan/process-04.md](plan/process-04.md) |
| 5 | SearchPanel の左右矢印+数字キーVM委譲 | ☑ done | [→ plan/process-05.md](plan/process-05.md) |
| 6 | FocusBMApp の2列時デフォルト幅補正 | ☑ done | [→ plan/process-06.md](plan/process-06.md) |
| 10 | AppSettingsTests 拡張（round-trip 6ケース） | ☑ done | [→ plan/process-10.md](plan/process-10.md) |
| 11 | SearchViewModelGridTests 新設 | ☑ done | [→ plan/process-11.md](plan/process-11.md) |
| 12 | YAMLStorage マイグレーションテスト追加 | ☑ done | [→ plan/process-12.md](plan/process-12.md) |
| 50 | GUI 手動検証チェックリスト | ☐ planning | [→ plan/process-50.md](plan/process-50.md) |
| 100 | 全体回帰テストと Swift build/test 実行 | ☐ planning | [→ plan/process-100.md](plan/process-100.md) |
| 200 | README と bookmarks.yml サンプル更新 | ☐ planning | [→ plan/process-200.md](plan/process-200.md) |
| 300 | OODA 振り返りと教訓記録 | ☐ planning | [→ plan/process-300.md](plan/process-300.md) |

**DAG**: `1→2→{3,4,5,6}→{10,11,12}→100→{50,200}→300`
**DAG凡例**: `{A,B}` = 並列実行可能、`A→B` = A完了後にB実行、`|` = 独立した依存チェーン
**Overall**: ☑ 9/13 completed

---

# References

| @ref | @target | @test |
|------|---------|-------|
| 設定モデル | Sources/FocusBMLib/Models.swift:108-154 | Tests/focusbmTests/AppSettingsTests.swift |
| YAML I/O | Sources/FocusBMLib/YAMLStorage.swift:20-42 | Tests/focusbmTests/AppSettingsTests.swift |
| 画面描画 | Sources/FocusBMApp/SearchView.swift:42 | (GUI 目視) |
| 行UI | Sources/FocusBMApp/BookmarkRow.swift:35-89 | (GUI 目視) |
| 選択状態 | Sources/FocusBMApp/SearchViewModel.swift:22-40 | Tests/FocusBMAppTests/SearchViewModelOrderingTests.swift |
| キー処理 | Sources/FocusBMApp/SearchPanel.swift:121-134 | Tests/FocusBMAppTests/SearchViewModelGridTests.swift (新規) |
| パネル幅 | Sources/FocusBMApp/FocusBMApp.swift:247,319 | (GUI 目視) |

---

# Risks

| リスク | 対策 |
|--------|------|
| 既存 yml との互換崩壊（新キー未指定で壊れる） | 未指定時は nil→1列で明示フォールバック。migration テスト必須 |
| キーバインド競合（hjkl / 矢印 / 数字） | ViewModel 層で入力ディスパッチを集約し、優先度を単体テスト化 |
| 狭幅パネル(既定500px)で2列が破綻 | 2列時のみ最小/推奨幅を補正し、テキスト省略 lineLimit を維持 |

---
