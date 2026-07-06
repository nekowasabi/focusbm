# スリープ復帰後に AI エージェント一覧が空になる問題

## 層別分析

| 層 | 観測 / 原因 | 信頼度 |
|---|---|---|
| UI 操作層 | `cmd+ctrl+b` で検索パネル自体は開くため、パネル表示やホットキー全体の故障ではない。 | 高 |
| プロセス取得層 | `ProcessProvider.listNonTmuxAIProcesses()` はスキャン時に tmux 外の AI エージェント候補を再取得する。強制リロードはこの既存経路を再利用できる。 | 高 |
| ターミナル解決層 | `TmuxProvider.findTerminalAppForTTY()` が `NSWorkspace.shared.runningApplications` に依存するため、復帰直後にターミナルアプリの突合が失敗しうる。 | 高 |
| 復元可能性判定層 | `terminalBundleId` が解決できない候補は復元不能として除外され、結果として一覧が空になる。 | 高 |
| 時間依存層 | 数秒から十数秒後に `NSWorkspace` 側の状態が回復すると、同じスキャン経路で再表示できる。恒久的なデータ欠損ではなく一時的な可視性不整合である。 | 中 |
| バックグラウンド更新層 | 復帰通知直後の自動更新が空結果をキャッシュすると、ユーザーが見る一覧も空になりやすい。即時更新を少し遅らせると発生確率を下げられる。 | 中 |

## 対策方針

1. 主対策: `forceReloadAgents` ホットキーを追加する。
   - 既定値は `cmd+ctrl+r`。
   - パネル表示中は `SearchViewModel.refreshForPanelAsync()` を直接実行する。
   - パネル非表示時は既存の `toggleSearchPanel()` 経路を使い、表示と再スキャンを同時に行う。
   - 信頼度: 高。

2. 設定互換: `HotkeySettings.forceReloadAgents` は `decodeIfPresent` で読む。
   - 既存 YAML が `togglePanel` だけでも `cmd+ctrl+r` にフォールバックする。
   - 合成デコードで `keyNotFound` にする実装は採用しない。
   - 信頼度: 高。

3. 補助対策: wake 通知直後の `BackgroundRefreshService` 更新を約 2 秒遅延する。
   - `NSWorkspace.runningApplications` の復帰待ちを目的にする。
   - `findTerminalAppForTTY()` 本体にリトライを入れず、ホットパスの負荷増を避ける。
   - 信頼度: 中。

4. 検証方針:
   - `swift test` で設定デコード、ホットキー解析、既存 YAML 移行の回帰を確認する。
   - 手動確認では、スリープ復帰後に一覧が空になった状態で `cmd+ctrl+r` を押し、数秒後に再表示されることを確認する。
   - 信頼度: 中。

