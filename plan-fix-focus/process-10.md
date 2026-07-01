# Process 10: tmux フォーカス回帰テスト追加

## Implementation Brief（コピペ用）

> このセクションは別セッションで `/x @plan-fix-focus/process-10.md` を起動した際の自己完結ブリーフ。

- **背景**: `switch-client -c <tty>` の意図は既にコードにあるが、attached 経路では実質到達不能だった。
- **目的**: window 単位 client 選択・session fallback・`switch-client -c` 到達性をテストで固定する。
- **変更範囲**:
  - `Tests/focusbmTests/TmuxProviderTests.swift`
  - `Tests/focusbmTests/ActivationTargetTests.swift`
- **参照する定数**:
  - `SYMBOL_LINE_TOLERANCE`
- **禁止事項**:
  - 実装の都合だけを検証し、外部挙動を固定しないテストにしない。
  - 実ターミナル起動や実 tmux server への依存を追加しない。
- **適用される横断方針（インライン展開）**:
  - テストは引数生成・parse・情報付与順序を純粋関数寄りに検証する。
  - 実 OS の前面 window 状態に依存するテストは作らない。
  - API / 認証 / 秘密情報は対象外。
- **出力順序**:
  1) テスト追加
  2) 失敗確認
  3) Process 01 実装後の成功確認
  4) セルフレビュー
  5) 品質ゲート実行

---

## Overview

`TmuxProviderTests` に window-aware client map と focus 引数のテストを追加する。必要なら `ActivationTargetTests` に新 case の安全性テストを追加する。

## Affected Files

- `Tests/focusbmTests/TmuxProviderTests.swift`
  - `parseClientMapOutput` の window 情報対応
  - 同一 session 複数 client の window 優先
  - `focusPaneArgs` の `-c` 引数生成
  - fallback の維持
- `Tests/focusbmTests/ActivationTargetTests.swift`
  - `ActivationTarget` に case を追加した場合のみ安全実行テスト

## Symbol Targets

- file: `Tests/focusbmTests/TmuxProviderTests.swift`
  symbols:
    - name: module-level tests
      kind: module-level
      body_start_line: 506
      body_end_line: 747
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: false
  disjoint_guarantee: false
  pre_flight_checks:
    - no_overlapping_wave
- file: `Tests/focusbmTests/ActivationTargetTests.swift`
  symbols:
    - name: module-level tests
      kind: module-level
      body_start_line: 1
      body_end_line: 120
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks:
    - symbol_exists

## Implementation Notes

- 追加するテスト観点:
  - `parseClientMapOutput` が `client_tty`, `client_session`, `window_index`, `window_name`, `pane_id`, `client_pid` を取り込む。
  - 同一 session に複数 client があるとき、対象 window の client が優先される。
  - `focusPaneArgs` は `clientTTY` ありで `switch-client -c <tty> -t session:window` を返す。
  - `clientTTY` なしの場合は既存の `switch-client -t session:window` を維持する。
  - `preferredTerminal` があっても `clientTTY` が失われない。
- テスト名は既存スタイルに合わせ、`@Test func test_...()` を使う。
- 実 tmux には依存せず、parse と引数生成の純粋関数で固定する。

## Behavior Specification

System Type: transformation

### I/O Mapping

| 入力 | 出力 | pre_state | post_state | invariants |
|------|------|-----------|------------|------------|
| 複数 client の list-clients 出力 | window key ごとの client 情報 | 同一 session に別 window client が存在 | window ごとに別 client を参照できる | session fallback は保持 |
| `TmuxPane` + `clientTTY` | `switch-client -c <tty> -t session:window` 引数 | pane に clientTTY あり | tty 指定が引数に入る | target は session/window 形式 |
| `TmuxPane` + clientTTY なし | `switch-client -t session:window` 引数 | pane に clientTTY なし | 既存 detached 形式を返す | target は session/window 形式 |

### Correctness Criteria

- テストは Process 01 実装前に少なくとも window-aware client map 観点で失敗する。
- Process 01 実装後に `swift test` が成功する。
- OS の前面アプリや実 tmux server に依存しない。

### Left to Implementation

- テストヘルパ関数名。
- サンプル session/window 名。
- assert メッセージの細部。

## Frontend Constraints

- AbortController: 対象外。通信処理なし。
- cleanup 必須対象: なし。UI イベント監視・タイマーを追加しない。
- state リセット条件: 対象外。テスト対象は tmux client 情報の変換と引数生成。
- エラー時の表示: 対象外。ユーザー表示ではなく回帰テストで固定する。

## Performance & Scalability

- expected_load: テストは実 tmux server / 実 terminal 起動に依存せず、純粋な parse / 引数生成で完了する。
- latency_budget: `swift test` 全体の既存実行時間を大きく増やさない。外部プロセス起動を伴う新規テストは禁止。
- bottleneck: OS 前面 window 状態や実プロセス探索に依存すると遅く不安定になるため、fixture 文字列と構造体で検証する。

---

## Red Phase: テスト作成と失敗確認

- [ ] window-aware client map の失敗テストを追加
- [ ] `switch-client -c` 到達性の失敗テストを追加
- [ ] fallback 維持テストを追加
- [ ] `swift test` を実行して失敗確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] Process 01 の実装後に `swift test` を実行
- [ ] 既存テストを含め全件成功を確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] テスト名が挙動を説明しているか確認
- [ ] テストデータに不要な値がないか確認
- [ ] `swift test` が継続して成功することを確認

✅ **Phase Complete**

---

## Manual Verification（手動検証シナリオ）

対象外: この Process は自動テストで挙動契約を固定する。実機確認は Process 01 の Manual Verification で実施する。

---

## Dependencies

- Requires: 01
- Blocks: 200, 300
