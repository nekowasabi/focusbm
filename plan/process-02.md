# Process 2: activate(item:) ヘルパー抽出

## Overview
SearchPanel 内に3箇所散在するアクティベーション処理（restoreSelected → close → activate）を共通メソッドに抽出する。Process 6 でアルファベットキーバイパスを追加する前提。

## Affected Files
- `Sources/FocusBMApp/SearchPanel.swift` (L98-113, L116-132): digit/alpha キーハンドラ内のアクティベーション
- `Sources/FocusBMApp/SearchPanel.swift` (L44-51): `onAutoExecute` コールバック
- `Sources/FocusBMApp/SearchView.swift` (L66-73): onTapGesture 内のアクティベーション

## Implementation Notes
- 現在の3つのアクティベーション箇所:
  1. SearchPanel digit キーハンドラ (L108-113): `restoreSelected() → close() → activate()`
  2. SearchPanel alpha キーハンドラ (L126-132): 同上
  3. SearchPanel onAutoExecute (L44-51): 同上
  4. SearchView onTapGesture (L66-73): `selectedIndex = index → onSubmit` 経由
- 抽出先: `SearchPanel.activateItem(_ item: SearchItem)` or `SearchViewModel.activate(item:closePanel:)`

```swift
// Why: SearchPanel に配置。理由: panel.close() が必要なためPanel層のメソッドが適切
private func activateItem(_ item: SearchItem) {
    self.close()
    DispatchQueue.main.async {
        ActivationTarget.from(item)?.activate()
    }
}
```

- ActivationTarget.from(item:) が既存なら利用、なければ SearchItem → ActivationTarget 変換を確認

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - 抽出後も digit キーでのアクティベーションが正常動作すること
  - 抽出後も alpha キーでのアクティベーションが正常動作すること
  - 抽出後も autoExecute が正常動作すること
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `activateItem(_ item: SearchItem)` メソッドを SearchPanel に追加
- [ ] digit キーハンドラのアクティベーション部分を `activateItem` 呼び出しに置換
- [ ] alpha キーハンドラのアクティベーション部分を `activateItem` 呼び出しに置換
- [ ] onAutoExecute コールバックを `activateItem` 呼び出しに置換
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 不要になったインライン処理の削除
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: Process 6
