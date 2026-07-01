# Process 200: README tmux 連携説明更新

## Implementation Brief（コピペ用）

> このセクションは別セッションで `/x @plan-fix-focus/process-200.md` を起動した際の自己完結ブリーフ。

- **背景**: tmux pane 選択時の terminal 検出と fallback の実際の挙動が README に十分書かれていない。
- **目的**: window 単位 client 優先と fallback の仕様を利用者向けに説明する。
- **変更範囲**:
  - `README.md`
  - `README_ja.md`
- **参照する定数**:
  - なし
- **禁止事項**:
  - 「必ず特定ウィンドウを前面化できる」と断定しない。
  - コード内部名を利用者説明へ過剰に出さない。
- **適用される横断方針（インライン展開）**:
  - 英語版と日本語版で同じ外部挙動を説明する。
  - 実装詳細より、利用者が期待できる挙動と制限を優先する。
- **出力順序**:
  1) README 更新
  2) セルフレビュー
  3) リンク・表記確認
  4) 品質ゲート実行

---

## Overview

tmux 連携セクションに、terminal 検出が window 単位 client を優先し、見つからない場合に session fallback を使うことを追加する。同一 terminal アプリ内の window 前面化は OS / terminal 側の挙動に依存するため、保証しない旨も明記する。

## Affected Files

- `README.md`
  - `tmux Integration` / `Terminal detection` 付近
- `README_ja.md`
  - `tmux 連携` 付近

## Symbol Targets

- file: `README.md`
  symbols:
    - name: tmux Integration section
      kind: module-level
      body_start_line: 352
      body_end_line: 390
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: false
  disjoint_guarantee: n/a
  pre_flight_checks:
    - doc_section_exists
- file: `README_ja.md`
  symbols:
    - name: tmux 連携 section
      kind: module-level
      body_start_line: 344
      body_end_line: 355
      line_hint: `SYMBOL_LINE_TOLERANCE` 内
  patch_only: false
  disjoint_guarantee: n/a
  pre_flight_checks:
    - doc_section_exists

## Implementation Notes

- 英語版には以下を説明する:
  - FocusBM prefers the tmux client currently showing the target session/window.
  - If no matching client exists, FocusBM falls back to the session-level client or existing terminal detection.
  - Activating a terminal app may still depend on terminal/OS window behavior.
- 日本語版には同内容を自然な日本語で説明する。
- `preferredTerminal` は fallback / 表示補助であり、取得済み client tty を上書きする用途ではないと明記する。

## Behavior Specification

対象外: doc-only Process。外部挙動は Process 01 の Behavior Specification が正本。

---

## Red Phase: テスト作成と失敗確認

- [ ] README の対象セクションを確認
- [ ] 既存説明との差分を確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] `README.md` を更新
- [ ] `README_ja.md` を更新
- [ ] 表記が実装と一致していることを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 英語版と日本語版の説明に矛盾がないか確認
- [ ] 制限事項が断定過剰になっていないか確認
- [ ] `swift test` を実行し、文書更新と実装が同じコミットに入っても問題ないことを確認

✅ **Phase Complete**

---

## Manual Verification（手動検証シナリオ）

1. 操作: README の tmux 連携説明を読む → 期待: window client 優先と fallback が分かる → 状態確認: Process 01 の仕様と矛盾しない。

---

## Dependencies

- Requires: 01, 10
- Blocks: 300
