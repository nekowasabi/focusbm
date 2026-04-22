# Process 2: YAMLStorage マイグレーションと不正値フォールバック

## Overview
`bookmarks.yml` から `bookmarkListColumns` を読み込む際、未指定・不正値（0、3以上、文字列等）を安全に nil にフォールバックし、旧 yml との互換性を担保する。

## Affected Files
- `Sources/FocusBMLib/YAMLStorage.swift:20-42` — `loadYAML()` もしくは `migrateV1YAML()` に正規化処理を追加
- 必要に応じて `Sources/FocusBMLib/Models.swift` の decode カスタマイズ

## Implementation Notes
- Yams の `YAMLDecoder` が未指定キーを自動的に nil にするため、主要ケースは既存挙動で通過
- 明示的に不正値（例: `bookmarkListColumns: 0` / `3` / `"two"`）は nil に正規化するため、`init(from decoder:)` で範囲チェック（許可: nil, 1, 2）
- 許可外の値は WARN ログ（`os_log` もしくは既存ログ経路）に残して nil 扱い
- encode 時は nil なら出力省略（現行 encode 挙動に揃える）
- マイグレーションスキーマに version フィールドがある場合でも新規追加キーは不要（Optional のため）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - Process 12 の migration テスト（旧 yml 読み込み・不正値フォールバック）を先行実装
- [x] テストを実行して失敗することを確認

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] `AppSettings.init(from:)` で `bookmarkListColumns` を decode し、値が {1,2} 以外なら nil に正規化
- [x] 不正値検出時のログ出力（既存ログ経路に合わせる）
- [x] `swift test` で migration テストが通ることを確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] 正規化ロジックを `AppSettings.normalizedColumns` のような private helper に切り出し
- [x] 将来 3 列対応する場合の拡張ポイントをコメントで明記（Why コメント）
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 1
- Blocks: 3, 4, 5, 6, 12
