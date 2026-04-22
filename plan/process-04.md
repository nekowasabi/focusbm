# Process 4: SearchView の LazyVStack/LazyVGrid 切替

## Overview
`SearchView` のリスト描画を `viewModel.columns` に応じて `LazyVStack`（1列）と `LazyVGrid`（2列）で切り替える。選択状態ハイライトは既存と同じ visual を保つ。

## Affected Files
- `Sources/FocusBMApp/SearchView.swift:42` — `LazyVStack(spacing: 2)` 部分を分岐描画
- `Sources/FocusBMApp/BookmarkRow.swift:35-89` — 幅制約のみ微調整（`.lineLimit(1)` 維持）

## Implementation Notes
- 条件分岐の最小差分:
  ```swift
  // Why: 列数は VM の派生プロパティに集約し、View は描画選択のみ担う
  if viewModel.columns == 2 {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
          ForEach(...) { ... }
      }
  } else {
      LazyVStack(spacing: 2) { ForEach(...) { ... } }
  }
  ```
- 選択ハイライト (`.background(Color.accentColor.opacity(0.2))` 等) は `BookmarkRow` 内部に維持、2列でも動作する設計
- 奇数件の最終行右セルは空のまま（`LazyVGrid` の標準挙動）
- `BookmarkRow` の `maxWidth: .infinity` は GridItem 側で列幅が決まるためそのまま保持
- アイコン（✈️ 📖 等）の絵文字幅は `.lineLimit(1)` で既存を維持

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - View 層は目視確認だが、Snapshot 不在のため Process 50 のチェックリストで定性検証
- [x] テストを実行して失敗することを確認（該当なしなら skip 記録）

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] `if viewModel.columns == 2` 分岐追加
- [x] `LazyVGrid` + 2カラム GridItem 定義
- [x] 1列パスは既存 `LazyVStack` を維持
- [x] `swift build` で警告なし
- [x] 手動起動で1列→2列切替を確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] GridItem 定義を private static let に抽出
- [x] Why コメントで「列数派生は VM に集約」旨を明記
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 3
- Blocks: 50
