# focusbm 機能拡張 PLAN.md（議論・コメント付き）

> **このファイルの目的**: 各機能提案に対し、設計上の疑問点・リスク・代替案をコメントとして記載し、
> Council審議（ユーザビリティ / 実用性 / カスタマイズ性 / 堅牢性 / 速度）の入力資料とする。
>
> **コメントの読み方**: `> [議論コメント - XXX]` の形式で気になる点を記載。
> 各自コメントを追記する場合は `> [あなたのコメント]` の形式で。

## Context

ユーザーが提案した6つの機能について、コードベース調査結果をもとに実現可能性・実装方針を整理する。
目的は「簡単に使えつつ、YAMLを編集すれば高度な設定ができる」という設計哲学に沿った議論。

**設計哲学の再確認:**
- **シンプルユーザー**: YAMLを最低限だけ書けば動く（bundleIdPatternなしでも可）
- **パワーユーザー**: YAMLを細かく設定すれば、ブラウザタブ・tmuxセッション・AIエージェントまで管理できる

---

## 現状サマリー（コードベース調査結果）

| 機能領域 | 実装ファイル | 現状 |
|---------|------------|------|
| アプリ判定 | `Sources/FocusBMLib/AppleScriptBridge.swift:128-139` | `bundleIdPattern`（正規表現）のみ |
| 検索 | `Sources/FocusBMLib/Models.swift:151-161` | `contains` 部分一致（id/appName/context） |
| ホットキー | `Sources/FocusBMApp/FocusBMApp.swift:85-116` | CGEventTap |
| tmux連携 | なし | V1のiTerm2サポートをV2で廃止 |
| プロセス取得 | `Sources/FocusBMLib/AppleScriptBridge.swift:130-136` | `NSWorkspace.shared.runningApplications` |

**現在のデータモデル（参考）:**
```swift
// Models.swift
public struct Bookmark: Codable, Identifiable {
    public var id: String              // ユーザー指定エイリアス
    public var appName: String         // 表示名のみ（マッチングに未使用）
    public var bundleIdPattern: String // 正規表現対応 Bundle ID（現在必須）
    public var context: String
    public var state: AppState         // .app(windowTitle) or .browser(url, title, tabIndex)
    public var createdAt: Date
}
```

---

## 各機能の分析・提案

### 1. AIと実装したい機能内容を相談
→ 本PLANファイルがこれに相当。以下の機能について議論する。

---

### 2. アプリ名とIdentifierのどっちかでアプリ判定できるようにする

**現状の問題:**
- `bundleIdPattern` が必須フィールドとして機能しており、Bundle IDを知らないとブックマークできない
- `appName` は表示用のみ（`Sources/FocusBMApp/BookmarkRow.swift:60`）

**実装方針（ユーザー確認済み: 自動フォールバック）:**

```yaml
# bundleIdPatternを省略 → appName で自動マッチング
bookmarks:
  - id: my-app
    appName: "My Custom App"   # NSRunningApplication.localizedName と比較
    # bundleIdPattern は省略可能に変更

  - id: chrome
    appName: Google Chrome
    bundleIdPattern: "com.google.Chrome"  # あれば優先使用（より確実）
```

**変更が必要なファイル:**
- `Sources/FocusBMLib/Models.swift`: `bundleIdPattern` を `Optional<String>` に変更
- `Sources/FocusBMLib/AppleScriptBridge.swift:findRunningApp()`: appNameフォールバック追加
- `Tests/focusbmTests/AppSettingsTests.swift`: Optional対応のテスト追加
- **難易度:** ★★☆☆☆（低〜中）、**工数:** 0.5日

> **[議論コメント - ユーザビリティ]**
> - アプリ名の表記揺れ（"Google Chrome" vs "Chrome"）はどう扱うか？ 部分一致か完全一致か？
> - `localizedName` はmacOSのロケール設定に依存。日本語環境では別名になる可能性あり
> - **推奨**: 部分一致（`contains`）でケースインセンシティブ検索。ただし誤マッチのリスクあり

> **[議論コメント - 堅牢性]**
> - 同名アプリが複数ある場合（開発版と本番版のElectronアプリ等）は先頭ヒットになる危険性がある
> - `save`コマンド実行時にbundleIdPatternを自動取得→保存する設計にすれば、ユーザーは後で省略できる

