# Process 3: selectedIndex 参照先統一

## Overview
`selectedIndex` が `mainListAssignments` のみを追跡するよう、全5箇所の参照先を変更する。

## Affected Files
- `Sources/FocusBMApp/SearchViewModel.swift`:
  - L189-191: `updateItems()` 内の clamp ロジック — `searchItems.count` → `mainListAssignments.count`
  - L278-281: `moveUp()` — 変更不要（floor=0 は共通）
  - L284-287: `moveDown()` — `searchItems.count` → `mainListAssignments.count`
  - L290-292: `restoreSelected()` — `searchItems[selectedIndex]` → `mainListAssignments[selectedIndex].item`
- `Sources/FocusBMApp/SearchView.swift`:
  - L80-84: `onChange(of: selectedIndex)` — `searchItems[safe: newIndex]` → `mainListAssignments[safe: newIndex]?.item`
  - L43: `ForEach` — `shortcutAssignments` → `mainListAssignments` に変更
  - L59-62: `isAutoExecuteHighlighted` 条件 — `searchItems.count` → `mainListAssignments.count`
- `Sources/FocusBMApp/SearchViewModel.swift`:
  - L197-213: `autoExecuteOnSingleResult` — `searchItems.count == 1` → `mainListAssignments.count == 1`

## Implementation Notes
- **最重要**: `restoreSelected()` の戻り値は `searchItems[selectedIndex]` を参照している。分離後は `mainListAssignments[selectedIndex].item` に変更必須
- `safe:` subscript (SearchView.swift L110-113) は Array extension なので型変更なしで動作
- `moveDown()` の上限を `mainListAssignments.count - 1` に変更する際、`mainListAssignments` が computed property のため毎回計算コストがかかる点に注意（必要なら cached count 導入）

```swift
// Why: mainListAssignments を直接参照。理由: selectedIndex はメインリストのみを追跡する新契約
func moveDown() {
    if selectedIndex < mainListAssignments.count - 1 {
        selectedIndex += 1
    }
}

func restoreSelected() -> ActivationTarget? {
    guard selectedIndex >= 0, selectedIndex < mainListAssignments.count else { return nil }
    let item = mainListAssignments[selectedIndex].item
    // ... 既存の ActivationTarget 変換ロジック
}
```

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - `moveDown()` が `mainListAssignments.count - 1` で止まること
  - `restoreSelected()` が mainListAssignments からアイテムを取得すること
  - ショートカットバーアイテムが `selectedIndex` で選択されないこと
  - `updateItems()` 後の clamp が mainListAssignments ベースで動作すること
  - autoExecute が mainListAssignments.count == 1 で発火すること
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `moveDown()` の bounds を `mainListAssignments.count` に変更
- [ ] `restoreSelected()` の参照先を `mainListAssignments` に変更
- [ ] `updateItems()` の clamp を `mainListAssignments.count` に変更
- [ ] `autoExecuteOnSingleResult` の条件を `mainListAssignments.count` に変更
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] computed property の呼び出し回数を確認、必要なら count をキャッシュ
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1
- Blocks: Process 5
