# Process 1: TmuxPane に displayNameWithoutEmoji 追加

## Overview
TmuxPane の displayName が statusEmoji + agentName + path を文字列結合しているため、SwiftUI 側で部分着色できない。statusEmoji を除いた表示名を返す `displayNameWithoutEmoji` プロパティを public で追加し、既存 displayName 契約は維持する（非破壊変更）。

## Affected Files
- `Sources/FocusBMLib/TmuxProvider.swift:154-158` - `displayName` 定義の隣接箇所に新プロパティ追加
- `Sources/FocusBMLib/TmuxProvider.swift:117-124` - 既存 `statusEmoji` プロパティ（変更なし、参照のみ）

## Implementation Notes
- 既存 `displayName` は `terminalEmoji + statusEmoji + agentName + path` の構造（要確認）
- 新プロパティ `public var displayNameWithoutEmoji: String` を追加
- statusEmoji 部分のみを除いた残りの文字列を返す
- displayName と displayNameWithoutEmoji の整合性: `displayName == statusEmoji + " " + displayNameWithoutEmoji`（または既存フォーマットに準拠）
- 実装後 displayName 自体は変更せず、外部参照箇所への影響をゼロに保つ

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - `displayNameWithoutEmoji` が statusEmoji（●/○）を含まないこと
  - `displayNameWithoutEmoji` が agentName と path を含むこと
  - 既存 `displayName` の値が変更されないこと（後方互換）
- [x] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] TmuxProvider.swift に `public var displayNameWithoutEmoji: String` を追加
- [x] statusEmoji を除いた文字列を返す実装
- [x] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] displayName を `statusEmoji + " " + displayNameWithoutEmoji` の組合せに置き換え可能か検討（既存テスト維持優先で見送り可）
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: 2, 3, 10