> 指摘: 複数アプリが存在する場合、同名アプリすべての内容を検証し、条件にマッチする場合はそれを利用し、マッチしない場合は、同名アプリの最初のものを利用する、というロジックにするのはどうでしょうか？（例: "Google Chrome" という名前のアプリが複数ある場合、すべてのアプリの `localizedName` を検査し、条件にマッチするものがあればそれを利用し、マッチするものがなければ最初のアプリを利用する）

---

### 3. tmux+AIエージェントのプロセスを取得できるか調査

**技術的実現可能性:**

```swift
// tmuxセッション一覧取得（pane_current_commandでプロセス名が取れる）
let result = try? Process.run("/usr/bin/tmux",
  ["list-panes", "-a", "-F", "#{session_name}:#{window_name}:#{pane_current_command}"])
// 出力例:
//   main:claude:claude
//   main:nvim:nvim
//   work:htop:htop
```

**調査すべき事項:**
1. `pane_current_command` でサブプロセス（claude CLI等）を識別できるか
2. プロセスの応答速度（`Process.run`のオーバーヘッド: 予測50-200ms）
3. tmux未インストール環境でのグレースフルな無効化

**YAML設計案（シンプル〜高度の段階設計）:**
```yaml
bookmarks:
  # シンプル: セッション名固定でアタッチ
  - id: my-work
    appName: iTerm2
    bundleIdPattern: "com.googlecode.iterm2"
    state:
      type: tmux
      sessionName: "main"          # 固定セッション名でアタッチ

  # 高度: AIエージェントを動的に検索
  - id: claude-agent
    appName: WezTerm
    bundleIdPattern: "com.github.wez.wezterm"
    state:
      type: tmux
      paneCommand: "claude"         # このコマンドが動いているペインを自動検索
      windowName: "agent"           # ウィンドウ名でさらに絞り込み（省略可）
```

**変更が必要なファイル:**
- `Sources/FocusBMLib/Models.swift`: `AppState` enum に `.tmux` バリアント追加
- `Sources/FocusBMLib/BookmarkRestorer.swift`: tmux復元ロジック追加
- **難易度:** ★★★☆☆（中）、**工数:** 1-2日

> **[議論コメント - 実用性]**
> - `pane_current_command` は直近のコマンドを返すが、シェル内でclaudeを起動した場合は"bash"や"zsh"になる可能性がある
> - より確実な方法: `pane_current_path` + `ps aux` のPID検索の組み合わせ（ただし複雑化する）
> - **疑問**: ユーザーは「AIエージェントを自動発見して飛ぶ」のか「決まったセッションに素早くジャンプ」するのか？

> 指摘: AIエージェントを開いたtmuxのプロセスは増えたり減ったりするため、設定ファイルで固定するのではなく、動的に取得する形の方が良いのではないでしょうか？（例: `tmux list-panes` の結果から `pane_current_command` が "claude" であるペインを探し、そのペインが属するセッションにアタッチする）

> 指摘: ユーザは「AIエージェントを動的に検索して飛ぶ」ことを望んでいると思います。セッション名を固定するのは、ユーザが自分でtmuxのセッションやウィンドウを管理している場合に限られるのではないでしょうか？ 動的に検索する場合、`paneCommand` だけでなく、`windowName` や `sessionName` もオプションで指定できるようにしておくと、より柔軟に対応できるのではないでしょうか？（例: `paneCommand: "claude"` だけでなく、`windowName: "agent"` や `sessionName: "main"` も指定できるようにする）

> **[議論コメント - カスタマイズ性]**
> - `type: tmux` を新規追加するため `AppState` enum に新バリアントが必要（破壊的変更ではないが）
> - `BookmarkRestorer.swift` にtmux用の復元ロジックが増える（既存のapp/browser分岐に並列）

---

### 4. AIエージェントを起動しているセッションに移動できるか確認

**実装フロー案:**

```
1. tmux list-panes -a -F で claude/aider等のプロセスを検索
2. 該当するセッション名・ウィンドウ名を取得
3. ターゲットのターミナルアプリをアクティブ化
4. tmux switch-client -t <session> or ターミナル固有CLIでペイン移動
```

