# Process 1: AppSettings に bookmarkListColumns フィールド追加

## Overview
`bookmarks.yml` 経由で絞り込み画面の列数をユーザー設定可能にする基礎として、`AppSettings` 構造体に `bookmarkListColumns: Int?` を追加する。既存設定との互換を壊さないよう Optional で導入する。

## Affected Files
- `Sources/FocusBMLib/Models.swift:108-154` — `AppSettings` 構造体に `bookmarkListColumns: Int?` プロパティを追加
- `Sources/FocusBMLib/Models.swift`（`CodingKeys` 定義があれば同期）

## Implementation Notes
- 既存の `listFontSize: Double?`, `showTmuxAgents: Bool?`, `directNumberKeys: Bool?` と同じ Optional パターンに倣う
- デフォルト値は nil（未設定時は1列として扱われることを後続 Process 3 の VM 層で保証）
- `Codable` + `Equatable` conformance を維持
- init(...) に引数追加する場合、既存呼び出し箇所（テスト含む）のデフォルト値を nil に

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - Process 10 で追加する `test_bookmarkListColumns_default_isNil` を先行実装しコンパイル失敗を確認
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] `AppSettings` に `public var bookmarkListColumns: Int?` を追加
- [x] CodingKeys に同期（明示的に定義されている場合のみ）
- [x] 既存 init の呼び出し側を壊さないため引数はデフォルト nil
- [x] `swift build` でコンパイル通過確認
- [x] テストを実行して成功することを確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] プロパティ順序を既存の「表示系」グループに整列
- [x] ドキュメントコメントで「1=縦1列(既定) / 2=横2列 / その他=nil 扱い」を明記
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: -
- Blocks: 2, 3, 10
