# Process 3: SearchViewModel ロジック引き上げ+2D選択遷移

## Overview
View 層に散在しているキー処理ロジック（数字キー・選択遷移）を `SearchViewModel` に引き上げ、さらに `bookmarkListColumns` に応じた (row, col) 遷移を集約する。これにより Swift Testing で主要ロジックを自動担保可能にする。

## Affected Files
- `Sources/FocusBMApp/SearchViewModel.swift:22-40` — 以下メソッドを追加:
  - `func moveUp()` / `func moveDown()`（既存があれば拡張）
  - `func moveLeft()` / `func moveRight()`（新規）
  - `func selectByDigit(_ number: Int) -> Bool`（SearchPanel から切り出し）
  - `var columns: Int { appSettings?.bookmarkListColumns ?? 1 }`（派生プロパティ）
  - `func indexToGrid(_ index: Int) -> (row: Int, col: Int)`
  - `func gridToIndex(row: Int, col: Int) -> Int?`

## Implementation Notes
- `selectedIndex` は単一 1D インデックスを維持（内部表現の互換性維持）、2D は計算で導出
- `moveLeft`: columns==1 なら no-op、columns==2 なら selectedIndex-1（行頭なら no-op）
- `moveRight`: columns==1 なら no-op、columns==2 なら selectedIndex+1（行末・範囲外は clamp）
- `moveUp`/`moveDown` は columns を考慮し `selectedIndex ± columns` でクランプ
- 奇数件の最終行右セルは存在しない → `gridToIndex` で nil を返しナビゲーションを抑制
- `selectByDigit`: 既存の `digitToIndex` マップを使い、`selectedIndex` に反映。成功時 true
- `mainListAssignments` 参照箇所は既存のまま（1D 配列ビュー）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - `SearchViewModelGridTests.swift`（Process 11）で各メソッドの期待動作を定義
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] `columns` 派生プロパティ追加
- [x] `indexToGrid`/`gridToIndex` 変換実装
- [x] `moveLeft`/`moveRight`/`moveUp`/`moveDown` 実装（境界クランプ含む）
- [x] `selectByDigit` を SearchPanel から移設
- [x] テストを実行して成功することを確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] 境界条件の helper（`clampIndex` 等）を private に集約
- [x] 「なぜ 1D を内部表現として維持するか」の Why コメント追加
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 2
- Blocks: 4, 5, 11