**ターミナルアプリ別対応（ユーザー指定: iTerm2, WezTerm, Ghostty）:**

| アプリ | 実装方法 | 難易度 | 備考 |
|-------|---------|-------|------|
| **iTerm2** | AppleScript (`select tab`) + `tmux switch-client` | ★★★☆☆ | AppleScript辞書あり |
| **WezTerm** | `wezterm cli list --format json` + `wezterm cli activate-pane` | ★★☆☆☆ | CLIが最も強力 |
| **Ghostty** | `open -a Ghostty` でアクティブ化 + tmux経由のみ | ★★★★☆ | AppleScript非対応 |

**ターミナル別実装イメージ:**
```swift
// WezTerm（CLIが豊富で最も扱いやすい）
// wezterm cli list --format json → pane_id 特定 → wezterm cli activate-pane --pane-id {id}

// iTerm2（AppleScript経由）
// tell application "iTerm2" to select tab whose name contains "claude"

// Ghostty（フォールバック: tmux経由のみ）
// tmux switch-client -t <session> → Ghosttyがフォアグラウンドに来ることを期待
```

- **難易度:** ★★★★☆（高）、**工数:** 2-4日
- **推奨フェーズ分割:**
  1. フェーズ1: tmuxプロセス検出のみ実装（全ターミナル共通）
  2. フェーズ2: WezTerm → iTerm2 の順で固有CLI/AppleScript実装
  3. フェーズ3: Ghostty対応（tmux経由フォールバック）

> **[議論コメント - 実用性]**
> - WezTermはCLIが強力だが、`wezterm`コマンドがPATHに存在する前提。Homebrew経由でも `/usr/local/bin/wezterm` が存在しないケースがある
> - iTerm2の `tmux integration mode` 有効時に挙動が変わる（tmuxウィンドウとiTerm2タブが同期される）
> - **根本的疑問**:「特定のセッションに飛ぶ」のか「AIが動いているペインを自動発見して飛ぶ」のか、主なユースケースはどちら？

> 指摘: まずはtmuxのみを実装する

> 指摘: AIが動いているペインを絞り込み画面に表示して、ユーザが選択したペインに飛ぶ、という形の方が柔軟でわかりやすいのではないでしょうか？（例: `tmux list-panes` の結果から `pane_current_command` が "claude" であるペインをリストアップし、ユーザがその中から選択して飛ぶ）

> **[議論コメント - 堅牢性]**
> - ターミナルが起動していない場合の挙動を定義する必要がある（エラー表示? 自動起動?）
> - 複数モニター環境でGhosttyのウィンドウがどのスクリーンにあるか不明なケースへの対処
> - `wezterm cli` はWezTermが起動していないと失敗する（プロセスチェックが必須）

> 指摘: ターミナルが起動していない場合は絞り込みの候補に表示しない。
> 指摘: tmuxを起動せずに、直接AIえーじぇんとを起動している場合は、アプリにフォーカスするだけで良いのではないでしょうか？（例: `pane_current_command` が "claude" であるペインが見つからない場合、単純にWezTermをアクティブ化する）

---

### 5. プロセスの状態をどれくらいの速度で取得できるか確認

**既存コードの性能特性（予測値）:**

| 方法 | 予測速度 | 用途 |
|------|---------|------|
| `NSRunningApplication.runningApplications(withBundleIdentifier:)` | <1ms | Bundle ID完全一致（高速パス） |
| `NSWorkspace.shared.runningApplications` | 1-5ms | 全アプリ列挙+正規表現マッチ |
| `Process.run("/usr/bin/tmux", ...)` | 50-200ms | tmuxプロセス起動コスト |
| `wezterm cli list` | 20-100ms | WezTermデーモン通信 |
| AppleScript (`osascript`) | 100-500ms | スクリプト実行コスト |

**現在の取得タイミング（問題点）:**
- パネル表示時に `YAMLStorage.load()` でブックマーク読み込みのみ
- 実行中アプリのチェックは**復元時**のみ（一覧に「起動中かどうか」が表示されない）

