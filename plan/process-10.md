# Process 10: 統合テスト

## Overview
Process 1-6 の全変更が連携して正しく動作することを検証する統合テストスイート。

## Affected Files
- `Tests/FocusBMTests/SearchViewModelTests.swift`: 既存テストの更新 + 新規統合テスト
- `Tests/FocusBMTests/ShortcutBarTests.swift`: 新規テストファイル

## Implementation Notes
- 既存の SearchViewModelTests の shortcutAssignments テストは mainListAssignments / shortcutBarItems に分化
- テストシナリオ:

### シナリオ A: 基本分離
1. YAML に shortcut: "g", shortcut: "v" のブックマーク + 通常ブックマーク5件をセット
2. `shortcutBarItems.count == 2`, `mainListAssignments.count == 5` を検証
3. mainListAssignments に "g", "v" アイテムが含まれないことを検証

### シナリオ B: キーボードナビゲーション
1. mainListAssignments に5件セット
2. `moveDown()` を5回呼び出し → selectedIndex が 4（最後）で停止
3. `moveUp()` を1回 → selectedIndex が 3
4. shortcutBarItems のアイテムが selectedIndex 操作に影響されないこと

### シナリオ C: 検索モード遷移
1. query を空→非空に変更
2. shortcutBarItems が表示対象外（UI側でガード）であることの ViewModel 側確認
3. 検索結果に shortcut 付きアイテムが含まれること（排除されない）
4. query を空に戻す → shortcutBarItems が再び有効

### シナリオ D: アルファベットキーアクティベーション
1. shortcutBarItems に "g" → Chrome をセット
2. "g" キー押下シミュレート → Chrome がアクティベート対象として返ること
3. selectedIndex が変更されていないこと

### シナリオ E: エッジケース
1. ショートカット0件 → shortcutBarItems 空、mainListAssignments == shortcutAssignments
2. 全アイテムがショートカット → mainListAssignments が数字ショートカットのみ
3. noShortcut: true のアイテム → どちらのリストにも badge なしで存在

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] シナリオ A-E のテストケースを作成
- [ ] 全テストが既存コードで失敗することを確認（Process 1-6 実装前）

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] Process 1-6 の実装完了後に全テスト実行
- [ ] 全シナリオが通過することを確認
- [ ] `swift build` が成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] テストの重複を整理
- [ ] テストヘルパーの共通化
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1, 2, 3, 4, 5, 6
- Blocks: Process 200
