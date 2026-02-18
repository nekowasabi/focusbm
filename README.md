# focusbm

macOS アプリフォーカスのブックマークツール。YAML でアプリの切り替え先を定義し、一発で復元できる CLI ツール。

## 機能

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

## 対応アプリ

- **ブラウザ** — アクティブタブの URL パターン・タイトル・タブインデックスを保存・復元
  - Microsoft Edge, Google Chrome, Brave Browser, Safari, Firefox
- **その他のアプリ** — ウィンドウタイトルを保存し、bundleIdPattern（正規表現対応）でアプリを前面に表示

## 必要環境

- macOS 13 (Ventura) 以上
- Swift 6.0 以上
- Xcode（テスト実行時）
- fzf（`switch` コマンド使用時）

## ビルド方法

```sh
# デバッグビルド
swift build

# テスト実行
swift test
```

## インストール

```sh
swift build -c release
cp .build/release/focusbm /usr/local/bin/focusbm
```

## 使い方

### 推奨ワークフロー: YAML 定義 → 復元

`save` コマンドは最前面アプリしか取得できないため、**YAML 手動定義が推奨ワークフロー**です。

#### 1. ブックマークを追加する（`add` コマンド）

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

#### 2. YAML を直接編集する

```sh
# $EDITOR で YAML を開く
focusbm edit
```

#### 3. ブックマークを復元する

```sh
focusbm restore mywork

# fzf で選択して復元
focusbm switch

# コンテキスト内の全ブックマークを一括復元
focusbm restore-context work
```

### 補助: 現在のアプリを保存する（`save` コマンド）

最前面のアプリの状態を素早くブックマークしたい場合に使用できます。ただし、取得できるのは現在フォーカス中のアプリのみです。

```sh
# 現在のフォーカス状態を "mywork" という名前で保存
focusbm save mywork

# コンテキスト（タグ）を指定して保存
focusbm save mywork --context project-a
```

### ブックマーク一覧を表示する

```sh
# 通常表示（コンテキスト別グループ表示）
focusbm list

# コンテキストで絞り込み
focusbm list --context project-a

# fzf と連携（パイプ入力用フォーマット）
focusbm list --format fzf
```

### ブックマークを削除する

```sh
focusbm delete mywork
```

## データ保存先

ブックマークは YAML 形式で以下のパスに保存される。

```
~/.config/focusbm/bookmarks.yml
```

旧形式（V1）の `bookmarks.yml` が存在する場合は、初回読み込み時に自動的に V2 形式へ変換する（元ファイルは `.bak` として保持）。

## YAML 手動編集

`~/.config/focusbm/bookmarks.yml` を直接編集することで、正規表現パターンなどの高度な設定が可能。

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

### フィールド説明

- **bundleIdPattern** — アプリのバンドル ID を正規表現パターンで指定。`^com\.electron\.taskchute` のように前方一致や完全一致を指定可能
- **urlPattern** — ブラウザのアクティブタブ URL の部分一致パターン
- **tabIndex** — ブラウザのタブインデックス（1始まり）。復元時に `tabIndex` が指定されていれば該当タブへ直接切り替える。`urlPattern` と併用した場合は `tabIndex` を優先しつつ URL で検証し、一致しなければ URL でフォールバック検索する。省略時は `urlPattern` のみで検索

## プロジェクト構成

```
focusbm/
├── Package.swift
├── Sources/
│   ├── FocusBMLib/          # ライブラリ（モデル・AppleScript ブリッジ・ストレージ）
│   │   ├── Models.swift
│   │   ├── AppleScriptBridge.swift
│   │   └── YAMLStorage.swift
│   └── focusbm/             # CLI エントリポイント
│       └── focusbm.swift
└── Tests/
    └── focusbmTests/
```

### 依存ライブラリ

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) — CLI サブコマンド定義
- [Yams](https://github.com/jpsim/Yams) — YAML エンコード・デコード

## ライセンス

MIT