**実装オプション:**
1. **都度取得（シンプル案）**: パネル表示時のみ実行 → UI表示前に完了すれば許容範囲
2. **NSWorkspace通知活用**: `.didLaunchApplicationNotification` / `.didTerminateApplicationNotification` でキャッシュ更新
3. **バックグラウンドポーリング（tmux用）**: `DispatchQueue.global().asyncAfter` で定期取得 + キャッシュ

**推奨測定コード:**
```swift
// SearchPanel.swift の makeKeyAndOrderFront 前後で計測
let start = CFAbsoluteTimeGetCurrent()
let apps = NSWorkspace.shared.runningApplications
let tmuxPanes = try? Process.run("/usr/bin/tmux", ["list-panes", "-a"])
let elapsed = CFAbsoluteTimeGetCurrent() - start
print("Total fetch: \(elapsed * 1000)ms")
```

- **難易度:** ★★☆☆☆（調査タスク → 結果次第で実装方針が変わる）、**工数:** 0.5日

> **[議論コメント - 実行速度]**
> - tmuxコマンドが200msかかるなら、パネル表示時に同期実行すると体感的に遅い（ショートカット後のラグ）
> - **提案**: tmuxの取得はバックグラウンドで先行実行し、パネル表示時はキャッシュを使う
> - **懸念**: キャッシュが古くなる問題（新規tmuxセッション作成後もリストに出ない）→ ポーリング間隔をYAMLで公開するか？

> 指摘: 頻繁な更新はないため、キャッシュを使用する。ポーリング間隔は1分程度で十分ではないでしょうか？（例: `DispatchQueue.global().asyncAfter(deadline: .now() + 60) { fetchTmuxPanes() }`）

> **[議論コメント - ユーザビリティ]**
> - ブックマーク一覧に「起動中 🟢 / 未起動 ⚫」のインジケーターを出すと実用的だが、リアルタイム更新のコストが必要
> - 現状は起動中かどうか分からないまま選択 → 未起動なら自動起動という設計で問題ないか？

> 指摘: ステータス表示は良いアイデアです。ですが、リアルタイム更新はコストが高いので、ポーリングで更新する形が現実的ではないでしょうか？（例: ブックマークの横に「🟢」や「⚫」を表示し、1分ごとに更新する） 実現している実装が、 ~/repos/tmux-ai-agents-status です。tmuxのペインで動いているAIエージェントの状態を1分ごとに更新して表示しています。 

---

### 6. あいまい検索できるようにする

**現状の限界:** `contains`（部分一致）→ 「ch」で「Chrome」「TaskChute」「Scratch」が全部ヒット。ブックマーク数が増えると絞り込みが不十分

**ユーザー選択: FZF風頭文字マッチ（確認済み）**

```
入力: "tc"
ヒット: ✅ TaskChute（T-askCh-ute → t,c が順番通りに登場）
ヒット: ✅ TweetCraft（T-weet-C-raft）
スキップ: ❌ Chrome（c はあるが t がない）
```

**実装設計（`Sources/FocusBMLib/Models.swift:BookmarkSearcher` 拡張）:**

```swift
// FZF風スコアリング（ライブラリ不要）
public static func fuzzyScore(text: String, query: String) -> Int? {
    let t = text.lowercased()
    let q = query.lowercased()
    var score = 0
    var textIdx = t.startIndex
    var queryIdx = q.startIndex

    while queryIdx < q.endIndex {
        guard let found = t[textIdx...].firstIndex(of: q[queryIdx]) else {
            return nil  // クエリ文字が順番通りに見つからない → マッチしない
        }
        if found == t.startIndex { score += 10 }  // 先頭一致ボーナス
        if found > t.startIndex {
            let prev = t.index(before: found)
            if " -_".contains(t[prev]) { score += 5 }  // 単語区切り直後ボーナス
        }
        score += 1
        textIdx = t.index(after: found)
        queryIdx = q.index(after: queryIdx)
    }
    return score
}

// 既存の filter() をfuzzy対応に置き換え（スコア順ソート付き）
public static func filter(bookmarks: [Bookmark], query: String) -> [Bookmark] {
    guard !query.isEmpty else { return bookmarks }
    return bookmarks
        .compactMap { bm -> (Bookmark, Int)? in
            let texts = [bm.id, bm.appName, bm.context]
            let maxScore = texts.compactMap { fuzzyScore(text: $0, query: query) }.max()
            return maxScore.map { (bm, $0) }
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
}
```

