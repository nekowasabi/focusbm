# ゾンビプロセス非表示と手動リフレッシュ実装計画書

## 1. 目的

絞り込み画面に、フォーカス切り替え不能な `❓` 付き AI プロセス候補が残る問題を解消する。

主目的は次の二点とする。

1. 終了済み・ゾンビ化・復元不能な AI プロセスを、可能な限り検索候補に表示しない。
2. 状態が古くなった場合でも、ユーザーが `⌘R` で絞り込み画面を閉じずに手動再取得できるようにする。

## 2. 背景と現状

### 2.1 現状の動作

- tmux 外 AI プロセス候補は `ProcessProvider.listNonTmuxAIProcesses()` で取得される。
- 候補は `SearchViewModel.refreshForPanelAsync()` または `BackgroundRefreshService` 経由で `aiProcessCache` に反映される。
- `SearchItem.aiProcess` は `terminalEmoji` が `❓` の場合でも表示される。
- `SearchViewModel.restoreSelected()` と `SearchViewModel.activationTarget(for:)` は、`terminalBundleId == nil` の AI プロセスに対して `nil` を返す。

### 2.2 問題

`pgrep` で検出された PID が次の状態になっている場合、絞り込み画面に表示されても復元できない。

- すでに終了している。
- ゾンビ状態になっている。
- TTY またはターミナルアプリを特定できず、`terminalBundleId` が `nil` になる。

この結果、ユーザーから見ると `❓ claude — hq` のような候補が残り、選択してもフォーカスが切り替わらない。

## 3. 要件

### 3.1 機能要件

- `ProcessProvider.listNonTmuxAIProcesses()` は、終了済みまたはゾンビ状態の PID を候補に含めない。
- `ProcessProvider.listNonTmuxAIProcesses()` は、`terminalBundleId` を持たず復元不能な AI プロセスを候補に含めない。
- 絞り込み画面で `⌘R` を押すと、画面を閉じずに `refreshForPanelAsync()` を実行する。
- `⌘⇧R` も手動リフレッシュとして扱う。
- 手動リフレッシュは、検索文字列の有無にかかわらず発火する。
- 手動リフレッシュは、再取得後に自動フォーカス移動を発生させない。

### 3.2 非機能要件

- 既存の `⌘+数字`、矢印移動、`Escape`、アルファベットショートカットの挙動を壊さない。
- `r` と `R` の通常ショートカットは維持する。ただし `⌘R` と `⌘⇧R` は手動リフレッシュ用に予約する。
- 既存のデーモン除外ロジック（`app-server`、`mcp-server`、`--chrome-native-host`）を維持する。
- SwiftPM の既存テストを通過させる。

### 3.3 制約

- フォーカス切り替えは `terminalBundleId` を使う既存設計に従う。
- ターミナル検出が一時的に失敗したプロセスは、復元不能候補として非表示にする。
- 誤非表示の救済は `⌘R` による再取得で行う。

## 4. 設計方針

### 4.1 プロセス候補のフィルタリング

対象ファイル: `Sources/FocusBMLib/ProcessProvider.swift`

`ProcessProvider` に次の判定を追加する。

- `isProcessAlive(_:)`
  - `sysctl` で PID の存在を確認する。
  - `kp_proc.p_stat == SZOMB` の場合は false とする。
- `isRecoverableAIProcess(_:)`
  - `AIProcess.terminalBundleId != nil` の場合のみ true とする。

`listNonTmuxAIProcesses()` の候補作成フローは次の順序にする。

1. コマンド名ごとに `pgrep` で PID を取得する。
2. tmux 内プロセスを除外する。
3. PID が存在しない、またはゾンビ状態なら除外する。
4. 既知のデーモンコマンドラインを除外する。
5. TTY・作業ディレクトリ・ターミナル情報を取得する。
6. `AIProcess` を構築する。
7. 復元不能な `AIProcess` を除外する。
8. 残った候補のみ返す。

```swift
// Why: pgrep の結果だけを採用すると終了済み/ゾンビ化した PID が残り、
//      復元不能な「❓」項目として絞り込み画面に表示されるため事前に除外する。
```

### 4.2 手動リフレッシュ

対象ファイル: `Sources/FocusBMApp/SearchPanel.swift`

`SearchPanel` に `isManualRefreshShortcut(keyCode:flags:)` を追加し、ローカルキーモニタの冒頭で `⌘R` / `⌘⇧R` を処理する。

処理順は、数字キーやアルファベットショートカットより前にする。

理由:

- `⌘R` は明示的な再取得操作として優先すべきである。
- 先にアルファベットショートカットへ流すと、`shortcut: "r"` または `shortcut: "R"` と衝突する。

`alphabetShortcutLabel(keyCode:flags:)` でも `⌘R` / `⌘⇧R` は `nil` を返すようにし、通常ショートカット扱いされないことを保証する。

