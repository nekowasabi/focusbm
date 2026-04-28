# Process 12: BookmarkRow 着色描画テスト

## Overview
Process 3 で実装した BookmarkRow の着色描画を検証する。SwiftUI View の単体テストは制約があるため、ロジック部分（色選択ロジック、agentDisplay 取得）を分離可能な範囲でユニットテスト化し、視覚的検証は手動 UI 確認で補完する。

## Affected Files
- `Tests/FocusBMAppTests/BookmarkRowTests.swift` - 新規作成（または既存ファイル拡張）
- 視覚的確認: アプリ起動時のスクリーンショット記録

## Implementation Notes
- ユニットテスト可能な観点:
  1. 色選択ロジック関数（例: `colorForAgent(isRunning: Bool) -> Color`）を BookmarkRow から抽出可能か検討
  2. searchItem.agentDisplay の値に応じた expected color を検証
- ViewInspector パッケージの導入を検討（オプション、コスト次第）
- 手動確認チェックリスト:
  - [x] running の AI エージェント行で ● が緑色
  - [x] idle の AI エージェント行で ○ が赤色
  - [x] planMode (⏸) の AI エージェント行で ⏸ が赤色（statusEmoji が ⏸ の場合は色のみ赤）
  - [x] 通常の bookmark 行に色分け装飾がない

## Note
SwiftUI View 単体テストはコストが高いため、本 Process では「色選択ロジックの分離テスト」+「手動 UI 確認」のハイブリッド方針とする。ViewInspector 導入は別途判断。

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] 色選択ロジック関数を抽出（必要なら）
- [x] running=green, !running=red のテストケース追加
- [x] テスト実行 → 失敗確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] Process 3 完了後にテスト実行
- [x] 色選択ロジックテスト Green
- [x] 手動 UI 確認 (4 観点) を完了

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [x] ViewInspector 導入の必要性を再評価
- [x] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: 3
- Blocks: 100
