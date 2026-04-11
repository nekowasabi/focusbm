# Process 10: 統合テスト

## Overview
Process 1（デーモンフィルタリング）と Process 2（Node.js検出強化）の修正が連携して正しく動作することを検証する統合テスト。

## Affected Files
- `Tests/focusbmTests/ProcessProviderTests.swift`: 統合シナリオテスト追加
- `Tests/focusbmTests/TmuxProviderTests.swift`: 統合シナリオテスト追加

## Implementation Notes

### テストシナリオ

1. **codex app-server がリストに表示されない**
   - pgrep で codex app-server PID が返される状況をシミュレート
   - listNonTmuxAIProcesses() の結果に含まれないことを確認

2. **tmux内 codex (node経由) が正しく検出される**
   - pane_current_command="node", 子プロセスが codex のペインを構築
   - isAIAgent == true, agentName == "Codex" を確認
   - agentEmoji == "📖" を確認（先行コミットの絵文字マッピング）

3. **既存エージェント検出が壊れていない**
   - claude, aider, gemini, copilot が従来通り検出されることを確認
   - 非AIプロセス（vim, ssh等）がフィルタリングされることを確認

4. **エッジケース**
   - node プロセスが AI ツール以外（一般的な node アプリ）→ isAIAgent == false
   - tmux 外の codex app-server → 非表示
   - tmux 内の codex → 表示（node 経由で検出）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] 上記4シナリオのテストケースを作成
- [x] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 1, 2 の実装が完了していることを前提に、テストが通ることを確認
- [x] `swift test` で全テスト通過を確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] テストの重複を整理
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1, Process 2
- Blocks: -
