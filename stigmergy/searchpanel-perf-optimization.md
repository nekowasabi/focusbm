# SearchPanel 表示高速化 知見 (2026-03-03)

## 問題
ホットキー押下からパネル表示まで2秒以上。`toggleSearchPanel()` が `makeKeyAndOrderFront()` の前に `refreshForPanel()` を同期実行し、プロセス検出（pgrep/ps/lsof を最大27回 spawn）が完了するまでパネルが表示されなかった。

## 解決アプローチ（6 Phase）

### Phase 1: パネル即時表示 + 非同期データ更新
- `makeKeyAndOrderFront()` を先に呼び、空パネルを即時表示
- `refreshForPanelAsync()` でバックグラウンドスレッドからデータ取得
- `refreshGeneration` カウンタでホットキー連打時のレースコンディション防止
- `NSWorkspace.shared.runningApplications` はメインスレッド制約あり → バックグラウンド投入前にスナップショット取得

### Phase 2: デバッグログ削除
- `enableDebugLog` + FileHandle I/O が毎回 open/seek/write/close + ISO8601DateFormatter 生成
- "remove after investigation" コメント付きは速やかに削除すべき

### Phase 3: YAML 3重読み込みの統合
- `toggleSearchPanel()` 内で `BookmarkStore.loadYAML()` が3回呼ばれていた
- `setupSearchPanel()` で1回だけパースしてキャッシュ、`reloadBookmarks()` でキャッシュ更新

### Phase 4: isProcessInTmux の sysctl 化
- `ps -p <pid> -o comm=` を最大20回 spawn → `sysctl(KERN_PROC_PID)` + `kp_proc.p_comm` に置換
- `MAXCOMM` 定数は Swift から不可視 → `MemoryLayout.size(ofValue: info.kp_proc.p_comm)` で代替
- メモ化キャッシュ (`pid -> Bool`) で同一リフレッシュサイクル内の重複走査を回避

### Phase 5: getWorkingDirectory の proc_pidinfo 化
- `lsof -p <pid> -d cwd` (100-300ms) → `proc_pidinfo(PROC_PIDVNODEPATHINFO)` (~1ms)
- `proc_vnodepathinfo.pvi_cdir.vip_path` から CWD 取得
- `proc_pidinfo` 失敗時は lsof にフォールバック（安全策）

### Phase 6: バックグラウンド定期キャッシュ
- 15秒間隔で tmux/process 情報をプリウォーム
- AX API（floating windows）は負荷が高いため対象外
- `screensDidSleepNotification` でスリープ時は自動停止

## 実装パターン

### refreshGeneration パターン（レースコンディション防止）
```swift
refreshGeneration += 1
let generation = refreshGeneration
DispatchQueue.global().async {
    let result = heavyWork()
    DispatchQueue.main.async {
        guard generation == self.refreshGeneration else { return }
        self.applyResult(result)
    }
}
```

### sysctl でプロセス情報取得
- `sysctlParentPID()`: `kp_eproc.e_ppid` で親PID
- `sysctlProcessName()`: `kp_proc.p_comm` でプロセス名（16文字制限、"tmux" は4文字で問題なし）
- `proc_pidinfo(PROC_PIDVNODEPATHINFO)`: CWD 取得（Darwin API、~1ms）

## パフォーマンス結果
| メトリクス | Before | After |
|-----------|--------|-------|
| パネル表示 | ~2秒 | < 50ms |
| isProcessInTmux | ps×20 (~1000ms) | sysctl×20 (~0.2ms) |
| getWorkingDirectory | lsof (~200ms) | proc_pidinfo (~1ms) |

## 並列実装の知見
- Phase 1-3 (FocusBMApp.swift + SearchViewModel.swift) と Phase 4-5 (ProcessProvider.swift + TmuxProvider.swift) はファイル重複なしで完全並列実行可能だった
- Multi-LLM 合議（Claude 3エージェント + Codex）で事前に施策の妥当性を確認し、実装フェーズでの手戻りゼロ
