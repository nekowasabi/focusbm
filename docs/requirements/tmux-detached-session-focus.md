# tmux detached セッションのフォーカス対応 — 調査結果と実装計画書

作成日: 2026-07-02
ステータス: 実装待ち（本ドキュメントのみで別セッションから着手可能）

## 1. 背景と問題

focusbm の絞り込みパネルは tmux 内の AI エージェントペインを列挙し、選択するとターミナル
アプリのアクティベート + tmux ペインへのフォーカスを行う。しかし **prefix+s（switch-client）で
セッションを切り替えた後、切り替え元セッションにいる AI エージェント**は以下の症状を示す:

1. パネル上でターミナル絵文字が「❓」になる（terminalBundleId が解決できない）
2. 選択してもフォーカスが失敗する、または意図しない動作になる

## 2. 根本原因（調査結果）

### 2.1 tmux の仕様

- tmux のクライアントは**常に 1 セッションにのみアタッチ**する
- prefix+s は「クライアントのアタッチ先セッションを付け替える」操作であり、
  切り替え元セッションは（他クライアントが付いていなければ）**detached** になる
- `tmux list-clients` は**アタッチ中のクライアントしか列挙しない**
  → detached セッションはクライアントマップから完全に消える

実機確認（2026-07-02 時点、この状態がまさに問題の再現状態）:

```
$ tmux list-clients -F '#{client_tty}||#{client_session}||#{client_activity}||#{window_index}||#{pane_id}'
/dev/ttys004||work||1782948682||5||%4
/dev/ttys001||dev-1782775416||1782948501||1||%7
/dev/ttys000||invase-web||1782948542||5||%25

$ tmux list-sessions -F '#{session_name}||attached=#{session_attached}'
dev-1782775416||attached=1
invase-app||attached=0        ← detached。list-clients に一切現れない
invase-web||attached=1
work||attached=1
```

### 2.2 コード上の障害連鎖（すべて `Sources/FocusBMLib/TmuxProvider.swift`）

| # | 箇所 | 何が起きるか |
|---|------|-------------|
| 1 | `buildClientMap()` (:235) / `parseClientMapOutput()` (:259) | `list-clients` ベースなので detached セッションのキー（`"session"` / `"session:windowIndex"`）が作られない |
| 2 | `listAllPanes()` (:360-386) | `clientMap[windowKey] ?? clientMap[pane.sessionName]` が両方ミス → `clientTTY = nil` |
| 3 | `detectTerminalApp()` (:581) | per-session の `list-clients -t session:window` (:608) も detached では空。`terminalAppFromTmuxEnv()` (:559) はセッション環境に TERM_PROGRAM が無いと失敗。全滅すると `terminalBundleId = nil` → 絵文字「❓」 |
| 4 | `focusPane()` (:439-482) | `clientTTY == nil` のため detached パスに入り、`switch-client -t session:window` を **`-c` なし**で実行 (:466-470)。focusbm は tmux 外の GUI アプリなので「current client」が存在せず `no current client` で失敗。`fatalOnFailure: true` のためフォーカス全体が例外で中断 |

つまり「❓ 表示」と「フォーカス失敗」は同一原因（detached セッションにクライアント情報が
割り当てられない）の 2 つの現れである。

### 2.3 既存の解決済み類似問題（参考）

コミット `1bc5bc4`「tmuxペインfocus時にwindow単位でクライアントを解決する」で、
**同一セッション内の別 window** 問題は window キー優先の解決で対応済み。
本件はその一段外側「別セッション（detached）」の問題であり、同じ `switch-client -c`
メカニズムの延長で解決できる。

## 3. 解決方針

**detached セッションのペインに「借用クライアント（fallback client）」を割り当てる。**

- `buildClientMap()` で `#{client_activity}`（epoch 秒、実機で取得可能なことを確認済み）を
  追加取得し、**最も直近に操作されたクライアント**をグローバルフォールバックとして保持する
