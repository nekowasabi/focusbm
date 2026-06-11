# focusbm Lessons Index

プロジェクトで得た教訓の見出しインデックス。詳細は `.serena/memories/` および個別 `stigmergy/*.md` を参照。

## 2026-06-11 ミッション（リファクタリング計画フェーズ: 20260611-120143-29486-001）
ミッション: 全体リファクタリング計画（PLAN.md策定、Phase0先行調査、310テスト全green確認）
詳細ファイル: `stigmergy/lessons-20260611-refactor-planning.md`

### cycle 1 教訓

| ID | 見出し | 重要度 | 保存先 |
|----|--------|--------|--------|
| L-A | 計画書の定量数値は必ず grep 実測で確定せよ | high | `.serena/memories/focusbm-refactor-planning-lessons` |
| L-B | 同一制約値は define once, reference many（Markdown でも） | medium | `.serena/memories/focusbm-refactor-planning-lessons` |
| L-C | 双方向循環依存は「逆方向依存」と区別して記録せよ | high | `.serena/memories/focusbm-refactor-planning-lessons` |
| L-D | I/O 呼出点はファイル数でなく呼出サイト数で計上せよ | medium | `.serena/memories/focusbm-refactor-planning-lessons` |
| L-E | テストベースラインは実装者以外が独立実行して確定せよ | high | `.serena/memories/focusbm-refactor-planning-lessons` |

### cycle 2 教訓（新規追加: 2026-06-11）

| ID | 見出し | 重要度 | 保存先 |
|----|--------|--------|--------|
| L-C2-1 | 指示間矛盾はオーケストレータが仲裁し、実行後に追認記録を残せ | high | `stigmergy/lessons-20260611-refactor-planning.md` |
| L-C2-2 | supervisor の FAIL 報告は executor 完了後タイムスタンプと照合してから採否判定せよ | high | `stigmergy/lessons-20260611-refactor-planning.md` |
| L-C2-3 | 証跡ファイルの末尾切断は申し送りの最後に明示せよ | medium | `stigmergy/lessons-20260611-refactor-planning.md` |
| L-C2-4 | PLAN.md 内の同一型定数は PhaseID と行番号をペアで記載せよ | medium | `stigmergy/lessons-20260611-refactor-planning.md` |

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
