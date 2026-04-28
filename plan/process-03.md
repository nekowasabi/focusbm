# Process 3: BookmarkRow で statusEmoji を分離着色描画

## Overview
BookmarkRow.swift で `Text(searchItem.displayName)` を単一 Text として描画している箇所を、AIエージェント行（agentDisplay が non-nil）の場合のみ HStack で statusEmoji を別 Text に分離し、`isRunning ? .green : .red` で着色する。displayName 本体（emoji を除いた部分）は通常色のまま。

## Affected Files
- `Sources/FocusBMApp/BookmarkRow.swift:68-74` - `Text(searchItem.displayName)` の描画箇所
- 既存の HStack / Spacer 構造を維持し、Text 部分のみ条件分岐

## Implementation Notes
- 描画ロジック:
  ```swift
  if let agent = searchItem.agentDisplay {
      HStack(spacing: 4) {
          Text(agent.emoji)
              .foregroundColor(agent.isRunning ? .green : .red)
              .fontWeight(.bold)  // オプション: 視認性向上
          Text(agent.nameWithoutEmoji)
      }
  } else {
      Text(searchItem.displayName)
  }
  ```
- showAIAgentShortcut 設定との干渉なし（ショートカット番号は別カラム）
- 選択時背景色は SearchView 側で適用済みのため変更不要
- ダークモード対応: Color.green / .red は SwiftUI 標準で自動切替

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成
  - 手動 UI 確認: 処理中の AI エージェント行で ● が緑色で表示
  - 手動 UI 確認: idle / planMode / acceptEdits の AI エージェント行で ○ が赤色で表示
  - 通常の bookmark 行は装飾なしで displayName 表示
  - showAIAgentShortcut = false でも色分けが正しく動作
- [x] テストを実行して失敗することを確認（既存 snapshot との差分）

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] BookmarkRow.swift で agentDisplay 分岐実装
- [x] HStack で emoji と nameWithoutEmoji を並列描画
- [x] foregroundColor を isRunning で切替
- [x] テストを実行して成功することを確認
- [x] swift run focusbm でアプリ起動し手動確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] HStack spacing / fontWeight の調整
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: 1, 2
- Blocks: 12, 50, 200
