# focusBM Windows 版 README

この文書は、統合リポジトリ内の focusBM Windows 版の **インストールから動作確認まで** の手順です。macOS 正本は [README.md](./README.md)。設定例は [bookmarks.example.windows.yml](./bookmarks.example.windows.yml)。

Windows 版は以下の 2 つで構成されています。

- `FocusBM.Cli.exe` — ブックマークの追加・一覧・保存・復元を行う CLI
- `FocusBM.App.Wpf.exe` — 常駐 tray + Spotlight 風検索パネルの WPF アプリ

---

## 1. 必要環境

### 実行だけする場合

- Windows 10 / 11
- 通常の対話デスクトップセッション
- `.NET 8 Desktop Runtime`

ただし、self-contained publish を使う場合は .NET Runtime の事前インストールなしでも実行できます。

### 開発・ビルドする場合

- Windows 10 / 11、または WSL/Linux でのクロスビルド
- .NET SDK 8.x

確認:

```powershell
dotnet --version
```

---

## 2. ビルド

リポジトリ直下で実行します。

```powershell
dotnet restore dotnet/FocusBM.sln
dotnet build dotnet/FocusBM.sln
```

自動テスト:

```powershell
dotnet test dotnet/FocusBM.sln
```

期待:

```text
Failed: 0
```

### Makefile を使う場合（WSL/Linux 推奨）

リポジトリ直下の `Makefile` でも同等の操作ができます。既定の `WIN_CONFIG` は `Debug` です。

```powershell
make win-build
make win-test
```

利用可能なターゲット一覧:

```text
help        利用可能なターゲット一覧を表示する
win-restore Windows 版ソリューションの NuGet 依存を復元する
win-build   Windows 版ソリューションをビルドする (win-restore に依存)
win-test    Windows 版の自動テストを実行する (win-build に依存)
win-publish CLI / WPF アプリを win-x64 向けに publish する (framework 依存, artifacts/ 配下)
win-exe     Windows 単体実行 exe を生成する (self-contained/single-file, artifacts/ 配下)
win-clean   Windows 版のビルド生成物を削除する
```

---

## 3. 配布用ファイルを作成する

推奨は付属スクリプトです。

```powershell
.\scripts\windows\publish-focusbm.ps1
```

生成物:

```text
artifacts\focusbm-cli\FocusBM.Cli.exe
artifacts\focusbm-app\FocusBM.App.Wpf.exe
artifacts\dist\focusbm-win-x64-debug.zip
artifacts\dist\focusbm-win-x64-debug.zip.sha256
```

> 注: `publish-focusbm.ps1` は CLI / WPF アプリを `win-x64` 向けに publish します。

単体実行 exe（self-contained / single-file、.NET Runtime 非依存）が欲しい場合は Makefile を使います。

```powershell
make win-exe
```

生成物:

```text
artifacts\focusbm-cli-exe\FocusBM.Cli.exe
artifacts\focusbm-app-exe\FocusBM.App.Wpf.exe
```

---

## 4. YAML 設定ファイル

focusBM は YAML にブックマークを保存します。

既定パスは、以下の優先順位で解決されます。

1. 環境変数 `FOCUSBM_YAML`
2. 実行ファイルと同じディレクトリの `bookmarks.yml`（存在する場合）
3. `%APPDATA%\focusbm\bookmarks.yml`

テスト用に別ファイルを使う場合:

```powershell
$env:FOCUSBM_YAML = "$env:TEMP\focusbm-manual-test.yml"
```

現在の YAML パスを確認:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe where
```

---

## 5. CLI の基本確認

### 5.1 サンプルブックマークを作る

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe sample
```

期待:

```text
sample bookmark written: memo -> notepad
```

### 5.2 一覧表示

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe list
```

期待例:

```text
memo    notepad    manual test notepad
```

### 5.3 追加

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe add docs notepad "work memo"
```

### 5.4 削除

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe delete docs
```

### 5.5 復元

Notepad を起動してから実行します。

```powershell
notepad.exe
.\artifacts\focusbm-cli\FocusBM.Cli.exe restore memo
```

期待:

- Notepad が前面化される
- CLI が `Success` または `Partial` を表示する
- 終了コードが `0`

### 5.6 検索して復元

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe restore-context memo
```

### 5.7 `switch` alias

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe switch memo
```

---

## 6. 現在の前面ウィンドウを保存する

Windows 実機で前面ウィンドウを保存します。

```powershell
notepad.exe
.\artifacts\focusbm-cli\FocusBM.Cli.exe save current-notepad "manual saved notepad"
```

確認:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe list
Get-Content $env:FOCUSBM_YAML
```

