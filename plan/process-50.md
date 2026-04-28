# Process 50: showAIAgentShortcut との干渉確認

## Overview
最近 commit (dbd5361, 2300f52, 35b1b3a) で追加された `showAIAgentShortcut` 設定（AIエージェント行のショートカット番号表示 ON/OFF）と、本 PR の statusEmoji 着色変更が独立に動作することを確認する。両者は責務が異なる（番号 vs 色）が、同じ AIエージェント行を扱うため、デグレ防止のための回帰テストを行う。

## Affected Files
- `Tests/FocusBMAppTests/SearchViewModelOrderingTests.swift` - 既存テスト確認（修正なし想定）
- `Sources/FocusBMApp/SearchViewModel.swift:224-306` - shortcutAssignments / labelToIndex（参照のみ、修正なし）
- `Sources/FocusBMApp/BookmarkRow.swift` - Process 3 の着色変更が showAIAgentShortcut の表示分岐に影響しないことを確認

## Implementation Notes
- 確認観点:
  1. showAIAgentShortcut = true: ショートカット番号 + 着色 statusEmoji が同時表示される
  2. showAIAgentShortcut = false: ショートカット番号は非表示、着色 statusEmoji のみ表示される
  3. labelToIndex のソート順が着色変更で破壊されない
- 既存テスト `SearchViewModelOrderingTests` を実行し、Green 維持を確認
- 設定の組合せパターンを手動 UI で 2 ケース確認

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] showAIAgentShortcut 関連の既存テストを把握
- [x] 必要に応じて「着色 + ショートカット番号」の同時表示テストを追加
- [x] テスト実行（既存テストは Green のまま、新規テストのみ Red）

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 3 完了後にテスト実行
- [x] 既存テスト全 Green
- [x] 手動 UI 確認 (showAIAgentShortcut の ON/OFF 切替 × statusEmoji 着色)

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] 干渉確認テストの自動化検討
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: 3
- Blocks: 100
