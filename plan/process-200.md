# Process 200: README と bookmarks.yml サンプル更新

## Overview
新設定 `bookmarkListColumns` をユーザーが発見・採用しやすいよう、README とサンプル yml に説明・例・推奨 panelWidth を追記する。

## Affected Files
- `README.md`（プロジェクトルートに存在する場合）— 設定項目セクションに追加
- `bookmarks.example.yml` もしくは README 内サンプル — 以下の例を追加:
  ```yaml
  # 絞り込み画面を横2列表示にする（既定: 1列）
  bookmarkListColumns: 2
  panelWidth: 800  # 2列表示時の推奨値
  ```

## Implementation Notes
- README には以下観点を記載:
  - 設定キー名・型・値域（`Int?` / 1 or 2 / 既定 nil=1列）
  - 2列表示時の推奨 panelWidth（800 以上）
  - 不正値時の挙動（nil フォールバック）
  - キー操作（矢印・hjkl・数字）の2列対応説明
- スクリーンショット更新は任意（あれば差し替え）
- 英語版・日本語版 README があれば両方更新

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] （ドキュメントのため該当なし、skip 記録）

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] README の設定項目セクション更新
- [ ] サンプル yml に `bookmarkListColumns: 2` と推奨 panelWidth を追記
- [ ] 挙動説明（キー操作・不正値フォールバック）を追記
- [ ] Markdown lint 通過

Phase Complete

---

## Refactor Phase: 品質改善

- [ ] 説明文の冗長さを整理
- [ ] 「いつ 2列が便利か」のユースケース1行追加
- [ ] Markdown lint 再確認

Phase Complete

---

## Dependencies
- Requires: 100
- Blocks: 300