---

## 7. CLI 設定

現在の設定:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config get
```

主な設定:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set togglePanel ctrl+shift+f8
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set hotkeyKey F8
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set hotkeyModifiers Control+Shift
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set imeRestoreEnabled true
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set bookmarkListColumns 2
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set openSessionPullRequest ctrl+p
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set forceReloadAgents ctrl+alt+r
```

既定 hotkey は次の通りです。

```text
Ctrl + Alt + Space
```

---

## 8. WPF アプリを起動する

推奨:

```powershell
.\scripts\windows\run-focusbm-app.ps1
```

このスクリプトは以下を行います。

1. publish がなければ publish
2. YAML がなければ sample bookmark を作成
3. `FocusBM.App.Wpf.exe --self-test` を実行
4. 成功したら GUI アプリを起動

手動で起動する場合:

```powershell
$env:FOCUSBM_YAML = "$env:TEMP\focusbm-manual-test.yml"
.\artifacts\focusbm-app\FocusBM.App.Wpf.exe
```

---

## 9. WPF アプリの操作確認

起動後、以下を確認します。

### 9.1 基本表示

- `focusBM` ウィンドウが表示される
- 通知領域に `focusBM` アイコンが表示される
- 検索欄にフォーカスがある

### 9.2 検索

検索欄に入力します。

```text
memo
```

期待:

- `memo` ブックマークが絞り込まれる

### 9.3 キーボード操作

- `Enter` — 選択項目を復元
- `Esc` — ウィンドウを非表示
- `↑ / ↓ / ← / →` — 選択移動
- `Ctrl+P`（設定変更可）— 選択中の Claude Code / Codex の GitHub プルリクエストを開く

### 9.3b 検索フォーカス

ホットキーまたはトレイ「開く」でパネルを出した直後、検索欄にキャレットがあり、クリックなしで文字入力できること。

### 9.3c AI エージェント絵文字

動的 AI 行は次の絵文字で識別できること。

- Claude Code — 🤖
- Codex — 📖
- Grok — 🔫

### 9.4 ショートカットバー

検索欄が空のとき、フッター左に YAML `shortcut:` 付きブックマークのアイコンバーが表示されます。数字バッジはメインリスト側です。

例:

```text
1 memo
```

表示された数字/文字キーを押すと、対応 bookmark を直接 restore します。

### 9.5 2 列表示

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set bookmarkListColumns 2
```

アプリを再読み込み、または再起動します。

期待:

- 結果一覧が 2 列 grid になる
- 左右キーで移動できる

### 9.6 Tray 操作

- × ボタン — 終了せず非表示
- tray icon ダブルクリック — 再表示
- tray menu `開く` — 再表示
- tray menu `再読み込み` — YAML を再読み込み
- tray menu `終了` — アプリ終了

### 9.7 グローバルホットキー

既定:

```text
Ctrl + Alt + Space
```

`bookmarks.yml` で変更できます。

```yaml
settings:
  hotkey:
    togglePanel: "ctrl+alt+space"
```

手順:

1. ウィンドウを非表示にする
2. `Ctrl+Alt+Space` を押す（または YAML で指定したキー）
3. 検索パネルが表示され、検索欄にフォーカスがあることを確認する

設定を変えた場合は、その hotkey を押します。

---

## 10. 自動証跡収集

Windows 実機では、まずこのスクリプトを実行すると便利です。

```powershell
.\scripts\windows\record-manual-evidence.ps1
```

実行内容:

- publish
- CLI smoke
- WPF `--self-test`
- Notepad restore
- foreground save
- OS / session / user / admin 状態の記録

出力:

```text
artifacts\manual-evidence\manual-real-windows-*.json
artifacts\manual-evidence\manual-real-windows-*.md
```

`Status: pass` になることを確認してください。

---

## 11. Chromium CDP を使う場合

CDP は明示 opt-in です。

### 11.1 CDP 用 Chrome / Edge を起動

```powershell
.\scripts\windows\start-chromium-cdp.ps1
```

このスクリプトは:

- 専用 profile を作成
- `.focusbm-cdp-profile` marker を作成
- `--remote-debugging-port=9222`
- `--user-data-dir=<専用 profile>`

で Chrome / Edge を起動します。

### 11.2 focusBM 側に CDP を設定

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config init-cdp "$env:LOCALAPPDATA\focusbm-cdp-profile" http://127.0.0.1:9222
```

