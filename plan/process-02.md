# Process 2: Node.jsベースAIツールのtmux検出強化

## Overview
tmux ペイン内で実行中の codex（Node.jsベース）が `pane_current_command = "node"` として報告されるため、`isAIAgent` 判定に失敗し、AIエージェントとして検出されない問題を修正する。

## Affected Files
- `Sources/FocusBMLib/TmuxProvider.swift`:
  - L46-62: `isAIAgent` computed property — "node" コマンド時の追加判定ロジック
  - L112-126: `agentName` — "node" 経由で検出されたエージェントの名前解決
  - L248-302: `listAllPanes()` — ペイン情報取得時にプロセス引数を補完
- `Tests/focusbmTests/TmuxProviderTests.swift`:
  - Node.js経由のAIエージェント検出テスト追加

## Implementation Notes

### 根本原因
tmux の `pane_current_command` は実行バイナリ名を返す。Node.jsベースのCLI（codex等）は実際には `node /path/to/codex` として実行されるため、tmux は "node" としか報告しない。

codex の実際のペイン情報:
```
pane_current_command: "node"      ← "codex" ではない
pane_title: "tmux-ai-agents-status"  ← "codex" を含まない
```

### 修正アプローチ

**案A: ペインPIDからプロセス引数を取得** ⭐⭐⭐⭐⭐ (推奨)
tmux の `pane_pid` でペイン内のシェルPIDを取得し、その子プロセスのコマンドライン引数を `ps` で確認する。

```swift
// isAIAgent 内:
// Why: Node.jsベースCLIは pane_current_command が "node" になるため、
//      プロセスの引数から実際のAIツール名を判定する必要がある
if command == "node" || command == "deno" || command == "bun" {
    return resolveNodeAgentCommand() != nil
}
```

**resolveNodeAgentCommand() の実装:**
```swift
// Why: pane_pid の子プロセスのコマンドラインから bin/{agent} パターンを検索
private func resolveNodeAgentCommand() -> String? {
    // 1. pane_pid を取得（tmux list-panes で #{pane_pid} を含める必要あり）
    // 2. ps -o args= -p <child_pid> でコマンドライン取得
    // 3. aiAgentCommands とマッチング
    // 4. マッチしたコマンド名を返す
}
```

**案B: listAllPanes() で pane_pid を取得し事前解決** ⭐⭐⭐⭐
`tmux list-panes` のフォーマット文字列に `#{pane_pid}` を追加し、TmuxPane 構造体に格納。
`isAIAgent` 判定時にこのPIDを使ってプロセス引数を確認。

### listAllPanes のフォーマット変更
現在の tmux list-panes フォーマット文字列を確認し、`#{pane_pid}` を追加する必要がある。

### agentName の対応
`command == "node"` の場合、`resolveNodeAgentCommand()` の結果を使って agentName を返す:
```swift
case "node", "deno", "bun":
    if let resolved = resolveNodeAgentCommand() {
        switch resolved {
        case "codex": return "Codex"
        case "copilot": return "Copilot"
        default: return resolved.capitalized
        }
    }
    return command
```

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - command="node", 子プロセスが "codex" → isAIAgent == true
  - command="node", 子プロセスが "codex" → agentName == "Codex"
  - command="node", 子プロセスが一般的なnodeアプリ → isAIAgent == false
  - command="node", 子プロセス情報取得失敗 → isAIAgent == false（安全側）
- [x] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] TmuxPane に `panePid` プロパティを追加
- [x] `listAllPanes()` のフォーマット文字列に `#{pane_pid}` を追加
- [x] `resolveNodeAgentCommand()` メソッドを実装
- [x] `isAIAgent` に "node"/"deno"/"bun" 判定を追加
- [x] `agentName` に node 経由の名前解決を追加
- [x] ビルドが通ることを確認 (`swift build`)
- [x] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] resolveNodeAgentCommand() の結果キャッシュを検討（ps 呼び出し削減）
- [x] Why コメントが適切に記載されていることを確認
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: Process 10
