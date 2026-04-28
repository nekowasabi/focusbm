# Process 200: ドキュメント更新（README/DESIGN）

## Overview
statusEmoji の色分け表示機能を README または docs/ 配下のドキュメントに追記する。ユーザー向けの機能説明と、開発者向けの設計メモ（FocusBMLib が SwiftUI 非依存を維持していること）を併記する。

## Affected Files
- `README.md` - 機能説明セクションに「AIエージェント行の状態色分け」を追記
- `docs/DESIGN.md`（存在する場合）- 設計メモ追加。なければ新規作成は見送り
- `.serena/memories/`（存在する場合）- プロジェクト記憶に設計決定を記録

## Implementation Notes
- README 追記内容:
  - 機能名: AIエージェント動作状態の色分け表示
  - 説明: tmux pane で実行中の AIエージェント行は緑色の ● で「処理中」を表示し、それ以外は赤色の ○ で「待機中」を表示
  - スクリーンショット推奨（手動撮影、docs/images/ 配下に配置）
- 設計メモ:
  - FocusBMLib に Color を持ち込まない理由（SwiftUI 非依存維持、テスト容易性）
  - displayName の後方互換性を維持した非破壊変更の意図
  - showAIAgentShortcut 設定との独立性

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] README 内の関連セクションを把握
- [ ] 既存ドキュメントとの整合性確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] README に色分け機能の説明を追記
- [ ] スクリーンショット撮影 (オプション)
- [ ] docs/ または .serena/memories/ に設計メモ追加 (オプション)
- [ ] 文章のレビュー（誤字脱字確認）

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] ドキュメントの可読性向上
- [ ] 既存ドキュメントとのフォーマット統一

✅ **Phase Complete**

---

## Dependencies
- Requires: 100
- Blocks: 300
