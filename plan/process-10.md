# Process 10: TmuxPane プロパティ分離テスト

## Overview
Process 1 で追加した `TmuxPane.displayNameWithoutEmoji` の動作を保証するためのユニットテストを追加する。既存 `displayName` の後方互換性も同時に検証する。

## Affected Files
- `Tests/focusbmTests/TmuxProviderTests.swift` - 新規テストケース追加

## Implementation Notes
- テスト観点:
  1. `displayNameWithoutEmoji` が ●/○ の statusEmoji を含まない
  2. `displayNameWithoutEmoji` が agentName を含む
  3. `displayName == statusEmoji + " " + displayNameWithoutEmoji`（または既存フォーマット準拠）
  4. agentStatus 4 状態（running / planMode / acceptEdits / idle）すべてで安定動作
- 既存 displayName テストは変更せず、後方互換性を担保
- TmuxPane のモック生成は既存テストヘルパを流用

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] 新規テスト 4 ケースを追加（上記観点）
- [x] Process 1 未実装の状態でテスト実行 → コンパイルエラー or 期待値不一致で失敗確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 1 完了後にテストを実行
- [x] 全 4 ケース Green を確認
- [x] 既存 displayName テストも引き続き Green を確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] テストヘルパの DRY 化（必要なら）
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: 1
- Blocks: 100