確認:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config get
```

期待:

```text
browserCdpEnabled=True
browserCdpEndpoint=http://127.0.0.1:9222
browserCdpRequireKnownBrowserOwner=True
```

CDP の安全条件:

- loopback HTTP endpoint のみ
- 専用 profile marker 必須
- Windows では endpoint port の owner process が既知 browser であること

---

## 12. WSL / tmux を使う場合

WSL/tmux は opt-in です。

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set wslEnabled true
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set wslDistribution Ubuntu
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set wslUser <user>
```

pane 一覧:

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe tmux-list
```

WPF アプリを再読み込みすると、tmux pane が検索対象に追加されます。

対応する AI エージェントは Claude Code、Aider、Gemini、Copilot CLI、Codex、Hermes、OpenCode、Pi、Grok Build です。OpenCode の `serve`、Codex の `app-server` / `mcp-server`、Chrome Native Host は一覧から除外します。Grok Build のバージョン付き実体と Node.js / Python 経由の起動も検出します。

tmux の AI 行には状態記号を表示します。

```text
● 実行中   ⏸ 計画・確認待ち   ⏵ 編集許可待ち   ○ 待機
```

パネル表示中は 3 秒間隔で状態を更新します。`forceReloadAgents`（既定 `Ctrl+Alt+R`）で表示中の一覧を手動更新できます。

選択中の Claude Code / Codex 行は、作業ディレクトリで `gh pr view --json url --jq .url` を実行して PR を解決します。解決済みの行には `#<番号>` を表示し、取得失敗は 5 分間再試行しません。`gh` は WSL 内で利用可能にしてください。

WSL tmux 内の Neovim を復元する場合は、`wslNvim` を使います。`workingDirectory` は完全一致し、`exCommand` は先頭 `:`、改行、NUL を拒否します。

```yaml
- id: project-nvim
  appName: WSL tmux Neovim
  context: work
  state:
    type: wslNvim
    workingDirectory: /home/user/project
    exCommand: write
```

---

## 13. IME 制御

IME 制御は opt-in です。

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set imeRestoreEnabled true
```

有効時:

- 検索パネル表示時に IME を OFF
- パネル非表示 / restore 後に IME 状態を復元

---

## 14. VirtuaWin連携

VirtuaWin 連携は既定で有効です。アプリを前面化するときは、先にそのウィンドウがある VirtuaWin デスクトップへ切り替えます（ブックマーク、Firefox、Windows Terminal、WezTerm、nvim を含む）。VirtuaWin が起動していなければ検出に失敗して通常の前面化だけ行い、全ウィンドウが同一デスクトップにある前提で問題になりません。IPC 自体を止めたいときだけ `virtuawinEnabled: false` にしてください。

```powershell
.\artifacts\focusbm-cli\FocusBM.Cli.exe config set virtuawinEnabled true
```

---

## 15. Release gate

通常 CI smoke:

```powershell
.\scripts\release-evidence-lint.ps1
```

release strict gate:

```powershell
$env:RELEASE_GATE = "1"
.\scripts\release-evidence-lint.ps1
```

strict gate は `artifacts\manual-evidence\manual-real-windows-*.json` を確認します。

---

## 16. トラブルシュート

### hotkey が効かない

- 別アプリと衝突していないか確認
- `config set hotkeyKey ...` で別 hotkey に変更
- アプリを再起動

### restore で前面化されない

- 対象アプリが起動しているか確認
- 管理者権限アプリを通常権限 focusBM から操作していないか確認
- high-integrity target は安全のため暗黙前面化を拒否します
- `bookmarks.yml` と同じフォルダの `focusbm.log` にパネル表示・復元・前面化の結果が追記されます。トレイの「ログを開く」でも参照できます。パスは環境変数 `FOCUSBM_LOG` で変更できます。

### VPN / セキュリティソフトがマルウェアと判定して終了する

未署名の単一ファイル exe と、ホットキー・前面化・ブラウザ起動の組み合わせは誤検知されやすいです。VPN や Defender の除外（許可）に `release/FocusBM.exe` を追加してください。コード署名用の証明書があれば別途署名できます。

### CDP が使えない

- `start-chromium-cdp.ps1` で起動した Chrome / Edge か確認
- endpoint が `http://127.0.0.1:9222` か確認
- profile に `.focusbm-cdp-profile` があるか確認
- owner process が Chrome / Edge か確認

### WSL/tmux が出ない

- `wsl.exe` が使えるか確認
- tmux がインストール済みか確認
- `wslDistribution` / `wslUser` を確認

---

## 17. Linux / WSL 上での注意

Linux / WSL では Windows API が使えないため、以下は `Unsupported` になります。

- foreground activation
- foreground save
- WPF GUI 実行
- tray icon
- global hotkey
- IME control

ただし、ビルド・テスト・Windows 向け publish は WSL/Linux 上でも確認できます。