**YAML設定（オプション）:**
```yaml
settings:
  search:
    mode: fuzzy    # "exact" or "fuzzy" (デフォルト: fuzzy)
```

- **難易度:** ★★★☆☆（中）、**工数:** 1日
- **変更箇所**: `Sources/FocusBMLib/Models.swift:151-161`、`Tests/focusbmTests/ModelsTests.swift`

> **[議論コメント - ユーザビリティ]**
> - スコア順ソートにより**毎回順序が変わる**可能性がある
> - 現在の `Cmd+1〜9` ショートカットはリスト順依存 → ファジー検索でリスト順が変わるとショートカットの対象も変わる（混乱の可能性）
> - **提案**: 検索クエリが空のときはオリジナル順を維持し、入力があるときのみスコア順に切り替える

> 指摘: `Cmd+1〜9` のショートカットは、検索クエリが空のときのみ有効にする。クエリが入力されている場合は、ユーザが明示的に選択する形にするのが良いのではないでしょうか？（例: クエリが空のときは `Cmd+1` が最初のブックマークを選択、クエリがあるときはショートカットを無効化してユーザが選択する）

> **[議論コメント - カスタマイズ性]**
> - `mode: exact` でフォールバックできるようにしておくと、ブックマーク数が少ないユーザーにも優しい
> - 将来的にブックマークに「使用頻度」を保存してスコアに加算する拡張も考えられる（今は不要）

> **[議論コメント - 堅牢性]**
> - 日本語アプリ名（例: "タスクシュート"）でも `Character` 単位でマッチするため基本動作する
> - 絵文字が含まれるアプリ名はインデックスがずれる可能性があるが、実用上の影響は軽微

> 指摘: 曖昧検索と併せて https://github.com/oguna/jsmigemo を使えないか？

---

## 優先度・実装順序の推奨

| 優先度 | 機能 | 理由 | 想定工数 |
|-------|------|------|---------|
| ⭐⭐⭐⭐⭐ | アプリ名判定（自動フォールバック） | 使いやすさ直結、破壊的変更なし | 0.5日 |
| ⭐⭐⭐⭐☆ | ファジー検索（FZF風） | UX直結、ライブラリ不要で実装可 | 1日 |
| ⭐⭐⭐☆☆ | プロセス速度計測 | tmux実装前の基礎調査（計測のみ） | 0.5日 |
| ⭐⭐⭐☆☆ | tmux検出調査・基礎実装 | 先に実現可能性確認が必要 | 1-2日 |
| ⭐⭐☆☆☆ | AIセッション移動（ターミナル連携） | tmux調査結果次第、ターミナル依存 | 2-4日 |

**推奨実装フェーズ:**
```
Phase 1 (即実装): アプリ名フォールバック + ファジー検索
Phase 2 (調査):  プロセス速度計測 + tmux基礎調査
Phase 3 (拡張):  tmuxブックマーク型実装 + WezTerm/iTerm2連携
Phase 4 (応用):  Ghostty対応 + 動的AIエージェント検出
```

---

## ユーザー確認済み方針

| 項目 | 決定事項 |
|------|---------|
| ターゲットターミナル | **iTerm2, WezTerm, Ghostty** の3種 |
| ファジー検索 | **FZF風頭文字マッチ**（"tc" → "TaskChute"）|
| アプリ名判定 | **自動フォールバック**（`bundleIdPattern`省略 → `appName`でマッチ）|

## 残未確認事項

1. **AIエージェントの定義**: `claude`, `aider`, `cursor`? どのプロセス名をAIエージェントとして識別するか？ YAML で設定可能にする？
   - 例: `settings.aiAgentCommands: ["claude", "aider", "cursor", "codex"]`

> 指摘: gemini, agent, copilotを追加してください

---

## Council審議のための論点整理

> **審議軸: ユーザビリティ / 実用性 / カスタマイズ性 / 堅牢性 / 実行速度**

