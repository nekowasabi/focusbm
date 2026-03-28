---
title: "ショートカットアプリの下部横並びバー分離"
status: planning
created: "2026-03-28"
---

# Commander's Intent

## Purpose
アルファベットショートカットが割り当てられたアプリがメインリストに混在し表示枠を圧迫する問題を解消する。固定ショートカットと動的検索結果の役割分担を明確化しUXを改善する。

## End State
ショートカットアプリが絞り込みウインドウ下部に横並びバーとして表示され、メインリストには数字ショートカットと通常アイテムのみが表示される状態。

## Key Tasks
- SearchViewModel にデータ分離ロジック追加（mainListAssignments / shortcutBarItems）
- ShortcutBarView 新規作成（水平スクロール HStack + アイコン+文字バッジ）
- selectedIndex の参照先を mainListAssignments に統一

## Constraints
- ショートカットバーは query が空の時のみ表示
- 数字キー（1-9）の動作は変更しない
- アルファベットキーは selectedIndex をバイパスして直接アクティベート
- パネル高さの動的リサイズは行わない（ScrollView が吸収）

---

# Progress Map

| Process | Title | Status | File |
|---------|-------|--------|------|
| 1 | ViewModel データ分離 | ☐ planning | [→ plan/process-01.md](plan/process-01.md) |
| 2 | activate(item:) ヘルパー抽出 | ☐ planning | [→ plan/process-02.md](plan/process-02.md) |
| 3 | selectedIndex 参照先統一 | ☐ planning | [→ plan/process-03.md](plan/process-03.md) |
| 4 | ShortcutBarView 新規作成 | ☐ planning | [→ plan/process-04.md](plan/process-04.md) |
| 5 | SearchView 統合 | ☐ planning | [→ plan/process-05.md](plan/process-05.md) |
| 6 | SearchPanel キーハンドラ更新 | ☐ planning | [→ plan/process-06.md](plan/process-06.md) |
| 10 | 統合テスト | ☐ planning | [→ plan/process-10.md](plan/process-10.md) |
| 200 | README 更新 | ☐ planning | [→ plan/process-200.md](plan/process-200.md) |
| 300 | OODA レビュー | ☐ planning | [→ plan/process-300.md](plan/process-300.md) |

**Overall**: ☐ 0/9 completed

---

# References

| @ref | @target | @test |
|------|---------|-------|
| SearchViewModel.swift | shortcutAssignments (L221-257) | Tests/SearchViewModelTests.swift |
| SearchView.swift | ForEach (L43), onChange (L80-84) | - |
| SearchPanel.swift | startLocalKeyMonitor (L90-148) | - |
| BookmarkRow.swift | ZStack badge (L54-65) | - |
| Models.swift | Bookmark.shortcut, SearchItem | Tests/ |
| FocusBMApp.swift | setupSearchPanel (L244-252) | - |
| 新規: ShortcutBarView.swift | 水平ショートカットバー | 新規テスト |

---

# Risks

| リスク | 対策 |
|--------|------|
| selectedIndex のインデックスずれ | mainListAssignments.count で全 bounds check を統一、テストで網羅 |
| ショートカット0件時の表示崩れ | `if !shortcutBarItems.isEmpty` ガード |
| アクティベーション処理の重複 | Process 2 で先に activate(item:) を抽出してから分離 |
