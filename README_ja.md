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
AIエージェントプロセス一覧の強制再取得は **Cmd+Ctrl+R**、選択中のClaude Codeセッションに記録されたGitHubプルリクエストを開く画面内キーは **Cmd+P** です。

YAML の `settings` セクションで変更できます（後述）。
プルリクエスト操作は、選択中のClaude Codeプロセスまたはtmuxペインの作業ディレクトリで `gh pr view --json url --jq .url` を実行して解決します。実行できない場合は、セッション索引にある構造化済みの `prUrl` へフォールバックします。PRが見つからない場合、データが不正な場合、URLが競合する場合は何も開きません。Codexは、PIDとセッションおよびセッションとプルリクエストを結ぶ安定契約を確認するまで無効です。

### 必要な権限

アプリ・ブラウザの復元に **アクセシビリティ権限** が必要です。

初回起動時または復元失敗時に、以下の手順で権限を付与してください。

1. システム設定 → プライバシーとセキュリティ → アクセシビリティ
2. `FocusBMApp`（または `.build/debug/FocusBMApp`）を追加してオンにする

> ブラウザタブの復元には System Events / AppleScript 経由でのアクセスが必要なため、アクセシビリティ権限が必須です。

---

## 対応アプリ

- **ブラウザ** — アクティブタブの URL パターン・タイトル・タブインデックスを保存・復元
  - Microsoft Edge, Google Chrome, Brave Browser, Safari — URL でのタブ検索・切り替え対応
  - Firefox — **`tabIndex` 指定時のみ** Cmd+N ショートカット経由でタブ切り替え（後述）
- **その他のアプリ** — ウィンドウタイトルを保存し、bundleIdPattern（正規表現対応）でアプリを前面に表示
- **floating window アプリ** — Cmd+Tab に表示されない LSUIElement アプリ（Alter など）の floating window を実行時に動的列挙して切り替え
- **iTerm2 + tmux + Neovim** — `type: itermNvim` で一致する `nvim` ペインを前面化し、固定 Ex コマンドを 1 回送る。iTerm2 専用。詳細は後述。

---

## 必要環境

- macOS 13 (Ventura) 以上
- Swift 6.0 以上
- Xcode（テスト実行時）
- fzf（CLI の `switch` コマンド使用時）
- GitHub CLI（`gh`、PRの解決に使用）

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

  - id: slack-inbox
    bundleIdPattern: com.google.Chrome
    appName: Google Chrome
    context: work
    state:
      type: browser
      urlPattern: "https://app.slack.com/client/T0APA1XEE/activity-inbox"
      title: "Slack"
      urlPrefix: "https://app.slack.com/client/T0APA1XEE"  # 省略可能
    createdAt: "2025-02-18T09:00:00Z"

  - id: rarely-used
    appName: SomeApp
    bundleIdPattern: com.example.someapp
    context: work
    noShortcut: true   # ⌘1-9 のバッジを付けない（後続アイテムの番号は詰める）
    lowPriority: true  # クエリなし時にリスト下部に表示
    state:
      type: app
      windowTitle: ""
    createdAt: "2025-01-01T00:00:00Z"
```

### settings セクション

`bookmarks.yml` に `settings` セクションを追加することで、メニューバーアプリの動作を設定できる。

```yaml
settings:
  hotkey:
    togglePanel: "cmd+ctrl+b"
    forceReloadAgents: "cmd+ctrl+r"
    openSessionPullRequest: "cmd+p"
  displayNumber: 1
  listFontSize: 15.0   # 省略時はシステム標準 .body (≈13pt)
  directNumberKeys: true  # 数字キー単体でブックマークにフォーカス（false: Cmd+数字のみ）
  showAIAgentShortcut: true # AI エージェント行（aiProcess / tmux ペインの AI）に番号を振る（false で非表示）

bookmarks:
  - id: ...