### 論点A: 段階的な複雑さの設計は適切か（ユーザビリティ × カスタマイズ性）
- Phase1（アプリ名フォールバック + ファジー検索）だけでも「簡単に使えるブックマーク」として成立するか？
- tmux/AIエージェント機能を追加するとYAMLが複雑化する。シンプルユーザーへの影響は？
- **賛成観点**: `bundleIdPattern`省略可能 + `type: tmux`はオプションなので既存ユーザーに影響なし
- **反対観点**: ドキュメントやエラーメッセージが複雑化する。`type: tmux`が失敗した時のメッセージは？

### 論点B: tmux依存は適切か（実用性 × 堅牢性）
- tmuxを使っていないユーザーが多い場合、tmux機能は「高度ユーザー向けオプション」として正当化されるか？
- tmuxなしでも「ターミナルアプリ＋ウィンドウタイトルマッチ」で代替できるか？（既存V1 iTerm2方式の復活）
- **懸念**: tmuxのパス（`/usr/bin/tmux` vs `/opt/homebrew/bin/tmux`）が環境依存

### 論点C: プロセス取得速度のトレードオフ（実行速度 × ユーザビリティ）
- パネル表示のレイテンシ目標は何ms？（目安: 100ms以下なら知覚なし、300ms以上は遅く感じる）
- tmuxコマンドが200msかかる場合、バックグラウンド事前取得は必須か？
- バックグラウンドポーリングはバッテリー消費・CPU使用率に影響するか？

### 論点D: ファジー検索のスコア順ソートはCmd+1〜9と干渉するか（堅牢性）
- 検索中にCmd+1が指す対象がフィルタ前後で変わる問題
- 解決策候補: ①空クエリ時のみ固定順（現状維持）、②Cmd+1〜9は非推奨にしてEnterのみに統一

### 論点E: WezTerm/Ghostty対応は現実的か（実用性 × 実行速度）
- `wezterm cli`は強力だがWezTermが起動していないと失敗する
- Ghosttyは事実上tmux経由しかない → Ghosttyユーザーはtmux必須になる
- 対応表明だけして実装は後回し（スタブ実装）は許容されるか？

---

## 指摘事項の要件整理・妥当性検討（コードベース調査結果）

> **調査日**: 2026-02-28
> **調査ファイル**: Models.swift, AppleScriptBridge.swift, BookmarkRestorer.swift, SearchPanel.swift, SearchViewModel.swift

### コードベース現状サマリー

| ファイル | 現状の制約 |
|---------|-----------|
| `Models.swift` | `bundleIdPattern: String`（必須）、AppState は `.browser/.app/.floatingWindows` の3バリアント |
| `AppleScriptBridge.swift:128-139` | bundleIdPattern のみでマッチング（完全一致 → 正規表現の2段階）|
| `BookmarkRestorer.swift` | state による switch 分岐、`.app` は `activateApp` のみ呼ぶ |
| `SearchPanel.swift:69-80` | Cmd+1-9 は `searchItems.count` ベース（クエリ変更でインデックスがずれる）|
| `SearchViewModel.updateItems()` | インライン `contains` フィルタ（BookmarkSearcher.filter は UI 未使用） |

---

### 機能2: アプリ名フォールバック — 確定要件

```
findRunningApp の拡張ロジック:
1. bundleIdPattern がある → 既存ロジック（完全一致 → 正規表現）
2. bundleIdPattern が nil → appName で全アプリを検索
   - localizedName に対して contains（case insensitive）
   - 同名複数アプリが存在する場合:
     a. 追加条件（windowTitle 等）を満たすものを優先
     b. 条件マッチがなければ first を利用
```

**変更ファイル:**
- `Models.swift`: `bundleIdPattern: String?` に Optional 化
- `AppleScriptBridge.swift:findRunningApp()`: appName フォールバック追加
- `BookmarkRestorer.swift`: bundleIdPattern が nil の場合の処理追加
- `Tests/focusbmTests/AppSettingsTests.swift`: Optional 対応テスト

**妥当性:** ✅ 低リスク（既存 YAML との後方互換性あり）

---

### 機能3+4: tmux 動的検出 + AI セッション移動 — 確定要件

```yaml
# YAML 設計（指摘反映後）
- id: claude-agent
  appName: WezTerm
  state:
    type: tmux
    paneCommand: "claude"   # nil の場合は全ペイン対象
    windowName: "agent"     # オプション絞り込み（省略可）
    sessionName: "main"     # オプション絞り込み（省略可）
```

