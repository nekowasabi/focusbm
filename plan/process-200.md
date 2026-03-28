# Process 200: README 更新

## Overview
ショートカットバー機能の説明をREADMEに追記する。

## Affected Files
- `README.md`: ショートカットバーの説明セクション追加

## Implementation Notes
- 既存の shortcut / noShortcut / lowPriority フィールドの説明に、UIの変更を反映
- ショートカットバーの表示条件（query が空の時のみ）を明記
- スクリーンショットまたはASCIIアートでレイアウト変更を図示

追記内容の概要:
- 「ショートカットバー」セクション新設
- YAML の `shortcut:` フィールドを設定したアプリは下部バーに表示される説明
- キーボードショートカット（アルファベットキー直接 or ⌘+キー）の説明

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] README の記載が実装と一致していることを手動確認するチェックリスト作成

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] README にショートカットバーセクションを追記
- [ ] 既存のショートカット説明との整合性確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] 文章の推敲
- [ ] レイアウト図の確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 10
- Blocks: Process 300