- window キー・セッションキーが両方ミスしたペインには、フォールバッククライアントの
  tty / bundleId / appName を設定する
- `focusPane()` は **変更不要**。`clientTTY` が入れば既存の attached パス
  `switch-client -c <tty> -t <session>:<window>` → `select-window` → `select-pane`
  がそのまま動く。`switch-client -c` は「そのクライアントのアタッチ先を切り替える」
  コマンドなので、prefix+s と同一の動作になる

```
// Why: 「最前面ターミナルのクライアント優先」ではなく client_activity 最新を採用。
//      理由: ユーザーが最後に触っていたターミナルを乗っ取るのが prefix+s の体感と一致し、
//      NSWorkspace の frontmost 判定と tty の突合という追加コストに見合う体感差がない。
```

### 3.1 仕様上の合意事項（前セッションでの判断）

- **副作用の受容**: detached セッションへのフォーカスは、借用クライアントが表示中の
  セッションを置き換える。これは要望どおり（prefix+s 相当）の動作として受け入れる
- **「❓」の意味変更**: 従来「❓」は復元不能のシグナルだったが、変更後は detached
  セッションでも借用先ターミナルの絵文字が表示される。「フォーカスするとこのターミナルに
  表示される」という意味になる

## 4. 実装計画

変更対象は `Sources/FocusBMLib/TmuxProvider.swift` と `Tests/focusbmTests/` のみ。
`ProcessProvider.swift`（tmux 外プロセス検出）と `focusPane()` は変更しない。
推定差分: 50〜100 行。

### Step 0: 事前確認 → verify: ベースライン緑

- `swift test` が全件パスすることを確認（作業ツリーに未コミット変更あり。§6 参照）

### Step 1: format 文字列に client_activity を追加 → verify: パーサテスト緑（Red→Green）

`buildClientMap()` の `-F` 引数を 7 フィールドに拡張:

```
#{client_tty}||#{client_session}||#{window_index}||#{window_name}||#{pane_id}||#{client_pid}||#{client_activity}
```

`parseClientMapOutput()` を拡張:

- `parts.count >= 7` のとき `activity = Int(parts[6])`（parse 失敗時は 0 扱い）
- 既存の `>= 6` / `>= 3`（legacy）分岐は後方互換のため維持
- `TmuxClientInfo` に `let activity: Int` を追加（legacy 経路では 0）

**テスト（先に書く）**:
- 7 フィールド入力で activity がパースされる
- 6 フィールド（旧形式）入力で activity=0 になり既存挙動が壊れない
- activity が非数値の行でクラッシュせず 0 になる

### Step 2: フォールバッククライアントの選定 → verify: 選定ロジックのテスト緑

`parseClientMapOutput()` 内で、全クライアント行のうち **activity 最大**のものを
フォールバックとして辞書に登録する。

- キーは定数 `static let fallbackClientKey = ":fallback:"` を新設
  ```
  // Why: 戻り値の型を struct に変える案は detectTerminalApp() のシグネチャまで波及するため、
  //      センチネルキー方式を採用。tmux のセッション名は ":" を含められず、
  //      window キー "session:index" も session 空文字を guard 済みのため衝突しない。
  ```
- 同一 activity のタイ: 先勝ち（`>` 比較で更新）で決定的にする

**テスト（先に書く）**:
- 複数クライアント行から activity 最大の行が `fallbackClientKey` に入る
- タイのとき先の行が選ばれる
- クライアント 0 件（空出力）のとき `fallbackClientKey` が存在しない

### Step 3: ペインへの借用クライアント適用 → verify: 解決チェーンのテスト緑

`listAllPanes()` (:367) と `detectTerminalApp()` (:589) のルックアップチェーンを拡張:

```swift
clientMap[windowKey] ?? clientMap[pane.sessionName] ?? clientMap[fallbackClientKey]
```

テスト可能性のため、この 3 段チェーンを純粋関数に抽出することを推奨:

```swift
static func resolveClient(
    sessionName: String, windowIndex: Int,
    clientMap: [String: TmuxClientInfo]
) -> TmuxClientInfo?
```