```

| キー | 型 | デフォルト | 説明 |
|---|---|---|---|
| `settings.hotkey.togglePanel` | 文字列 | `"cmd+ctrl+b"` | 検索パネルを呼び出すグローバルホットキー |
| `settings.hotkey.forceReloadAgents` | 文字列 | `"cmd+ctrl+r"` | AIエージェントプロセス一覧を強制再取得するグローバルホットキー |
| `settings.hotkey.openSessionPullRequest` | 文字列 | `"cmd+p"` | 選択中Claude Codeセッションの構造化済みGitHubプルリクエストURLを開く画面内キー。不正値・予約キーは既定値へ戻る |
| `settings.displayNumber` | 整数 | `1` | パネルを表示するディスプレイ番号（1始まり） |
| `settings.listFontSize` | 小数 | `nil`（≈13pt）| 候補リストのフォントサイズ（pt）。省略時はシステム標準サイズ |
| `settings.directNumberKeys` | 真偽値 | `true` | `true`: 数字キー単体でブックマークにフォーカス。`false`: Cmd+数字のみ |
| `settings.showAIAgentShortcut` | 真偽値? | `nil`（= `true` 相当） | `true`/未指定: AI エージェント行（`aiProcess` と tmux ペインの AI エージェント）にも ⌘1–⌘9 番号を振る（現行動作）。`false`: AI エージェント行には番号を振らず、ブックマーク側の番号が 1,2,3... と詰まる。数字キーによるジャンプも AI 行には効かなくなる |

### フィールド説明

- **bundleIdPattern** — アプリのバンドル ID を正規表現パターンで指定。`^com\.electron\.taskchute` のように前方一致や完全一致を指定可能
- **urlPattern** — ブラウザのアクティブタブ URL の部分一致パターン
- **tabIndex** — ブラウザのタブインデックス（1始まり）。復元時に `tabIndex` が指定されていれば該当タブへ直接切り替える。`urlPattern` と併用した場合は `tabIndex` を優先しつつ URL で検証し、一致しなければ URL でフォールバック検索する。省略時かつ `urlPattern` が設定されている場合は `open location` で URL を直接開く（`https://` プレフィックスが自動補完される）。`urlPattern` も未設定の場合はアプリをアクティブ化するだけ
- **urlPrefix** — （省略可能）このプレフィックスで始まる URL のタブが既に開いていれば、新規タブを開かずそのタブにスイッチする。Slack のようにページ・チャンネルごとに URL が変わるアプリに有効。省略時は従来通り `urlPattern` で検索する
- **noShortcut** — （省略可能）`true` にすると、そのアイテムに ⌘1–⌘9 のショートカットバッジを表示しない。後続アイテムの番号は詰めて割り当てられる。省略または `false` で通常通り
- **lowPriority** — （省略可能）`true` にすると、クエリなし時にリストの下部に移動する。クエリあり時はスコア順に表示される（他のアイテムと同様）。省略または `false` で通常通り

### Firefox を使う場合の注意事項

Firefox は AppleScript の「タブ列挙・URL 検索」API（`tabs of windows`）を持たないため、Chrome/Safari とは動作が異なります。

| 条件 | 動作 |
|------|------|
| `tabIndex` あり | Cmd+N ショートカットを System Events 経由で送信し、N 番目のタブへジャンプ |
| `tabIndex: 9` 以上 | Cmd+9（最後のタブ）へジャンプ（Firefox 公式仕様） |
| `tabIndex` なし / `urlPattern` あり | `open location` で URL を新タブで開く（`https://` が自動補完される） |
| `tabIndex` なし / `urlPattern` なし | Firefox をアクティブ化するだけ（タブ切り替えなし） |

**Firefox ブックマークの推奨設定:**

```yaml
- id: github
  appName: Firefox
  bundleIdPattern: org.mozilla.firefox
  context: dev
  state:
    type: browser
    urlPattern: github.com   # 参考情報として記述（検索には使われない）
    title: GitHub
    tabIndex: 3              # 左から何番目のタブか（1始まり）を指定
  createdAt: "2025-01-01T00:00:00Z"
```

> **注意**: `tabIndex` はタブの位置が変わると機能しなくなります。常に同じ位置に固定して使うか、ピン留めタブとして固定することを推奨します。

