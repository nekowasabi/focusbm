---
title: "絞り込みウィンドウ close 時のフォーカス復元"
status: planning
created: "2026-04-10"
---

# Commander's Intent

## Purpose
絞り込みウィンドウ（SearchPanel）をEscapeキー・cancelOperation・ホットキートグルで閉じた際、直前にアクティブだったアプリケーションへフォーカスが復帰しない問題を修正する。

## End State
SearchPanel の全 close path で、パネル表示前にアクティブだったアプリケーションへフォーカスが自動復帰する状態。

## Key Tasks
- SearchPanel.makeKeyAndOrderFront() で直前のアクティブアプリをキャプチャ
- SearchPanel.close() override でフォーカス復元処理を追加
- OK paths（アイテム選択系）との二重 activate 安全性を確保

## Constraints
- 変更は SearchPanel.swift のみ（~10行）
- OK paths（P4-P8: onSubmit/tap/shortcutBar/activateItem/autoExecute）の既存動作を変更しない
- macOS 13.0+ 互換
- LSUIElement=true (accessory activation policy) 環境で動作すること

---

# Progress Map

| Process | Title | Status | File |
|---------|-------|--------|------|
| 1 | SearchPanel フォーカス復元機構追加 | ☐ planning | [→ plan/process-01.md](plan/process-01.md) |
| 10 | フォーカス復元テスト | ☐ planning | [→ plan/process-10.md](plan/process-10.md) |
| 300 | OODA レビュー | ☐ planning | [→ plan/process-300.md](plan/process-300.md) |

**DAG**: `1→10` | `300`
**DAG凡例**: `{A,B}` = 並列実行可能、`A→B` = A完了後にB実行、`|` = 独立した依存チェーン
**Overall**: ☐ 0/3 completed

---

# Investigation Summary (mission-20260410-065419)

OODA 2サイクルによる挙動調査の結果。詳細は各 process ファイルおよび `~/.claude/stigmergy/artifacts/mission-20260410-065419/` を参照。

**根本原因**: `toggleSearchPanel()` (FocusBMApp.swift:266) で `NSApp.activate(ignoringOtherApps: true)` によりFocusBMがフォーカスを奪取するが、`close()` override (SearchPanel.swift:64-67) にフォーカス返却処理がない。8つの close path のうち3つ（P1 Escape / P2 cancelOperation / P3 hotkey toggle）がバグ。

**推奨修正**: Strategy A（改） ★★★★★ — SearchPanel.swift のみ ~10行変更。makeKeyAndOrderFront() でキャプチャ、close() で復元。

---

# References

| @ref | @target | @test |
|------|---------|-------|
| SearchPanel.swift | close() (L64-67), makeKeyAndOrderFront() (L58-62), cancelOperation (L54), activateItem (L89-93), Escape (L141-142) | Tests/FocusBMAppTests/ |
| FocusBMApp.swift | toggleSearchPanel() (L254-272), NSApp.activate (L266) | - |
| SearchView.swift | onSubmit (L22), onTapGesture (L68), ShortcutBar (L113) | - |
| ActivationTarget.swift | activate() (L15-28) | Tests/focusbmTests/ |

---

# Risks

| リスク | 対策 |
|--------|------|
| OK paths で二重 activate が発生 | DispatchQueue.main.async による run-loop 分離で target.activate() が後勝ち — 安全性確認済 |
| 前アプリが終了済み | NSRunningApplication.activate() は静かに失敗 — クラッシュなし |
| rapid open/close で previousApp が stale | makeKeyAndOrderFront() で毎回上書きされるため問題なし |
| macOS 14+ で activate(options:) deprecated | activate() 引数なし版を使用（deprecated ではない） |
