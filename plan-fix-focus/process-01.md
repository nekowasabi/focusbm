# Process 01: tmux client window 対応と focusPane 経路修正

## Implementation Brief（コピペ用）

> このセクションは別セッションで `/x @plan-fix-focus/process-01.md` を起動した際の自己完結ブリーフ。

- **背景**: 現在は tmux client 情報を取得しているが、session 単位でキャッシュし、`switch-client -c <tty>` が attached 経路で使われない。
- **目的**: 選択した tmux pane の window に対応する client tty を優先し、意図しないターミナルで表示される問題を防ぐ。
- **変更範囲**:
  - `Sources/FocusBMLib/TmuxProvider.swift`
  - `Sources/FocusBMLib/ActivationTarget.swift`
- **参照する定数**:
  - `MAX_TERMINAL_ANCESTOR_DEPTH`
  - `SYMBOL_LINE_TOLERANCE`
- **禁止事項**:
  - `preferredTerminal` だけで全 tmux pane の表示先を強制しない。
  - `clientTTY` が存在する pane を detached 扱いしない。
  - 同一 session 内の全 window に同じ terminal 情報を無条件コピーしない。
  - `switch-client` 失敗時に既存フォールバックまで止めない。
- **適用される横断方針（インライン展開）**:
  - 既存 YAML 設定の互換性を維持する。
  - tmux client の window 情報が得られない場合は、現在の session 単位 fallback を維持する。
  - debug log は既存 `TmuxProvider.log` 経路を使い、追加の永続ログは作らない。
  - API / 認証 / 秘密情報は対象外。
- **出力順序**:
  1) 実装（差分）
  2) セルフレビュー
  3) 修正
  4) 再レビュー
  5) ドキュメント更新確認
  6) 品質ゲート実行

---

## Overview

tmux client を `sessionName` だけでなく `sessionName + windowIndex` でも引けるようにする。`listAllPanes` では pane の window と一致する client を優先して `clientTTY` / terminal 情報を付与する。`focusPane` は `clientTTY` がある場合に `switch-client -c <tty> -t session:window` を実行し、その後 `select-pane` で対象 pane を選択する。

## Affected Files

- `Sources/FocusBMLib/TmuxProvider.swift`
  - `buildClientMap`: format に window 情報を含め、window 単位 map を構築可能にする。
  - `parseClientMapOutput`: `client_tty`, `client_session`, `window_index`, `window_name`, `pane_id`, `client_pid` を扱う。
  - `listAllPanes`: session 単位キャッシュを window-aware な選択に変更する。
  - `focusPaneArgs`: `clientTTY` がある場合に `-c` を含める既存意図を維持しつつ到達可能にする。
  - `focusPane`: attached / detached の二分を「clientTTY あり / なし」ではなく「clientTTY による対象 client 指定可否」に整理する。
- `Sources/FocusBMLib/ActivationTarget.swift`
  - 必要なら terminal client 用 case を追加する。ただしアプリ内 window の強制前面化までは行わない。

## Symbol Targets

- file: `Sources/FocusBMLib/TmuxProvider.swift`
  symbols:
    - name: `buildClientMap`
      kind: method
      body_start_line: 220
      body_end_line: 240
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
    - name: `parseClientMapOutput`
      kind: method
      body_start_line: 244
      body_end_line: 282
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
    - name: `listAllPanes`
      kind: method
      body_start_line: 286
      body_end_line: 349
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
    - name: `focusPaneArgs`
      kind: method
      body_start_line: 377
      body_end_line: 383
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
    - name: `focusPane`
      kind: method
      body_start_line: 401
      body_end_line: 455
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: true
  disjoint_guarantee: false
  pre_flight_checks:
    - symbol_exists
    - no_overlapping_wave
- file: `Sources/FocusBMLib/ActivationTarget.swift`
  symbols:
    - name: `ActivationTarget`
      kind: enum
      body_start_line: 5
      body_end_line: 28
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: true
  disjoint_guarantee: true
  pre_flight_checks:
    - symbol_exists

## Implementation Notes

- `TmuxClientInfo` のような内部構造体を作り、`tty`, `sessionName`, `windowIndex`, `windowName`, `paneId`, `clientPid`, `bundleId`, `appName` を保持する。
- map は少なくとも以下の二系統を持つ。
  - window key: `sessionName + windowIndex`
  - session fallback: `sessionName`
- `listAllPanes` の terminal 情報付与順序:
  1. `preferredTerminal` は表示名 fallback として扱う。ただし `clientTTY` を消さない。
  2. window key に一致する client を優先する。
  3. window key がない場合は session fallback を使う。
  4. どちらもない場合のみ既存の `detectTerminalApp` fallback を使う。
