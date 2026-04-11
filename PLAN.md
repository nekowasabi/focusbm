---
title: "非Tmux AIプロセス検出のバグ修正"
status: done
created: "2026-04-11"
---

# Commander's Intent

## Purpose
codex app-server のゴースト表示（バグ7）と、tmux内Node.jsベースAIツールの検出漏れ（バグ8）を修正する。

## End State
- デーモン/サーバープロセス（codex app-server等）がAIエージェントリストに表示されない
- tmux内のNode.jsベースAIツール（codex等）がAIエージェントとして正しく検出・表示される

## Key Tasks
- pgrep結果からデーモン/サーバープロセスをフィルタリング
- tmuxペインのisAIAgent判定でNode.jsコマンドのプロセス引数を確認
- 両修正のユニット・統合テスト

## Constraints
- 変更は ProcessProvider.swift と TmuxProvider.swift の2ファイル（+ テスト）
- 既存のAIエージェント検出（claude, aider, gemini, copilot）を壊さない
- pgrep / ps コマンドの実行コストを最小限に抑える

---

# Progress Map

| Process | Title | Status | File |
|---------|-------|--------|------|
| 1 | デーモンプロセスのフィルタリング | ✅ done | [→ plan/process-01.md](plan/process-01.md) |
| 2 | Node.jsベースAIツールのtmux検出強化 | ✅ done | [→ plan/process-02.md](plan/process-02.md) |
| 10 | 統合テスト | ✅ done | [→ plan/process-10.md](plan/process-10.md) |
| 300 | OODA レビュー | ✅ done | [→ plan/process-300.md](plan/process-300.md) |

**DAG**: `{1,2}→10 | 300`
**DAG凡例**: `{A,B}` = 並列実行可能、`A→B` = A完了後にB実行、`|` = 独立した依存チェーン
**Overall**: ✅ 4/4 completed

---

# References

| @ref | @target | @test |
|------|---------|-------|
| ProcessProvider.swift | findProcessesByName() (L98-110), listNonTmuxAIProcesses() (L56-93), aiAgentCommands (L38) | Tests/focusbmTests/ProcessProviderTests.swift |
| TmuxProvider.swift | isAIAgent (L46-62), agentName (L112-126), listAllPanes() (L248-302) | Tests/focusbmTests/TmuxProviderTests.swift |

---

# Risks

| リスク | 対策 |
|--------|------|
| pgrep パターン変更で正規のcodexプロセスを除外してしまう | サブコマンド（app-server）のみを除外し、引数なし/通常引数は許可 |
| ps コマンド追加実行によるパフォーマンス低下 | node コマンドのペインのみに限定し、キャッシュ活用 |
| 他のNode.jsベースCLI（将来追加）で同じ問題が再発 | node 判定を汎用的に設計し、aiAgentCommands との照合で拡張可能にする |