```swift
// Why: Command+R は手動リフレッシュ専用に予約する。
//      通常ショートカットとして扱うと、再取得したい場面で登録済み "r"/"R" が発火してしまうため。
```

### 4.3 自動実行との関係

`⌘R` では既存の `SearchViewModel.refreshForPanelAsync()` を使う。

このメソッドはメインスレッド反映時に `updateItems(allowAutoExecute: false)` を呼ぶため、候補が 1 件になっても自動フォーカス移動を発生させない。

## 5. 実装手順

### Process 1: 復元不能 AI プロセスの除外

- [ ] `ProcessProvider.isProcessAlive(_:)` を追加する。
  - verify: 存在しない PID に対して false を返すテストを追加する。
- [ ] `ProcessProvider.isRecoverableAIProcess(_:)` を追加する。
  - verify: `terminalBundleId == nil` の `AIProcess` は false、値ありは true を返すテストを追加する。
- [ ] `listNonTmuxAIProcesses()` に生存確認と復元可能性確認を差し込む。
  - verify: 既存のデーモン除外テストが通る。

### Process 2: `⌘R` 手動リフレッシュ

- [ ] `SearchPanel.isManualRefreshShortcut(keyCode:flags:)` を追加する。
  - verify: `⌘R` と `⌘⇧R` を true として扱う。
- [ ] `startLocalKeyMonitor()` の冒頭で手動リフレッシュを処理する。
  - verify: `refreshForPanelAsync()` が呼ばれる経路であることをコードレビューする。
- [ ] `alphabetShortcutLabel` で `⌘R` と `⌘⇧R` を通常ショートカットから除外する。
  - verify: `alphabetShortcutLabel_withCommandR_returnsNilForRefreshShortcut` を追加する。
  - verify: `alphabetShortcutLabel_withCommandShiftR_returnsNilForRefreshShortcut` を追加する。

### Process 3: 回帰確認

- [ ] 対象テストを実行する。
  - verify: `swift test --filter ProcessProviderTests`
  - verify: `swift test --filter ShortcutBarTests`
- [ ] 全体確認を実行する。
  - verify: `swift build`
  - verify: `swift test --quiet`

## 6. テスト計画

### 6.1 単体テスト

- `ProcessProviderTests`
  - 存在しない PID は `isProcessAlive` が false を返す。
  - `terminalBundleId == nil` の `AIProcess` は復元不能と判定する。
  - `terminalBundleId` ありの `AIProcess` は復元可能と判定する。
  - 既存のデーモン除外テストが継続して通る。

- `ShortcutBarTests`
  - `⌘R` は `alphabetShortcutLabel` で nil になる。
  - `⌘⇧R` は `alphabetShortcutLabel` で nil になる。
  - 既存の小文字・大文字・Control ショートカット判定が継続して通る。

### 6.2 手動確認

- 絞り込み画面を開く。
- 終了済みの AI プロセス候補が残らないことを確認する。
- `❓` 付きで復元不能な候補が表示されにくくなることを確認する。
- `⌘R` を押して候補が再取得されることを確認する。
- `r` / `R` の通常ショートカットが、Command なしでは従来通り動作することを確認する。

## 7. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| ターミナル検出が一時的に失敗した生存プロセスも非表示になる | 見えるべき候補が一時的に消える | `⌘R` による再取得で救済する |
| `⌘R` が既存ショートカット `r` / `R` と衝突する | ショートカット対象が起動してしまう | `⌘R` / `⌘⇧R` を手動リフレッシュとして先に処理し、通常ショートカットから除外する |
| PID が `pgrep` 後に終了する | 古い候補が表示される | `sysctl` 生存確認を追加し、終了済み・ゾンビ状態を除外する |
| 自動実行設定がある環境で `⌘R` 後に勝手にフォーカス移動する | ユーザー操作の意図に反する | `refreshForPanelAsync()` の `allowAutoExecute: false` 経路を使う |

## 8. 受け入れ条件

- `swift build` が成功する。
- `swift test --quiet` が成功する。
- `ProcessProviderTests` と `ShortcutBarTests` が成功する。
- `terminalBundleId == nil` の AI プロセスは検索候補に含まれない。
- ゾンビ状態の PID は検索候補に含まれない。
- 絞り込み画面で `⌘R` / `⌘⇧R` により再取得できる。
- `⌘R` / `⌘⇧R` はアルファベットショートカットとして発火しない。

## 9. 実装対象ファイル

- `Sources/FocusBMLib/ProcessProvider.swift`
- `Sources/FocusBMApp/SearchPanel.swift`
- `Tests/focusbmTests/ProcessProviderTests.swift`
- `Tests/FocusBMAppTests/ShortcutBarTests.swift`
