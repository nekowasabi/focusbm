# Process 2: SearchItem に agentDisplay 計算プロパティ追加

## Overview
SearchItem enum の `.tmuxPane` ケースから AIエージェント行の表示用情報を取り出す統合プロパティを追加する。BookmarkRow が `if case .tmuxPane(let pane)` 分岐を毎回書かずに済むようにし、Color マッピングは持たない（FocusBMLib は SwiftUI 非依存を維持）。

## Affected Files
- `Sources/FocusBMLib/Models.swift:304-313` - SearchItem.displayName 周辺に新プロパティ追加
- `Sources/FocusBMLib/Models.swift` - 新 struct `AgentDisplay` を定義（同ファイル内）

## Implementation Notes
- 新 struct を定義:
  ```
  public struct AgentDisplay: Equatable {
      public let emoji: String         // pane.statusEmoji
      public let isRunning: Bool       // pane.agentStatus == .running
      public let nameWithoutEmoji: String  // pane.displayNameWithoutEmoji
  }
  ```
- SearchItem に `public var agentDisplay: AgentDisplay?` を追加
  - `.tmuxPane(let pane)` の場合のみ非 nil を返す
  - 他ケースは nil
- Color を含めない（App 層でマッピング）
- TmuxAgentStatus enum は既存のまま流用（Lib 層で完結）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成
  - `.tmuxPane` の SearchItem で agentDisplay が non-nil
  - emoji が statusEmoji と一致
  - isRunning が agentStatus == .running と一致
  - nameWithoutEmoji が displayNameWithoutEmoji と一致
  - 他ケース（`.bookmark` 等）で agentDisplay が nil
- [x] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] AgentDisplay struct を Models.swift に定義
- [x] SearchItem.agentDisplay 計算プロパティを実装
- [x] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] AgentDisplay の Equatable 準拠を確認
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: 1
- Blocks: 3, 11
