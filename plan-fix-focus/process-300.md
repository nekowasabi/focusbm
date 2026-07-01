# Process 300: OODA レトロスペクティブと知見保存

## Implementation Brief（コピペ用）

> このセクションは別セッションで `/x @plan-fix-focus/process-300.md` を起動した際の自己完結ブリーフ。

- **背景**: 今回の不具合は「情報は取得済みだが、実行経路で使われない」という設計ずれだった。
- **目的**: 修正完了後に再発防止の知見を Serena / ByteRover / 必要なプロジェクトメモへ保存する。
- **変更範囲**:
  - `.serena` memory（必要に応じて）
  - ByteRover context tree
  - セッション報告
- **参照する定数**:
  - なし
- **禁止事項**:
  - 単なる作業ログを長期知識として保存しない。
  - 実装前の仮説を事実として保存しない。
- **適用される横断方針（インライン展開）**:
  - 保存するのは、再利用可能な設計判断・落とし穴・再発防止パターンに限定する。
  - コードを読めば分かるだけの構造説明は保存しない。
- **出力順序**:
  1) 修正結果確認
  2) 教訓抽出
  3) Serena / ByteRover 保存
  4) 完了報告

---

## Overview

Process 01 / 10 / 200 が完了した後、何が根本原因で、どの設計判断で再発を防いだかを記録する。特に「取得済み情報を cache で粗く丸めると、実行時の選択精度が落ちる」という知見を残す。

## Affected Files

- 直接のコード変更なし。
- 必要に応じて記憶ストアへ保存。

## Symbol Targets

- file: -
  symbols:
    - name: -
      kind: module-level
      body_start_line: -
      body_end_line: -
      line_hint: -
  patch_only: false
  disjoint_guarantee: n/a
  pre_flight_checks:
    - implementation_complete
    - tests_green

## Implementation Notes

- 保存候補:
  - tmux client 対応情報は session 単位ではなく window 単位で扱う。
  - `clientTTY` は表示用メタデータではなく、`switch-client -c` の実行制御データとして扱う。
  - fallback は壊さず、精度の高い対応情報がある場合だけ優先する。
- 保存しないもの:
  - 個別のテスト名一覧。
  - README の文面そのもの。
  - 実行したコマンド履歴だけの記録。

## Behavior Specification

対象外: 知見保存 Process。アプリの外部挙動は Process 01 が正本。

---

## Red Phase: テスト作成と失敗確認

- [ ] Process 01 / 10 / 200 が完了していることを確認
- [ ] 保存すべき知見と保存しない作業ログを分離

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] Serena memory に保存する場合は短く構造化して保存
- [ ] ByteRover に保存する場合は `brv curate` を使い、完了を待つ
- [ ] 保存内容に仮説と事実の混同がないか確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 既存 memory と重複していないか確認
- [ ] 将来の類似修正に使える粒度になっているか確認

✅ **Phase Complete**

---

## Knowledge Phase: 知見の永続化

- [ ] `.serena/memories/` に教訓を保存（必要な場合）
- [ ] byterover に再利用可能な設計判断を保存
- [ ] 重要度が高い場合のみプロジェクトメモに追記

✅ **Phase Complete**

---

## Manual Verification（手動検証シナリオ）

1. 操作: 保存した知見を検索する → 期待: tmux client / terminal focus の再発防止観点が見つかる → 状態確認: 事実と仮説が分離されている。

---

## Dependencies

- Requires: 01, 10, 200
- Blocks: -
