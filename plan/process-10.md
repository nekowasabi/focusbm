# Process 10: AppSettingsTests 拡張（round-trip 6ケース）

## Overview
`Tests/focusbmTests/AppSettingsTests.swift` に `bookmarkListColumns` の YAML round-trip テストを 6 ケース追加する。既定・明示値・不正値・未指定の境界を網羅する。

## Affected Files
- `Tests/focusbmTests/AppSettingsTests.swift` — 以下テスト関数追加:
  - `test_bookmarkListColumns_default_isNil`
  - `test_bookmarkListColumns_fromYAML_is2`
  - `test_bookmarkListColumns_roundTrip_nil`
  - `test_bookmarkListColumns_roundTrip_1`
  - `test_bookmarkListColumns_roundTrip_2`
  - `test_bookmarkListColumns_invalid_3_decodesAsNil`

## Implementation Notes
- 既存テストは Swift Testing (`@Test` マクロ) 使用。新規も同形式で統一
- YAML サンプルは文字列リテラルで直接記述:
  ```swift
  let yaml = """
  bookmarkListColumns: 2
  """
  ```
- `YAMLDecoder().decode(AppSettings.self, from: yaml)` でデコード検証
- round-trip は encode → decode で値保持を確認
- `invalid_3_decodesAsNil` は Process 2 の正規化ロジックが効くことを検証（3 → nil）
- 不正値ケース追加: 0、負値、文字列（Swift 側で型不整合が発生するケースは decode エラーの期待値をチェック）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - 上記6関数を追加し、Process 1/2 実装前の状態でコンパイルエラーまたは Red を確認
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 1/2 完了後に全6ケースが Green になることを確認
- [x] `swift test --filter AppSettingsTests` で通過確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] テストヘルパー（yaml 文字列生成）を private func に抽出
- [x] 命名規則を既存テストと整合（`test_<対象>_<条件>_<期待>`）
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 1, 2
- Blocks: 100
