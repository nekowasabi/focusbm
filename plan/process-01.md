# Process 1: デーモンプロセスのフィルタリング

## Overview
`pgrep -f "bin/codex"` が `codex app-server`（内部デーモン）にもマッチし、存在しないように見えるゴーストプロセスとしてリストに表示される問題を修正する。

## Affected Files
- `Sources/FocusBMLib/ProcessProvider.swift`:
  - L98-110: `findProcessesByName()` — pgrep パターンまたは結果フィルタリングを修正
  - L56-93: `listNonTmuxAIProcesses()` — フィルタリング後のプロセスリスト生成
- `Tests/focusbmTests/ProcessProviderTests.swift`:
  - デーモンプロセス除外のテストケース追加

## Implementation Notes

### 根本原因
`findProcessesByName()` の pgrep パターン `"bin/codex([[:space:]]|$)"` は以下の両方にマッチする:
- `node /opt/homebrew/bin/codex --full-auto` (正規のAIエージェント) ✅
- `node /opt/homebrew/bin/codex app-server` (内部デーモン) ❌

### 修正アプローチ候補

**案A: pgrep パターンで除外** ⭐⭐⭐⭐
pgrep に `-v` (invert) は使えないため、結果取得後にフィルタリング。

**案B: コマンドライン引数チェックで除外** ⭐⭐⭐⭐⭐ (推奨)
PID取得後に `ps -p <pid> -o args=` でコマンドライン全体を取得し、
既知のデーモンサブコマンド（`app-server`）を含むプロセスを除外する。

```swift
// Why: pgrep パターンだけではサブコマンドの除外が困難 —
//      PID取得後にコマンドライン引数で判別する方式を採用
private static let daemonSubcommands = ["app-server"]

// listNonTmuxAIProcesses() 内:
let args = getCommandLineArgs(pid)
if daemonSubcommands.contains(where: { args.contains($0) }) {
    log("  pid \(pid): skip (daemon subcommand)")
    continue
}
```

### getCommandLineArgs の実装
```swift
static func getCommandLineArgs(_ pid: pid_t) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-p", "\(pid)", "-o", "args="]
    // ... (getTTYForProcess と同パターン)
}
```

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - `codex app-server` を含むコマンドラインがフィルタリングされること
  - `codex --full-auto` を含むコマンドラインがフィルタリングされないこと
  - `codex` (引数なし) がフィルタリングされないこと
- [x] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] `daemonSubcommands` 定数を ProcessProvider に追加
- [x] `getCommandLineArgs()` メソッドを追加
- [x] `listNonTmuxAIProcesses()` にデーモンフィルタリングロジックを追加
- [x] ビルドが通ることを確認 (`swift build`)
- [x] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] Why コメントが適切に記載されていることを確認
- [x] getCommandLineArgs と getTTYForProcess の共通化を検討（DRY原則）
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: Process 10
