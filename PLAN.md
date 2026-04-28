---
title: "AIエージェント行の動作状態を色分け表示"
status: planning
created: "2026-04-28"
---

# Commander's Intent

## Purpose
SearchPanel の AIエージェント行で動作状態（statusEmoji ○/●）が文字列に埋め込まれているため視認性が低い。View 層で別 Text として描画し、処理中=緑●、それ以外=赤○ で色分けすることでユーザーが agent の実行状況を一目で識別できるようにする。

## End State
BookmarkRow が AIエージェント行の場合、HStack 内で statusEmoji を別 Text として `.foregroundColor` 付きで描画し、displayName 本体（statusEmoji を除いた agentName + path）を後ろに並べる。FocusBMLib は SwiftUI 非依存を維持し、Color マッピングは App 層で行う。全テスト Green。

## Key Tasks
- TmuxPane に statusEmoji / displayNameWithoutEmoji を分離公開（既存 displayName 契約は維持）
- SearchItem に AIエージェント行を識別する判別経路を確保（既存 isAIAgent / case 分岐を活用）
- BookmarkRow で `.tmuxPane` 分岐 → statusEmoji を着色 Text として描画

## Constraints
- FocusBMLib は SwiftUI/Color に非依存を維持（Color enum を Lib 層に持ち込まない）
- TmuxPane.displayName の既存文字列契約（statusEmoji を含む）は変更しない（後方互換）
- showAIAgentShortcut 設定との独立性を維持（ショートカット番号表示は影響なし）
- agentStatus の 4 状態（running / planMode / acceptEdits / idle）のうち、running のみ「処理中=緑●」、それ以外は「赤○」に二値化

---

# Progress Map

| Process | Title | Status | File |
|---------|-------|--------|------|
| 1 | TmuxPane に displayNameWithoutEmoji 追加 | ✅ completed | [→ plan/process-01.md](plan/process-01.md) |
| 2 | SearchItem に agentDisplay 計算プロパティ追加 | ✅ completed | [→ plan/process-02.md](plan/process-02.md) |
| 3 | BookmarkRow で statusEmoji を分離着色描画 | ✅ completed | [→ plan/process-03.md](plan/process-03.md) |
| 10 | TmuxPane プロパティ分離テスト | ✅ completed | [→ plan/process-10.md](plan/process-10.md) |
| 11 | SearchItem.agentDisplay テスト | ✅ completed | [→ plan/process-11.md](plan/process-11.md) |
| 12 | BookmarkRow 着色描画テスト | ✅ completed | [→ plan/process-12.md](plan/process-12.md) |
| 50 | showAIAgentShortcut との干渉確認 | ✅ completed | [→ plan/process-50.md](plan/process-50.md) |
| 100 | 全テスト Green 確認（swift test） | ✅ completed | [→ plan/process-100.md](plan/process-100.md) |
| 200 | ドキュメント更新（README/DESIGN） | ☐ planning | [→ plan/process-200.md](plan/process-200.md) |
| 300 | OODA 振り返り（設計決定の記録） | ☐ planning | [→ plan/process-300.md](plan/process-300.md) |

**DAG**: `{1,2}→3→{10,11,12,50}→100→200→300`
**DAG凡例**: `{A,B}` = 並列実行可能、`A→B` = A完了後にB実行、`|` = 独立した依存チェーン
**Overall**: ☑ 8/10 completed

---

# References

| @ref | @target | @test |
|------|---------|-------|
| Sources/FocusBMLib/TmuxProvider.swift:107-158 | TmuxPane.agentStatus / statusEmoji / displayName | Tests/focusbmTests/TmuxProviderTests.swift |
| Sources/FocusBMLib/Models.swift:304-313 | SearchItem.displayName / .tmuxPane ケース | Tests/focusbmTests/ModelsTests.swift |
| Sources/FocusBMApp/BookmarkRow.swift:68-74 | Text(searchItem.displayName) 描画箇所 | Tests/FocusBMAppTests/BookmarkRowTests.swift（新規候補） |
| Sources/FocusBMApp/SearchView.swift:50-122 | リスト描画と選択時背景 | - |

---

# Risks

| リスク | 対策 |
|--------|------|
| TmuxPane.displayName の既存契約変更による破壊 | displayName 自体は不変。新プロパティ displayNameWithoutEmoji を追加する非破壊変更で対応。既存テストの期待値も維持。 |
| Color が FocusBMLib に漏れる | TmuxAgentStatus enum を Lib に置き、Color マッピングは App 層 (BookmarkRow) で計算。SwiftUI import を Lib に追加しない。 |
| ダークモード/アクセシビリティでの視認性不足 | Color.green / .red の代わりに、ダークモード対応の semantic color（必要なら Asset Catalog）を採用検討。ただし初版は標準 Color でリリースし、Process 200 で評価。 |
