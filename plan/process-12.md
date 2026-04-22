# Process 12: YAMLStorage マイグレーションテスト追加

## Overview
旧 yml（`bookmarkListColumns` 未指定）を読み込んで互換性が維持されること、及び不正値が nil フォールバックされることを自動担保する。

## Affected Files
- `Tests/focusbmTests/AppSettingsTests.swift` もしくは `Tests/focusbmTests/YAMLStorageTests.swift`（既存あればそれ、無ければ前者に追加）

## Implementation Notes
- 追加テスト:
  - `test_legacyYAML_withoutBookmarkListColumns_loadsAsNil()` — 既存キーのみの yml を decode し、新キーが nil で互換性維持
  - `test_yaml_withInvalidBookmarkListColumns_fallsBackToNil()` — 値 3 / 0 / 負値 を nil 扱い
  - `test_yaml_withBookmarkListColumns_2_preservedOnEncodeDecode()` — encode → decode round-trip で 2 が保持
- 旧 yml サンプル:
  ```yaml
  hotkey:
    togglePanel: "cmd+ctrl+b"
  panelWidth: 500
  ```
- 不正値サンプル:
  ```yaml
  bookmarkListColumns: 3
  ```
- 期待: `settings.bookmarkListColumns == nil`

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - Process 2 の正規化ロジック未実装状態で Red 確認
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 2 完了後に全テストが Green
- [x] `swift test --filter YAMLStorage` で通過確認（テストファイル名に応じてフィルタ調整）

Phase Complete

---

## Refactor Phase: 品質改善

- [x] yaml 文字列を定数化
- [x] 境界値テスト（1, 2, 境界外）のマトリクスを table-driven に整理
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 2
- Blocks: 100
