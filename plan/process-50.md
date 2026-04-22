# Process 50: GUI 手動検証チェックリスト

## Overview
XCTest では担保できない View 描画・NSEvent 経路・アニメーションを、手動検証チェックリストで補完する。全 Process 完了後にユーザー環境で一通り確認する。

## Affected Files
- 実行のみ（成果物ファイルなし）

## Implementation Notes
確認は以下環境で実施:
- macOS GUI 起動
- `~/.config/focusbm/bookmarks.yml` に切替用設定を反映
- 検証シナリオ:
  1. `bookmarkListColumns` 未指定 → 縦1列（既存動作）
  2. `bookmarkListColumns: 1` → 縦1列
  3. `bookmarkListColumns: 2` → 横2列
  4. `bookmarkListColumns: 3` → 縦1列（不正値フォールバック、WARN ログ）
  5. `bookmarkListColumns: 2` + `panelWidth` 未指定 → 幅 800px で表示
  6. `bookmarkListColumns: 2` + `panelWidth: 600` → 600px 維持（ユーザー明示優先）
- キー操作:
  - ↑↓: 上下移動（1列: selectedIndex±1 / 2列: ±columns）
  - ←→: 左右移動（1列: no-op / 2列: selectedIndex±1 境界クランプ）
  - 1-9: 直接実行（2列でも正しいアイテムにマップ）
  - hjkl: ↑↓←→と同等動作
- 奇数件レイアウト:
  - 5件時に最終行右セルが空セルで表示
  - 最終行左セル選択中に → を押しても空セルに移動しない
- 選択ハイライト:
  - 2列表示時の `.background(Color.accentColor.opacity(0.2))` が期待通り
  - 列切替（1→2）時に同じアイテムが選択状態維持

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] チェックリストを PLAN 直下にコピーまたは GitHub Issue 化
- [ ] （自動テスト該当なし）

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] 6 つの YAML 設定パターンを順に試行
- [ ] キー操作 4 カテゴリ（矢印/hjkl/数字/修飾キー）を順に試行
- [ ] 奇数件レイアウト 3 ケース確認
- [ ] 選択ハイライト 2 ケース確認
- [ ] 失敗項目があれば関連 Process にフィードバック

Phase Complete

---

## Refactor Phase: 品質改善

- [ ] チェックリストに通過日時・確認者を記録
- [ ] 将来の回帰防止のため README のスクリーンショットを更新（Process 200 と連携）

Phase Complete

---

## Dependencies
- Requires: 4, 5, 6, 100
- Blocks: 300