- `focusPane` の推奨順序:
  1. `clientTTY` がある場合は `switch-client -c <tty> -t session:window` を non-fatal に実行する。
  2. 続けて `select-window -t session:window` を non-fatal に実行する。
  3. 続けて `select-pane -t paneId` を non-fatal に実行する。
  4. `clientTTY` がない detached 相当の場合だけ、既存の fatal `switch-client -t session:window` を維持する。
- Why コメント:
  - `// Why: session 単位ではなく window 単位 client を優先 — 同一 session の別 window が別 terminal に表示される構成を壊さないため`
  - `// Why: clientTTY ありでも switch-client -c を実行 — 取得済み tty を tmux の対象 client 指定に反映するため`

## Behavior Specification

System Type: reactive

### State Transitions

| 現状態 | イベント | ガード | 次状態 | 事後条件 |
|--------|----------|--------|--------|----------|
| pane 候補表示中 | ユーザーが tmux AI pane を選択 | window key に一致する client あり | 対応 client の window/pane 選択 | `switch-client -c <tty>` が実行対象になる |
| pane 候補表示中 | ユーザーが tmux AI pane を選択 | window key なし / session fallback あり | session fallback client の window/pane 選択 | 既存互換で session の client を使う |
| pane 候補表示中 | ユーザーが tmux AI pane を選択 | client 情報なし | detached fallback | `switch-client -t session:window` を維持 |
| focus 中 | `switch-client -c` 失敗 | tmux コマンド終了コードが非成功 | select-window / select-pane 継続 | 既存の non-fatal 方針を維持 |
| terminal activate 中 | bundleId あり | 対象アプリ起動中 | アプリ前面化 | アプリ内 window の完全指定は保証しない |

### Correctness Criteria

- window key に一致する client がある pane では、`focusPaneArgs` 相当の引数に `-c <clientTTY>` が含まれる。
- 同一 session に複数 client があっても、対象 pane の `windowIndex` と一致する client が優先される。
- window key がない pane では、session fallback により既存の挙動が維持される。
- `preferredTerminal` が設定されていても、取得済み `clientTTY` を消さない。
- `switch-client -c` の失敗だけでユーザー選択全体を中断しない。

### Left to Implementation

- 内部構造体名、map 型の具体名、ヘルパ関数分割。
- debug log 文言の細部。
- terminal app 名の fallback 文字列の内部組み立て。

## Frontend Constraints

- AbortController: 対象外。SwiftUI / AppKit のローカル操作であり通信なし。
- cleanup 必須対象: なし。新規タイマー・イベント監視は追加しない。
- state リセット条件: `SearchViewModel` の状態遷移は変更しない。
- エラー時の表示: 既存の print / debug log 方針を維持し、ユーザー向け新規警告は追加しない。

## Performance & Scalability

- expected_load: パネル表示またはバックグラウンド更新ごとに tmux pane / client 情報を取得する既存負荷の範囲内に収める。
- latency_budget: 既存の体感応答を悪化させない。`list-clients` 追加 format による外部プロセス呼び出し回数の増加は禁止。
- bottleneck: terminal 検出で `ps` / `NSWorkspace` 参照が増えすぎること。client 情報は一括取得し、pane ごとの重複検出を避ける。

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] Process 10 のテストを先に作成する
  - window key 一致時に `clientTTY` が pane に入ること
  - `switch-client -c` が到達可能になること
  - session fallback が維持されること
- [ ] `swift test` を実行して失敗を確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] window-aware client map を追加
- [ ] `listAllPanes` の terminal/client 情報付与順序を修正
- [ ] `focusPane` の `switch-client -c` 到達不能経路を解消
- [ ] `swift test` を実行して成功確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 既存の `detectTerminalApp` fallback と重複した処理を最小限に整理
- [ ] Why コメントが実際の挙動と一致しているか確認
- [ ] `swift test` が継続して成功することを確認

✅ **Phase Complete**

---

## Manual Verification（手動検証シナリオ）

1. 操作: Ghostty / WezTerm / iTerm2 など複数 terminal で tmux client を開き、AI pane を選択する → 期待: 対応 client の window/pane が選択される → 状態確認: `tmux list-clients` と前面 terminal が一致する。
2. 操作: window key に一致しない detached session の pane を選択する → 期待: 既存 fallback で選択される → 状態確認: エラーで中断しない。
3. 操作: `preferredTerminal` を設定した状態で AI pane を選択する → 期待: `clientTTY` がある場合は tty 指定が優先される → 状態確認: preferredTerminal による誤った一律切替が起きない。

---

## Dependencies

- Requires: -
- Blocks: 10, 200, 300
