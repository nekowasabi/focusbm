# Process 11: SearchViewModelGridTests 新設

## Overview
`Tests/FocusBMAppTests/SearchViewModelGridTests.swift` を新規作成し、Process 3 で引き上げた 2D 遷移ロジックを網羅的に担保する。

## Affected Files
- `Tests/FocusBMAppTests/SearchViewModelGridTests.swift`（新規）

## Implementation Notes
- 既存 `SearchViewModelOrderingTests.swift` のセットアップパターンに倣う
- Swift Testing (`@Test`) 形式で以下関数を実装:
  - `test_columns_default_is1()`
  - `test_columns_from_settings_is2()`
  - `test_indexToGrid_2col_mapsCorrectly()` — 0→(0,0), 1→(0,1), 2→(1,0), 3→(1,1)
  - `test_gridToIndex_2col_outOfRange_returnsNil()`
  - `test_moveRight_2col_incrementsIndex()`
  - `test_moveRight_2col_atRowEnd_doesNotOverflow()`
  - `test_moveLeft_2col_decrementsIndex()`
  - `test_moveLeft_2col_atRowStart_noop()`
  - `test_moveDown_2col_incrementsByColumns()`
  - `test_moveUp_2col_decrementsByColumns()`
  - `test_moveLeft_1col_isNoop()`
  - `test_moveRight_1col_isNoop()`
  - `test_oddCount_lastCell_movementSkipsEmpty()`
  - `test_switchColumns_preservesSelectedItem()` — 1→2 列切替で同じブックマークが選択状態維持
  - `test_selectByDigit_setsIndex()`
  - `test_selectByDigit_invalidNumber_returnsFalse()`

## Implementation Notes（テストデータ）
- テスト用 `BookmarkStore` はメモリ内に5件のダミーブックマークを作成
- `AppSettings` を直接構築し `viewModel.appSettings = settings` で注入
- `selectedIndex` の初期値は 0

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - 全関数を追加し Process 3 実装前で Red 確認
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 3 完了後に全関数が Green になることを確認
- [x] `swift test --filter SearchViewModelGridTests` で通過確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] ダミーデータ生成を `makeViewModel(count: Int, columns: Int)` helper に集約
- [x] 命名規則を既存 Ordering テストと整合
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 3
- Blocks: 100
