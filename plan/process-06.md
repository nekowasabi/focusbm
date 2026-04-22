# Process 6: FocusBMApp の2列時デフォルト幅補正

## Overview
既定 `panelWidth=500` は2列表示には狭すぎるため、`columns==2` かつ `panelWidth` が未指定の場合に推奨幅（例: 800）を適用する。ユーザー明示設定は尊重する。

## Affected Files
- `Sources/FocusBMApp/FocusBMApp.swift:247,319` — `panelWidth` 決定ロジックに列数考慮を追加

## Implementation Notes
- 変更前:
  ```swift
  let width = store.settings?.panelWidth ?? 500
  ```
- 変更後:
  ```swift
  // Why: 2列時の既定500pxは狭すぎるため、未指定時のみ800にブースト（ユーザー明示値は尊重）
  let defaultWidth: CGFloat = (store.settings?.bookmarkListColumns == 2) ? 800 : 500
  let width = store.settings?.panelWidth ?? defaultWidth
  ```
- L319 の類似箇所も同様に更新
- 定数（500/800）は `Sources/FocusBMLib/Models.swift` に `public enum PanelDefaults` として集約すると良い（Refactor で実施）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - View 層のサイズ算出は XCTest 対象外。Process 50 の手動検証に委譲
- [x] テストを実行して失敗することを確認（該当なしなら skip 記録）

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] L247 の panelWidth 決定ロジックを更新
- [x] L319 の類似箇所も更新
- [x] 手動起動で `bookmarkListColumns: 2`・`panelWidth` 未設定時に幅 800 になることを確認

Phase Complete

---

## Refactor Phase: 品質改善

- [x] 定数を `PanelDefaults` enum に集約
- [x] Why コメント整理
- [x] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 2
- Blocks: 50