**注意点**:
- `detectTerminalApp()` 内のフォールバック順序に留意。現状は
  「clientMap ヒット → preferredTerminal → per-session list-clients → 祖先走査 → TERM_PROGRAM env」
  の順。フォールバッククライアント適用は **clientMap ヒットの段階**に組み込む
  （= `clientMap?[windowKey] ?? clientMap?[sessionName] ?? clientMap?[fallbackClientKey]`）。
  これにより preferredTerminal より借用クライアントの実ターミナルが優先される
- `listAllPanes()` の `terminalCache` キーは `mappedClient.map { "client:\($0.tty)" }` 形式
  なので、借用クライアント適用後も自然にキャッシュが効く（変更不要の見込み。要確認）

**テスト（先に書く）**:
- window キーヒット時はそれが最優先（既存挙動の回帰確認）
- セッションキーヒット時は window キーミスでもセッションのクライアントが返る
- 両方ミス時にフォールバッククライアントが返る
- clientMap 空のとき nil（現行挙動維持）

### Step 4: focusPane の経路確認 → verify: focusPaneArgs テスト緑 + 手動確認

コード変更は不要の見込みだが、以下を確認:

- 借用 clientTTY がセットされたペインで `focusPaneArgs()` (:415) が
  `["tmux", "switch-client", "-c", <tty>, "-t", "session:windowIndex"]` を返す
  （既存テストがあれば流用、なければ追加）
- `hasClientTTY == true` の経路 (:460-464) は `fatalOnFailure: false` なので、
  万一 switch-client が失敗しても select-window / select-pane まで進む

### Step 5: 手動検証 → verify: 実機で動作確認

1. `swift build && swift test` 全緑
2. iTerm2 で tmux セッション A に claude を起動 → prefix+s でセッション B に切り替え
   （A が detached になる）
3. focusbm パネルを開き、A 内の claude が **「❓」ではなく iTerm2 の絵文字（🍎）**で
   表示されることを確認
4. その項目を選択 → iTerm2 がアクティベートされ、**クライアントのセッションが A に
   切り替わり**、対象ペインにフォーカスされることを確認
5. 回帰確認: attached セッション内のエージェント（window 違い含む）のフォーカスが
   従来どおり動くことを確認
6. デバッグログ確認: `buildClientMap` のログに fallback 選定が出ること
   （必要なら Step 2 で log 追加）

## 5. スコープ外（今回やらないこと）

| 項目 | 理由 |
|------|------|
| クライアントが 1 つも無い場合（全ターミナル閉鎖等）の改善 | フォールバック不在時は現行挙動（detached パスで失敗）を維持。発生頻度が低く、別課題として切り出す |
| `ProcessProvider.swift`（tmux 外プロセス）の「❓」 | 原因が異なる（TTY→ターミナル解決の問題）。本件は tmux セッションに限定 |
| 「最前面ターミナル優先」の借用クライアント選定 | §3 の Why 参照。activity 最新で十分と判断 |
| detached セッション項目への視覚的マーク（例: 淡色表示） | UX 改善として有用だが要望外。必要なら別途 |

## 6. 実装セッションへの申し送り

- **作業ツリーに未コミット変更あり**（`SearchPanel.swift`, `ProcessProvider.swift`,
  `ShortcutBarTests.swift`, `ProcessProviderTests.swift`）。本件とは別の変更なので、
  着手前に `git status` / `git diff` で内容を確認し、混ざらないようにすること
- テストは `Tests/focusbmTests/`（TmuxProvider 系）に追加。`parseClientMapOutput` /
  `focusPaneArgs` は純粋関数として分離済みで、外部プロセス無しでテスト可能
- コミットメッセージは日本語 + Conventional Commits（例:
  `fix: detachedセッションのペインに直近アクティブクライアントを割り当てる`）
- 検証には本ドキュメント §2.1 の tmux コマンドがそのまま使える
