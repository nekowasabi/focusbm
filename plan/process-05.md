# Process 5: SearchView 統合

## Overview
SearchView の ForEach を mainListAssignments に変更し、フッター下にショートカットバーを条件付きで追加する。

## Affected Files
- `Sources/FocusBMApp/SearchView.swift`:
  - L43: `ForEach(viewModel.shortcutAssignments.enumerated())` → `ForEach(viewModel.mainListAssignments.enumerated())`
  - L59-62: `isAutoExecuteHighlighted` 条件内の `searchItems.count` → `mainListAssignments.count`
  - L80-84: `onChange` の `searchItems[safe:]` → `mainListAssignments[safe:]?.item`
  - L89-99 の後: 新規 ShortcutBarView セクション追加

## Implementation Notes
- 既存のフッターヒント（移動/復元/閉じる）は維持
- ShortcutBarView は `viewModel.query.isEmpty && !viewModel.shortcutBarItems.isEmpty` の時のみ表示

```swift
// SearchView body 変更後の構造:
VStack(spacing: 0) {
    // 検索フィールド（既存）
    HStack { ... }
    Divider()

    // メインリスト（mainListAssignments のみ）
    if viewModel.mainListAssignments.isEmpty {
        Text("No bookmarks found") ...
    } else {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.mainListAssignments.enumerated()), id: \.element.item.id) { index, pair in
                        BookmarkRow(...)
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                if let pair = viewModel.mainListAssignments[safe: newIndex] {
                    withAnimation { proxy.scrollTo(pair.item.id, anchor: .bottom) }
                }
            }
        }
    }

    Divider()
    // フッターヒント（既存）
    HStack(spacing: 16) { ... }

    // ショートカットバー（NEW）
    if viewModel.query.isEmpty && !viewModel.shortcutBarItems.isEmpty {
        Divider()
        ShortcutBarView(
            items: viewModel.shortcutBarItems,
            directNumberKeys: viewModel.directNumberKeys,
            onActivate: { item in panel?.activateItem(item) }
        )
    }
}
```

- **注意**: `safe:` subscript は `Array` extension なので `[(item: SearchItem, label: String?)]` でも動作する
- `panel?.activateItem(item)` — Process 2 で抽出した共通アクティベーションメソッドを使用
- `isEmpty` チェックで空のショートカットバーを表示しないようガード

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - メインリストに shortcutBarItems が含まれないこと
  - query が空の時にショートカットバーが表示されること
  - query が非空の時にショートカットバーが非表示になること
  - ショートカットバーのタップでアイテムがアクティベートされること
  - selectedIndex の onChange が mainListAssignments ベースでスクロールすること
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] ForEach のソースを `mainListAssignments` に変更
- [ ] onChange scroll の参照先を変更
- [ ] autoExecute highlight 条件を変更
- [ ] フッター下に ShortcutBarView を条件付き追加
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 重複コードの整理
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1, 3, 4
- Blocks: Process 10
