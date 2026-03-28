# Process 6: SearchPanel キーハンドラ更新

## Overview
アルファベットキーのハンドラを `labelToIndex` + `selectedIndex` 経由から `shortcutBarItems` 直接ルックアップ + `activateItem()` に変更する。

## Affected Files
- `Sources/FocusBMApp/SearchPanel.swift`:
  - L80-88: `alphabetKeyCodes` — 変更なし（キーコード→文字変換は共通）
  - L116-132: アルファベットキーハンドラ — `labelToIndex` → `shortcutBarItems` 直接参照に変更
- `Sources/FocusBMApp/SearchViewModel.swift`:
  - `labelToIndex` — アルファベットエントリを除外（数字のみ残す）、またはアルファベット用の別マップ追加

## Implementation Notes
- 現在のアルファベットキーハンドラ（SearchPanel.swift L116-132）:
  ```swift
  if let label = Self.alphabetKeyCodes[keyCode],
     self.viewModel.query.isEmpty,
     let index = self.viewModel.labelToIndex[label] {
      self.viewModel.selectedIndex = index  // ← これを削除
      if let target = self.viewModel.restoreSelected() { ... }
  }
  ```
- 変更後:
  ```swift
  // Why: selectedIndex をバイパス。理由: shortcutBarItems はメインリスト外のためインデックスが対応しない
  if let label = Self.alphabetKeyCodes[keyCode],
     self.viewModel.query.isEmpty,
     let pair = self.viewModel.shortcutBarItems.first(where: { $0.label == label }) {
      self.activateItem(pair.item)  // Process 2 で抽出したヘルパー
  }
  ```
- **数字キーハンドラ（L98-113）は変更なし** — `digitToIndex` は mainListAssignments のインデックスと一致する
- `labelToIndex` からアルファベットエントリを除去するか、アルファベット用に `shortcutBarLabelMap: [String: SearchItem]` を新設するか選択
  - 推奨: `shortcutBarItems.first(where:)` で十分（アイテム数は最大26、O(n) でも無視できる）

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - アルファベットキー押下で shortcutBarItems のアイテムがアクティベートされること
  - アルファベットキー押下で selectedIndex が変更されないこと
  - 数字キーの動作が変更されていないこと
  - query が非空の時にアルファベットキーがテキスト入力にフォールスルーすること
  - shortcutBarItems に存在しない文字キーがテキスト入力にフォールスルーすること
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] アルファベットキーハンドラを `shortcutBarItems` 直接参照に変更
- [ ] `activateItem()` 呼び出しに置換（Process 2 のヘルパー使用）
- [ ] `selectedIndex` への代入を削除
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] `labelToIndex` からアルファベットエントリの除去を検討
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1, 2
- Blocks: Process 10
