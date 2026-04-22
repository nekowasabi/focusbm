# focusbm Lessons Index

プロジェクトで得た教訓の見出しインデックス。詳細は `.serena/memories/` および個別 `stigmergy/*.md` を参照。

## 2026-04-22 ミッション（process-04〜12）
ミッションログ: `stigmergy/mission-2026-04-22-process-04-12.md`

| ID | 見出し | 保存先 |
|----|--------|--------|
| L1 | worktree strict で同一ファイル編集は直列化（COP 部分適用プロトコル） | `.serena/memories/focusbm-worktree-strict-same-file-serialization` |
| L2 | SourceKit LSP main-cache 誤検知は `swift build` を primary truth に | `.serena/memories/focusbm-sourcekit-lsp-main-cache-diagnostics` |
| L3 | Swift Testing + internal(set) + @testable import の 3 点セット（既存パターン踏襲） | `.serena/memories/swift-test-injection-patterns` |
| L4 | --min-cycles 2 は Wave 分割で自然充足（実装層 → テスト層） | `.serena/memories/focusbm-process-04-12-implementation-lessons` |
| L5 | doctrine-executor-heavy + worktree 隔離の DAG 並列化 | `.serena/memories/focusbm-process-04-12-implementation-lessons` |
| L6 | plan/*.md WIP の path-scoped stash 保護フロー | `.serena/memories/focusbm-process-04-12-implementation-lessons` |

## 2026-04-22 以前（process-01〜03）
| ID | 見出し | 保存先 |
|----|--------|--------|
| P1 | worktree merge 衝突の path-scoped stash 対策 | `.serena/memories/focusbm-worktree-ooda-patterns` |
| P2 | micro-exec strict DAG の部分適用プロトコル | `.serena/memories/focusbm-worktree-ooda-patterns` |
| P3 | SourceKit LSP の worktree 盲点 | `.serena/memories/swift-test-injection-patterns` |
| P4 | Red phase のログ明示確認強制 | `.serena/memories/swift-test-injection-patterns` |
| P5 | internal(set) + @testable import | `.serena/memories/swift-test-injection-patterns` |
| P6 | process 単位 --no-ff merge | `.serena/memories/focusbm-worktree-ooda-patterns` |
| P7 | tmux window index 実測 | `.serena/memories/focusbm-worktree-ooda-patterns` |
| P8 | Bash hook "FAILED" 誤検知クロスチェック | `.serena/memories/ooda-mission-2026-04-22` |
| P9 | process-per-worktree 優先 | `.serena/memories/focusbm-worktree-ooda-patterns` |
| P10| helper static func の internal 公開 | `.serena/memories/swift-test-injection-patterns` |

## その他プロジェクト教訓
| 見出し | 保存先 |
|--------|--------|
| focusbm アーキテクチャ概観 | `stigmergy/focusbm-architecture.md` |
| SearchPanel パフォーマンス最適化 | `stigmergy/searchpanel-perf-optimization.md` |
