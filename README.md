# focusbm

macOS アプリフォーカスのブックマークツール。YAML でアプリの切り替え先を定義し、一発で復元できる **CLI ツール** および **メニューバー常駐アプリ** のセット。

## 機能概要

| ツール | 形態 | 概要 |
|---|---|---|
| `focusbm` | CLI | サブコマンドでブックマークの追加・復元・管理 |
| `FocusBMApp` | メニューバーアプリ | グローバルホットキーで呼び出せるフローティング検索パネル |

---

## CLI ツール（focusbm）

### サブコマンド一覧

| サブコマンド | 説明 |
|---|---|
| `add <name> <bundleId>` | ブックマークを手動追加（YAML テンプレート生成）⭐推奨 |
| `edit` | ブックマーク YAML をエディタで開く ⭐推奨 |
| `save <name>` | 現在フォーカス中のアプリからブックマーク保存（補助コマンド） |
| `restore <name>` | 指定したブックマークを復元してフォーカス |
| `restore-context <context>` | コンテキスト内の全ブックマークを一括復元 |
| `switch` | fzf でブックマークを絞り込み選択して復元 |
| `list` | ブックマーク一覧を表示 |
| `delete <name>` | 指定したブックマークを削除 |

### 使い方

#### 推奨ワークフロー: YAML 定義 → 復元

`save` コマンドは最前面アプリしか取得できないため、**YAML 手動定義が推奨ワークフロー**です。

##### 1. ブックマークを追加する（`add` コマンド）

```sh
# アプリブックマークを追加
focusbm add mywork com.example.app --context work

# 表示名を指定
focusbm add mywork com.example.app --app-name "My App" --context work

# ブラウザブックマーク（URL パターン指定）
focusbm add pr com.microsoft.edgemac --url "github.com/pulls" --context dev

# ブラウザブックマーク（タブインデックス指定）
focusbm add slack com.google.Chrome --url "app.slack.com" --tab-index 3 --context work

# 正規表現パターン
focusbm add taskchute "^com\\.electron\\.taskchute" --app-name "TaskChute Cloud"
```

##### 2. YAML を直接編集する

```sh
# $EDITOR で YAML を開く
focusbm edit
```

##### 3. ブックマークを復元する

```sh
focusbm restore mywork

# fzf で選択して復元
focusbm switch

# コンテキスト内の全ブックマークを一括復元
focusbm restore-context work
```

#### 補助: 現在のアプリを保存する（`save` コマンド）

最前面のアプリの状態を素早くブックマークしたい場合に使用できます。ただし、取得できるのは現在フォーカス中のアプリのみです。

```sh
# 現在のフォーカス状態を "mywork" という名前で保存
focusbm save mywork

# コンテキスト（タグ）を指定して保存
focusbm save mywork --context project-a
```

#### ブックマーク一覧を表示する

```sh
# 通常表示（コンテキスト別グループ表示）
focusbm list

# コンテキストで絞り込み
focusbm list --context project-a

# fzf と連携（パイプ入力用フォーマット）
focusbm list --format fzf
```

#### ブックマークを削除する

```sh
focusbm delete mywork
```

---

## メニューバー常駐アプリ（FocusBMApp）

### 概要

- メニューバーに常駐し、グローバルホットキーで Spotlight 風フローティング検索パネルを呼び出せる
- パネルからブックマークをインクリメンタル検索して選択するだけでアプリ・ブラウザタブを前面に表示
- キーボード操作完結（↑↓ で選択、Enter で復元、Esc で閉じる）

### 起動方法

```sh
# デバッグビルドして起動
swift build
.build/debug/FocusBMApp
```

### グローバルホットキー

デフォルトのホットキーは **Cmd+Ctrl+B** です。

YAML の `settings` セクションで変更できます（後述）。

### 必要な権限

アプリ・ブラウザの復元に **アクセシビリティ権限** が必要です。

初回起動時または復元失敗時に、以下の手順で権限を付与してください。

1. システム設定 → プライバシーとセキュリティ → アクセシビリティ
2. `FocusBMApp`（または `.build/debug/FocusBMApp`）を追加してオンにする

> ブラウザタブの復元には System Events / AppleScript 経由でのアクセスが必要なため、アクセシビリティ権限が必須です。

---

## 対応アプリ

- **ブラウザ** — アクティブタブの URL パターン・タイトル・タブインデックスを保存・復元
  - Microsoft Edge, Google Chrome, Brave Browser, Safari, Firefox
- **その他のアプリ** — ウィンドウタイトルを保存し、bundleIdPattern（正規表現対応）でアプリを前面に表示

---

## 必要環境

