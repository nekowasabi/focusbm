# Process 4: ShortcutBarView 新規作成

## Overview
水平スクロール HStack でショートカットアプリをアイコン+文字バッジとしてコンパクトに表示する新規ビュー。

## Affected Files
- 新規: `Sources/FocusBMApp/ShortcutBarView.swift`
- 参照: `Sources/FocusBMApp/BookmarkRow.swift` (L54-65): 既存バッジスタイルを踏襲
- 参照: `Sources/FocusBMLib/AppIconProvider.swift`: アイコン取得（`AppIconProvider.shared.icon(forAppName:)`）

## Implementation Notes
- 各バッジのデザイン: 32×32pt 角丸四角、中央にアプリアイコン(16×16pt)、右下に文字バッジ
- 水平スクロール: `ScrollView(.horizontal, showsIndicators: false)` — 5-6個が快適、それ以上はスクロール
- `directNumberKeys` 設定に応じてバッジ表示を切り替え（`g` or `⌘g`）
- タップで直接アクティベート（`onTapGesture` → activateItem）
- カラー: `Color.accentColor.opacity(0.1)` 背景 + `.secondary` テキスト（既存バッジと統一）

```swift
struct ShortcutBarView: View {
    let items: [(item: SearchItem, label: String)]
    let directNumberKeys: Bool
    var onActivate: (SearchItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.item.id) { _, pair in
                    ShortcutBadge(
                        item: pair.item,
                        label: pair.label,
                        directNumberKeys: directNumberKeys
                    )
                    .onTapGesture { onActivate(pair.item) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct ShortcutBadge: View {
    let item: SearchItem
    let label: String
    let directNumberKeys: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: AppIconProvider.shared.icon(forAppName: item.appName))
                .resizable()
                .frame(width: 20, height: 20)
            Text(directNumberKeys ? label : "⌘\(label)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(6)
    }
}
```

- パネル幅500ptでの収容: 各バッジ約44pt幅 → 500pt - 24pt padding = 476pt → 約10個表示可能

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - ShortcutBarView が items 配列の全アイテムを表示すること
  - items が空の場合、バーが表示されないこと（親ビューでガード）
  - directNumberKeys=true で "g"、false で "⌘g" と表示されること
  - onActivate コールバックがタップ時に呼ばれること
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `ShortcutBarView.swift` を新規作成
- [ ] `ShortcutBadge` サブビューを実装
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] アクセシビリティラベルの追加
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1
- Blocks: Process 5
