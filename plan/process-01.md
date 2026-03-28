# Process 1: ViewModel データ分離

## Overview
SearchViewModel の `shortcutAssignments` を `mainListAssignments`（数字ショートカット+通常アイテム）と `shortcutBarItems`（YAML alphabet ショートカット専用）に分離する。

## Affected Files
- `Sources/FocusBMApp/SearchViewModel.swift` (L221-257): `shortcutAssignments` computed property の分割

## Implementation Notes
- `shortcutBarItems`: `shortcutAssignments` から `bm.shortcut != nil` のアイテムのみを抽出
  - 型: `[(item: SearchItem, label: String)]` — label は必ず non-nil（YAML shortcut 値）
  - floatingWindow/tmuxPane/aiProcess は常に mainList 側（shortcut フィールドを持たない）
- `mainListAssignments`: `shortcutAssignments` から shortcutBarItems を除いたもの
  - 型: `[(item: SearchItem, label: String?)]` — 既存と同じ
- 既存の `shortcutAssignments` は一旦残し、新プロパティから参照する形にする（段階的移行）
- `reservedLabels` ロジックはそのまま維持（数字の自動割り当てスキップに使用）

```swift
// Why: shortcutAssignments を分解せず、フィルタで分離。理由: 既存ロジックの変更最小化
var shortcutBarItems: [(item: SearchItem, label: String)] {
    shortcutAssignments.compactMap { pair in
        guard let label = pair.label,
              case .bookmark(let bm) = pair.item,
              bm.shortcut != nil else { return nil }
        return (item: pair.item, label: label)
    }
}

var mainListAssignments: [(item: SearchItem, label: String?)] {
    let barItemIds = Set(shortcutBarItems.map { $0.item.id })
    return shortcutAssignments.filter { !barItemIds.contains($0.item.id) }
}
```

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - `shortcutBarItems` が YAML `shortcut` 付きアイテムのみを返すこと
  - `mainListAssignments` が shortcutBarItems を含まないこと
  - `mainListAssignments.count + shortcutBarItems.count == shortcutAssignments.count` が成立すること
  - shortcut 項目が0件の場合、`shortcutBarItems` が空配列を返すこと
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `shortcutBarItems` computed property を追加
- [ ] `mainListAssignments` computed property を追加
- [ ] 既存の `shortcutAssignments` は変更せず維持
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 不要な中間変数の整理
- [ ] ドキュメントコメント追加
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: Process 3, 4, 5, 6, 10