- macOS 13 (Ventura) 以上
- Swift 6.0 以上
- Xcode（テスト実行時）
- fzf（CLI の `switch` コマンド使用時）

---

## ビルド方法

```sh
# デバッグビルド（CLI + メニューバーアプリ両方ビルドされる）
swift build

# テスト実行
swift test

# リリースビルド
swift build -c release
```

## インストール

### メニューバーアプリ（FocusBMApp.app）

バンドルスクリプトでリリースビルド済みの `.app` バンドルを生成できる。

```sh
# .app バンドルを作成（リリースビルド → FocusBMApp.app 生成）
./scripts/bundle.sh

# /Applications にインストール
cp -r FocusBMApp.app /Applications/

# 起動
open FocusBMApp.app
```

ダブルクリックや `open` コマンドでネイティブアプリとして起動する（ターミナル不要）。

### CLI（focusbm）

```sh
swift build -c release
cp .build/release/focusbm /usr/local/bin/focusbm
```

---

## データ保存先

ブックマークと設定は YAML 形式で以下のパスに保存される。

```
~/.config/focusbm/bookmarks.yml
```

旧形式（V1）の `bookmarks.yml` が存在する場合は、初回読み込み時に自動的に V2 形式へ変換する（元ファイルは `.bak` として保持）。

---

## YAML 手動編集

`~/.config/focusbm/bookmarks.yml` を直接編集することで、正規表現パターンや各種設定が可能。

### ブックマーク定義例

```yaml
bookmarks:
  - id: taskchute
    bundleIdPattern: "^com\\.electron\\.taskchute"
    appName: TaskChute Cloud
    context: work
    state:
      type: app
      windowTitle: ""
    createdAt: "2025-02-18T09:00:00Z"

  - id: github-pr
    bundleIdPattern: com.microsoft.edgemac
    appName: Microsoft Edge
    context: dev
    state:
      type: browser
      urlPattern: "github.com/myorg/pull"
      title: "PR Review"
      tabIndex: 2
    createdAt: "2025-02-18T09:00:00Z"
```

### settings セクション

`bookmarks.yml` に `settings` セクションを追加することで、メニューバーアプリの動作を設定できる。

```yaml
settings:
  hotkey:
    togglePanel: "cmd+ctrl+b"
  displayNumber: 1
  listFontSize: 15.0   # 省略時はシステム標準 .body (≈13pt)

bookmarks:
  - id: ...
```

| キー | 型 | デフォルト | 説明 |
|---|---|---|---|
| `settings.hotkey.togglePanel` | 文字列 | `"cmd+ctrl+b"` | 検索パネルを呼び出すグローバルホットキー |
| `settings.displayNumber` | 整数 | `1` | パネルを表示するディスプレイ番号（1始まり） |
| `settings.listFontSize` | 小数 | `nil`（≈13pt）| 候補リストのフォントサイズ（pt）。省略時はシステム標準サイズ |

### フィールド説明

- **bundleIdPattern** — アプリのバンドル ID を正規表現パターンで指定。`^com\.electron\.taskchute` のように前方一致や完全一致を指定可能
- **urlPattern** — ブラウザのアクティブタブ URL の部分一致パターン
- **tabIndex** — ブラウザのタブインデックス（1始まり）。復元時に `tabIndex` が指定されていれば該当タブへ直接切り替える。`urlPattern` と併用した場合は `tabIndex` を優先しつつ URL で検証し、一致しなければ URL でフォールバック検索する。省略時は `urlPattern` のみで検索

---

## プロジェクト構成

```
focusbm/
├── Package.swift
├── Sources/
│   ├── FocusBMLib/              # 共有ライブラリ（ロジック集約）
│   │   ├── Models.swift         # データモデル・AppSettings
│   │   ├── BookmarkRestorer.swift  # ブックマーク復元ロジック
│   │   ├── AppleScriptBridge.swift # AppleScript / System Events ブリッジ
│   │   └── YAMLStorage.swift    # YAML 読み書き・マイグレーション
│   ├── focusbm/                 # CLI エントリポイント
│   │   └── focusbm.swift
│   └── FocusBMApp/              # メニューバーアプリ
│       ├── FocusBMApp.swift     # AppDelegate・メニューバー常駐
│       ├── SearchPanel.swift    # フローティングパネルウィンドウ
│       ├── SearchView.swift     # SwiftUI 検索 UI
│       ├── SearchViewModel.swift # 検索ロジック・状態管理
│       └── BookmarkRow.swift    # ブックマーク行コンポーネント
└── Tests/
    └── focusbmTests/
```

### 依存ライブラリ

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI サブコマンド定義
- [Yams](https://github.com/jpsim/Yams) — YAML エンコード・デコード

---

## ライセンス

MIT
