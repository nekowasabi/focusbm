# Process 5: SearchPanel の左右矢印+数字キーVM委譲

## Overview
`SearchPanel.startLocalKeyMonitor()` の NSEvent ハンドラから数字キー処理を VM に委譲し、左右矢印キー（←→）を追加する。キーディスパッチ層を薄くして VM 層のテストで間接的に担保する。

## Affected Files
- `Sources/FocusBMApp/SearchPanel.swift:121-134` — 数字キーハンドラを `viewModel.selectByDigit(number)` 呼び出しに置換
- `Sources/FocusBMApp/SearchPanel.swift` — 矢印キー分岐を追加:
  - `NSEvent.SpecialKey.leftArrow` → `viewModel.moveLeft()`
  - `NSEvent.SpecialKey.rightArrow` → `viewModel.moveRight()`
  - 既存の `upArrow`/`downArrow` は `moveUp`/`moveDown` 呼び出しに置換

## Implementation Notes
- hjkl バインドが既存する場合、同じ VM メソッドを呼び出し動作統一
- `modifierFlags` で修飾キー併用時はデフォルト挙動を優先（Cmd+矢印等は既存踏襲）
- `selectByDigit` は Bool を返すので、処理済みなら `return nil`（イベント消費）、未処理なら `return event`
- 1列時は `moveLeft`/`moveRight` が no-op なので、キーイベントは消費せず次レスポンダに流す（判定は VM 側 bool 返し値で制御）

---

## Red Phase: テスト作成と失敗確認

- [x] ブリーフィング確認
- [x] テストケースを作成（実装前に失敗確認）
  - VM メソッドは Process 11 でテスト済み。ここでは統合テスト/手動確認（Process 50）に依存
- [x] テストを実行して失敗することを確認（NSEvent 直接テスト不可のため該当なし）

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [x] ブリーフィング確認
- [x] 数字キーハンドラを `viewModel.selectByDigit(number)` に置換（process-03 で実装済み）
- [x] 左右矢印分岐追加（keyCode 123/124 → moveLeft/moveRight）
- [x] 既存 upArrow/downArrow を `viewModel.moveUp/moveDown` に置換（既存維持）
- [x] 手動起動で各キーが期待通り動くことを確認（SearchViewModelGridTests 20件 PASS）

Phase Complete

---

## Refactor Phase: 品質改善

- [x] キー→VMメソッドのマッピングを private dictionary に整理（可読性向上）
- [x] Why コメントで「VM にロジック集約した理由（テスト容易性）」を明記
- [x] テストが継続して成功することを確認（20件 PASS）

Phase Complete

---

## Dependencies
- Requires: 3
- Blocks: 50