### floating window アプリ（Alter など）

Cmd+Tab に表示されない LSUIElement アプリの floating window をパネルから切り替えたい場合は `type: floatingWindows` を使います。ウィンドウタイトルはアプリ起動時に自動取得されるため YAML への記述は不要です。

```yaml
- id: alter
  appName: Alter            # アプリ名（CGWindowList のマッチに使用）
  bundleIdPattern: ""       # bundleId 不要
  context: tools
  state:
    type: floatingWindows   # 実行時に動的列挙
  createdAt: "2025-01-01T00:00:00Z"
```

パネルを開いた時点で存在する floating window が候補として表示されます（例: `Alter - Search the web - Hello`）。

### iTerm2 + tmux + Neovim（`type: itermNvim`）

**iTerm2 上**の tmux 内 Neovim ペインだけを前面化し、固定の Ex コマンドを一度だけ送ります。旧 V1 の `type: iterm2` ではありません（それは今も `type: app` へ移行されます）。

```yaml
- id: project-nvim
  appName: iTerm2
  bundleIdPattern: com.googlecode.iterm2
  context: work
  state:
    type: itermNvim
  createdAt: "2026-08-15T00:00:00Z"
```

| フィールド | 規則 |
|---|---|
| `workingDirectory` | 省略可。省略時は iTerm2 の最初の `nvim` ペイン。絶対パスを書いたときだけそのペインを優先する。マシン固有のフルパスは不要。 |
| `exCommand` | 省略可。指定するなら先頭 `:` なしの一行。省略・空はフォーカスのみ。先頭 `:`、CR、LF、NUL は拒否。 |

**候補になる条件:**

- `pane_current_command` がちょうど `nvim`（`vim` やラッパーは対象外）
- tmux クライアントが iTerm2（`com.googlecode.iterm2`）

複数候補があるときは、1 回の tmux `list-panes` 列挙の先頭だけを使う。そのあと対象 TTY で pane ID を切り替え、`#{pane_id}` を再読し、TTY が一致する iTerm2 session がちょうど 1 件のときだけ window → tab → session の順で選択し、Esc を 1 回、続けて `:` + `exCommand` + Enter を 1 回送る。

**次の場合はコマンドを送らない:**

- 適格ペインがない、iTerm2 以外、TTY が空または不明
- 同一 TTY の iTerm2 session が 0 件または 2 件以上
- tmux の切替・検証に失敗した
- FocusBM → iTerm2 の Automation が拒否された、または Apple Event がタイムアウトした（5 秒）

この経路に Accessibility / System Events は不要。必要なのは FocusBM が iTerm2 を操作する **Automation** 許可だけ（システム設定 → プライバシーとセキュリティ → オートメーション）。他ターミナル、tmux 外の Neovim、任意入力は対象外。

---

## tmux 連携

focusbm は tmux ペイン内で実行中の AI エージェントを検出し、検索パネルからフォーカスできます。

tmux ペインをフォーカスするときは、対象の session/window を表示中の tmux client を優先し、その client tty に対して `switch-client -c` を実行します。window 単位の client が見つからない場合は、session 単位の client、既存のターミナル検出の順にフォールバックします。

`settings.preferredTerminal` は表示と起動先のフォールバックであり、tmux から取得済みの client tty を上書きしません。ターミナルアプリを前面化した後に特定のウィンドウが必ず最前面になるかは macOS と各ターミナルの挙動に依存します。

### サポート対象 AI エージェント

- Claude Code (`claude`)
- Aider (`aider`)
- Gemini (`gemini`)
- Hermes (`hermes`)
- OpenCode (`opencode`)
- Pi (`pi`)
- Grok Build (`grok`)

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
│   │   ├── FloatingWindowProvider.swift # LSUIElement アプリの floating window 列挙
│   │   └── YAMLStorage.swift    # YAML 読み書き・マイグレーション
│   ├── focusbm/                 # CLI エントリポイント
│   │   └── focusbm.swift
│   └── FocusBMApp/              # メニューバーアプリ
│       ├── main.swift           # エントリポイント
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