**動作フロー（確定）:**
1. `tmux list-panes -a -F "#{session_name}:#{window_name}:#{pane_current_command}:#{pane_id}"` 実行
2. `paneCommand` でフィルタ（指定時）
3. `windowName`/`sessionName` で追加絞り込み（指定時）
4. 候補複数 → SearchPanel に候補リストを表示してユーザーが選択
5. 候補1つ → 直接移動
6. 候補0（tmux なし or 条件不一致）→ ターミナルアプリをアクティブ化するだけ

**AI エージェントコマンド一覧（YAML設定）:**
```yaml
settings:
  aiAgentCommands:
    - claude
    - aider
    - cursor
    - codex
    - gemini
    - agent
    - copilot
```

**変更ファイル:**
- `Models.swift`: `AppState.tmux` バリアント追加
- `BookmarkRestorer.swift`: `.tmux` ケース追加
- `Sources/FocusBMLib/TmuxBridge.swift`（新規）: `listPanes()`, `switchToPane()` 実装
- `SearchViewModel.swift`: tmux 候補が複数の場合のリスト表示ロジック

**妥当性:** ⚠️ 中程度リスク（`pane_current_command` はシェル内プロセスを検出できない問題あり）

---

### 機能5: プロセス状態取得速度 — 確定要件

```
キャッシュ戦略（指摘反映後）:
  - tmuxペイン情報: 1分間キャッシュ（DispatchQueue.global でポーリング）
  - アプリ起動状態: NSWorkspace 通知（didLaunchApp/didTerminateApp）でキャッシュ更新
  - ステータスインジケーター: 🟢（動作中）/ ⚫（未検出）をブックマーク横に表示
```

**変更ファイル:**
- `SearchViewModel.swift`: `ProcessStatusCache` 追加（tmux ポーリング）
- `BookmarkRow.swift`: 🟢/⚫ インジケーター表示

**妥当性:** ✅ 実装可能（バッテリー消費ほぼゼロ）

---

### 機能6: ファジー検索 — 確定要件

```
Cmd+1-9 挙動変更（指摘反映後）:
  - query が空 → 従来通りインデックスで選択
  - query あり → Cmd+1-9 を無効化（Enter のみで選択）

jsmigemo 検討結果:
  → Swift/macOS ネイティブには移植困難（JS ライブラリのため）
  → ローマ字→日本語変換は対応しない（Noticed but not fixed）
```

**変更ファイル:**
- `Models.swift`: `BookmarkSearcher.fuzzyScore()` 追加、`filter()` 置き換え
- `SearchViewModel.updateItems()`: `BookmarkSearcher.filter` を使うよう統一（重複解消）
- `SearchPanel.swift:69-80`: query 空のときのみ Cmd+1-9 有効化
- `Tests/focusbmTests/ModelsTests.swift`: fuzzy テスト追加

**妥当性:** ✅ ライブラリ不要で実装可能

---

### 確定実装順序

| Phase | 機能 | 工数 |
|-------|------|------|
| Phase 1 | アプリ名フォールバック | 0.5日 |
| Phase 1 | ファジー検索 + Cmd+1-9 挙動修正 | 1日 |
| Phase 2 | プロセス状態キャッシュ + インジケーター | 0.5日 |
| Phase 3 | tmux 動的検出 + AI セッション移動 | 2日 |

### 非対応決定事項

| 項目 | 理由 |
|------|------|
| jsmigemo | Swift 移植コスト高、JS ライブラリのため |
| WezTerm/iTerm2 固有 CLI | tmux 経由で代替可能、Phase 3 以降に先送り |

---

## 検証方法

- アプリ名判定: `swift run focusbm save` + `bundleIdPattern`省略でブックマーク保存 → `focusbm restore` で復元確認
- ファジー検索: `Tests/focusbmTests/ModelsTests.swift` にユニットテスト追加
- tmux調査: `Process.run("/usr/bin/tmux", ["list-panes", "-a"])` の実行結果・速度を確認
- 速度計測: `SearchPanel.swift` の `makeKeyAndOrderFront` 前後でCFAbsoluteTimeGetCurrent計測
