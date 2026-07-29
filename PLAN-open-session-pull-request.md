---
task_id: "T-20260729-open-session-pull-request"
title: "選択中AIエージェントのGitHubプルリクエストを開く"
status: planning
created: "2026-07-29"
scope:
  - "Claude Codeおよび安定したローカル契約を確認できたCodexのAIエージェント行から、セッションに記録されたGitHubプルリクエストを既定ブラウザで開く"
  - "bookmarks.ymlで画面内ショートカットを変更可能にする"
  - "セッション索引の読み取りとキー判定を単体テスト可能な純粋ロジックへ分離する"
risk_flags:
  - "external-format-dependency"
  - "filesystem-io"
  - "keyboard-shortcut-conflict"
quality_gate:
  command: "swift test"
commit_mode: manual
light_mode: true
---

# Commander's Intent

## Purpose

絞り込み画面でClaude CodeまたはCodexのAIエージェントプロセスを選択中に、既定値 `cmd+p` の画面内ショートカットを押すと、その実行セッションに記録されたGitHubプルリクエストを既定ブラウザで開けるようにする。CodexはPIDとセッション、およびセッションとプルリクエストURLを結ぶ安定契約を確認できた場合だけ有効化する。

## End State

- 選択中の `.aiProcess` がClaude Codeまたは有効化済みCodexセッションに厳密に対応し、そのセッションに有効なプルリクエストURLがある場合のみブラウザで開く。
- 対応セッション、`prUrl`、選択中AIエージェントのいずれかが無い場合は外部動作を起こさず、既存の選択・実行・入力動作を壊さない。
- `~/.config/focusbm/bookmarks.yml` の `settings.hotkey.openSessionPullRequest` でショートカットを変更でき、省略時は `cmd+p` を使う。
- ファイル形式の解析、PIDとセッションの対応付け、URL選択、キー照合は自動テストで判定できる。

## Key Tasks

- エージェント別の解決器を追加し、Claude CodeのPIDからセッションIDとプルリクエストURLを解決する。Codex解決器は安定契約を検証し、未確認・競合時は `nil` を返す。
- `HotkeySettings` に画面内アクション用ショートカットを後方互換で追加する。
- `SearchPanel` のローカルキーモニタに、選択中項目を対象とするブラウザ起動処理を追加する。
- 正常系、欠損・破損データ、非対象項目、設定変更、既存ショートカット競合をテストする。
- 設定例とREADMEを更新する。

---

# ★ Constants（唯一の正・他は定数名で参照）

| 定数名 | 値 | 単位 | 備考 |
|-------|-----|------|------|
| `DEFAULT_OPEN_PR_HOTKEY` | `cmd+p` | キー表現 | `HotkeySettings` の省略時既定値 |
| `CLAUDE_SESSION_REGISTRY_DIR` | `~/.claude/sessions` | パス | `<pid>.json` に `pid`, `sessionId`, `cwd` がある |
| `CLAUDE_PROJECTS_DIR` | `~/.claude/projects` | パス | 配下の `sessions-index.json` を探索する |
| `PR_URL_FIELD` | `prUrl` | JSONキー | 同一 `sessionId` の索引エントリから取得する |
| `CODEX_SESSIONS_DIR` | `~/.codex/sessions` | パス | `session_meta.payload.id` と `cwd` を持つロールアウトJSONLがある。PID対応と正規PR URLフィールドは未確認 |
| `SUPPORTED_PR_HOST` | `github.com` | ホスト名 | GitHubプルリクエストURLだけを開く |

---

# Scope

**対象**:

- `Sources/FocusBMLib/Models.swift` の設定モデルとショートカット解析の再利用
- エージェント別解決器によるClaude Codeセッション登録ファイル・セッション索引の読み取り
- CodexのPID→ロールアウトIDと正規PR URL契約の検証、および契約成立時のCodex解決器
- `Sources/FocusBMApp/SearchPanel.swift` のローカルキー処理
- 選択中の `SearchItem.aiProcess` から `ProcessProvider.AIProcess.pid` を使う解決経路
- `Tests/focusbmTests` と `Tests/FocusBMAppTests` の単体テスト
- `bookmarks.example.yml`, `README.md`, `README_ja.md` の設定説明

**対象外（理由付き）**:

- Gemini、Aider等のセッションとプルリクエストの対応付け — 安定したPID→セッションID→プルリクエストURLのローカル契約を確認できていないため
- 安定契約を確認できないCodex環境での推測対応 — cwd、Gitブランチ、更新時刻だけでは並行セッションを区別できず、別セッションのプルリクエストを開くため
- GitHub APIや`gh pr view`によるブランチ単位のプルリクエスト検索 — 「セッションに紐付けられた」値ではなくなり、ネットワーク・認証・複数プルリクエスト選択の責務が増えるため
- プルリクエストURLの生成・セッション索引への書き込み — Claude Code側が生成するデータの読み取り機能に限定するため
- 行内へのプルリクエスト有無アイコン表示 — ユーザー要求に含まれず、一覧更新時のファイル探索コストも増えるため
- ブックマーク単位の `shortcut` 契約変更 — 今回は画面アクション用の `settings.hotkey` であり、項目実行用ショートカットとは責務が異なるため

---

# Assumptions / Open Questions（外部挙動に影響する未決定事項）

| 種別(Assumption/Open Question) | 項目 | 内容 | 外部挙動への影響 | 解決方針(誰がいつ決めるか) |
|------|------|------|----------------|------------------------|
| Assumption | 対象エージェント | 初回対応はtmux外の `claude` と、下記2契約を確認できた `codex` に限定する | tmux内や未確認のCodex環境、他エージェントでは発動しない | 実装時に解決器登録とテストで固定する |
| Assumption | 紐付け元 | `~/.claude/sessions/<pid>.json` の `sessionId` と `~/.claude/projects/**/sessions-index.json` の同一 `sessionId` エントリを正とする | 同一作業ディレクトリ・ブランチの別セッションのプルリクエストを誤って開かない | 実装時にPID厳密一致をテストする |
| Assumption | 複数候補 | 同一セッションIDが複数索引に見つかった場合、有効な `prUrl` を持つ候補が1件なら採用し、異なるURLが複数なら安全側で何も開かない | 誤ったプルリクエストを開くことを防ぐ | 実装時に重複・競合テストで固定する |
| Assumption | パネル挙動 | URLを開く直前にパネルを閉じる | `NSWorkspace.open` によるブラウザ切替後、浮動パネルを残さない | `executeItem` と同じ「操作確定後に閉じる」方針で実装する |
| Assumption | 無効ショートカット | YAML値を解析できない場合は既定値へ戻す | 設定ミスで機能全体が失われない | 既存 `HotkeyParser` の失敗を検出し警告、`DEFAULT_OPEN_PR_HOTKEY` を使う |
| Open Question | Codexセッション識別 | 選択したCodex PIDを単一の `session_meta.payload.id` へ結ぶ公式または実測で安定した契約は何か | 未解決のままcwd・ブランチ・更新時刻で選ぶと別セッションを誤採用する | 実装前に同一cwdの並行Codex CLIで検証し、一意性を証明できなければCodex解決器を有効化しない |
| Open Question | Codexの正規PR URL | Codexのセッションに紐づく正規プルリクエストURLを表す構造化フィールドまたは明示的な外部索引は何か | JSONL本文には会話例・レビューURL・ツール出力が混在し、単純抽出できない | Codexの公式契約または専用索引を確認する。通常メッセージと汎用ツール出力は情報源にしない |
| Open Question | Codex実行形態 | Codex CLIとCodex Desktop / IDE拡張で同じセッション契約を使えるか | 実行形態によって有効・無効が変わる | 初回は契約を実測できたCLI形態だけに限定し、Desktop / IDE拡張は別途検証する |

---

# 実装ステップ

## Step 0: Codexのセッション・プルリクエスト契約を検証

- **概要**: Codex対応を有効化する前に、選択PID→ロールアウトIDと、ロールアウトID→正規プルリクエストURLの2契約を読み取り専用で検証する。
- **変更ファイル**: 契約検証時は変更なし。契約成立後に `Tests/focusbmTests/Fixtures/CodexSessions/` へ最小匿名化フィクスチャを追加する
- **参照する定数**: `CODEX_SESSIONS_DIR`, `SUPPORTED_PR_HOST`
- **実装メモ**:
  - 実測したロールアウト先頭の `session_meta.payload` には `id`, `session_id`, `cwd` があり、ローカルSQLiteの `threads.id` と一致する。一方、SQLiteと `session_meta` にPIDおよび正規PR URLの専用列は確認できていない。
  - `CODEX_THREAD_ID` はCodexが起動するツール環境へ渡るが、FocusBMが選択するCodex親プロセスの環境から取得できる契約とはみなさない。
  - 同一cwdで2つのCodex CLIを並行起動し、PIDから各ロールアウトIDを交差なく特定できる候補を検証する。cwd、Gitブランチ、開始・更新時刻だけの候補は不採用とする。
  - PR URLは公式の構造化セッションフィールドまたはFocusBM向け明示索引だけを採用候補とする。JSONLの通常メッセージ、ユーザー入力、汎用ツール出力、レビュー取得結果は候補にしない。
  - 2契約のいずれかが成立しない場合、Codex解決器は常に `nil` を返す閉じた実装とし、Claude Code対応を妨げない。
- **依存 Step**: -
- **振る舞い仕様**（System Type: integration gate）:
  - 同一cwdの並行Codex CLI → 各PIDが異なる正しいロールアウトIDへ一意に対応することを証明できる
  - 対応候補が0件または複数 → 契約不成立
  - セッション内に例示・レビュー・ツール出力のPR URLしかない → 正規PR URL無し
  - **Correctness Criteria**: cwd・ブランチ・更新時刻による推測なしで、PIDと正規PR URLを単一セッションへ再現可能に対応付けられる
  - **Left to Implementation**: 契約成立時の索引形式と取得方法。実測前に固定しない
- **テスト**: `session_meta`正常・破損、PID対応無し、複数ロールアウト競合、正規PRフィールド無し、会話・ツール出力のPR URL無視を追加する。
- **Manual Verification**: 同一リポジトリで2つのCodex CLIを起動し、片方だけに紐づくプルリクエストが他方の選択時に開かないことを確認する

---

## Step 1: セッションとプルリクエストの解決プロバイダーを追加

- **概要**: エージェント別解決器を介し、プロセスPIDからセッションIDとGitHubプルリクエストURLを解決する。ファイル探索・JSON解析をApp層へ漏らさず、Claude CodeとCodexの外部形式を分離する。
- **変更ファイル**: `Sources/FocusBMLib/SessionPullRequestResolver.swift`（新規）、`Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift`（新規）、Step 0の契約成立時のみ `Sources/FocusBMLib/CodexSessionPullRequestResolver.swift`（新規）。必要に応じて `Package.swift` はSwiftPM自動検出のため変更不要
- **参照する定数**: `CLAUDE_SESSION_REGISTRY_DIR`, `CLAUDE_PROJECTS_DIR`, `PR_URL_FIELD`, `SUPPORTED_PR_HOST`
- **実装メモ**:
  - `~/.claude/sessions/<pid>.json` を直接読む。全登録ファイル走査ではなく、選択中PIDから一意のファイルを引く。
  - 登録JSONの `pid` が要求PIDと一致し、`sessionId` が空でないことを確認する。PID再利用・古い登録ファイル対策として、可能なら現行プロセスの開始時刻と登録の `procStart` も照合する。
  - `~/.claude/projects/**/sessions-index.json` は再帰探索する。索引ルートは `{version, entries, originalPath}` 構造で、`entries` 配列から `entries[].sessionId == sessionId` を照合し、構造化済みの `prUrl` フィールドを収集する（`prNumber` / `prRepository` も同一エントリに併存するため補助検証に使える）。索引が破損・消失していても例外を外へ投げず「無し」とする。
  - 索引に `prUrl` が未反映のセッション（Claude Codeが非同期更新するため作成直後は欠落しうる。実測でも `prUrl` 保有は全エントリ中ごく一部）は「無し」として安全にフォールバックする。
  - URLは構造化フィールドの値をそのまま使い、`https`、ホストが `github.com`、パスが `/{owner}/{repo}/pull/{number}` を満たすものだけ採用する。JSONL本文やレビューコメントからのURL抽出はしない。
  - 同じURLの重複は除去する。異なるURLが複数ある場合は誤選択を避けて失敗結果にする。
  - App層はエージェントコマンドに対応する解決器を選ぶだけにし、Claude/Codexのファイル形式を分岐しない。共通化はURL検証、重複・競合判定、解決結果の境界に限定する。
  - Codex解決器はStep 0で2契約が成立した場合だけ登録する。未成立、未対応実行形態、候補競合では `nil` を返し、cwd・ブランチ・更新時刻で補完しない。
  - ファイルシステムとホームディレクトリを注入可能にし、一時ディレクトリでテストできる構造にする。
- **依存 Step**: -
- **振る舞い仕様**（System Type: transformation）:
  - 生存するClaude PID + 一致する登録JSON + 同一セッションIDの有効な単一`prUrl` → `URL`を返す → ファイル状態は不変
  - 登録ファイル無し / JSON破損 / PID不一致 / `sessionId`無し → `nil` → ファイル状態は不変
  - 索引無し / JSON破損 / 対応エントリ無し / `prUrl`無し → `nil` → ファイル状態は不変
  - `http`、GitHub以外のホスト、不正なpullパス → `nil` → 外部アプリを起動しない
  - 同一URL重複 → 1件へ正規化して返す。異なるURL複数 → `nil`
  - Codexの安定契約未成立 / PID対応無し / 正規PR URL無し / 候補競合 → `nil`
  - **Correctness Criteria**: PIDとセッションIDの両方が厳密に一致し、エージェント固有の正規フィールドから一意かつ有効なGitHubプルリクエストURLを得た場合だけ返す
  - **Left to Implementation**: 型名、内部DTO名、探索ヘルパーの分割
- **テスト**: Red Phaseで正常系、各欠損・破損、不正URL、重複、競合、PID不一致を追加し、Green Phaseでファイル注入可能な最小実装を行う。
- **Manual Verification**: 対象外: 一時ディレクトリを使う自動テストでデータ契約を十分検証できる

---

## Step 2: `bookmarks.yml` に画面アクション用ショートカットを追加

- **概要**: `HotkeySettings` に `openSessionPullRequest` を追加し、省略時の既定値と既存YAMLの後方互換を保証する。
- **変更ファイル**: `Sources/FocusBMLib/Models.swift:104-128`, `Tests/focusbmTests/AppSettingsTests.swift`
- **参照する定数**: `DEFAULT_OPEN_PR_HOTKEY`
- **実装メモ**:
  - 推奨設定形は `settings.hotkey.openSessionPullRequest: "cmd+p"` とする。既存のアプリ全体ホットキー `togglePanel` / `forceReloadAgents` と同じ場所に置くが、登録先はグローバルイベントタップではなくパネル内ローカルモニタである。
  - `HotkeySettings.init(from:)` の `decodeIfPresent` に追加し、古いYAMLでは既定値を補う。合成デコードへ戻さない。
  - 既存の `HotkeyParser.parse` を使用し、`cmd`, `ctrl`, `opt`, `shift` とキーの組合せを既存設定と同じ文法で扱う。
  - `cmd+r` は手動リフレッシュ予約キー、数字・矢印・Escapeは既存操作なので、衝突設定は警告して既定値へ戻すか無効化する方針を純粋関数で固定する。黙って既存操作を上書きしない。
- **依存 Step**: -
- **振る舞い仕様**（System Type: transformation）:
  - 設定省略 → `cmd+p`
  - 有効な設定値（例 `cmd+shift+p`, `ctrl+p`）→ 解析済みキーとして採用
  - 不正値・予約キー競合 → 既定値へフォールバックし警告
  - **Correctness Criteria**: 既存YAMLがデコード可能なままで、設定値のラウンドトリップと既定値が安定する
  - **Left to Implementation**: 予約キー検証ヘルパー名、警告出力方法
- **テスト**: Red Phaseで省略時、任意値、ラウンドトリップ、不正値、予約キー競合を追加し、Green Phaseでカスタムデコードと検証を実装する。
- **Manual Verification**: `bookmarks.yml` の値を `cmd+shift+p` に変えて再読み込みし、旧 `cmd+p` では発動せず新キーで発動することを確認する

---

## Step 3: 選択中AIエージェントに対するキー処理とブラウザ起動を追加

- **概要**: `SearchPanel` のローカルキーモニタで設定済みショートカットを先に判定し、選択中の対応エージェントプロセスに一意なプルリクエストがある場合だけパネルを閉じて既定ブラウザで開く。
- **変更ファイル**: `Sources/FocusBMApp/SearchPanel.swift:103-224`, `Sources/FocusBMApp/SearchViewModel.swift:390-428`, `Tests/FocusBMAppTests/ShortcutBarTests.swift` または新規 `SessionPullRequestShortcutTests.swift`
- **参照する定数**: `DEFAULT_OPEN_PR_HOTKEY`
- **実装メモ**:
  - `SearchPanel` に「NSEventと設定文字列が一致するか」の純粋関数を置くか、共有のキー照合器へ抽出する。文字キー固定の`alphabetShortcutLabel`へ無理に組み込まず、既存 `ParsedHotkey` とイベント修飾子を比較する。
  - ショートカット判定は数字・ブックマーク用アルファベット判定より前に行い、設定が一致したイベントを予約する。ただし選択項目が非対象、またはURL無しの場合は既存入力を妨げないようイベントを返す。
  - `SearchViewModel` は選択スナップショットを返す既存 `selectedItem()` を利用し、URL解決そのものはライブラリの解決器へ委譲する。対象は `.aiProcess(let process)` かつ登録済み解決器があるコマンドとし、初期値は `claude`、Step 0の契約成立時に `codex` を追加する。
  - ファイル探索はメインスレッドで行わず、選択項目をスナップショット後にバックグラウンド実行する。URLが得られた時だけメインスレッドで `close()` と `NSWorkspace.shared.open(url)` を行う。
  - `executeItem` はターミナルへのフォーカス用として維持し、プルリクエスト起動処理と混在させない。
  - ブラウザ起動をクロージャ注入できるようにし、テストで実アプリを開かない。
- **依存 Step**: Step 0, Step 1, Step 2
- **振る舞い仕様**（System Type: reactive）:
  - パネル表示中 + 対応AIプロセス選択 + キー一致 + 有効URLあり → パネルを閉じる → 既定ブラウザでURLを1回開く
  - 非AI項目 / tmuxペイン / 未対応エージェント / 選択無し + キー一致 → 何も開かずパネルを維持し、イベントを既存処理へ渡す
  - 対応エージェント選択 + URL無し・解析失敗 + キー一致 → 何も開かずパネルを維持する
  - キー不一致 → 既存の数字選択、項目ショートカット、矢印、Escape、文字入力を従来どおり処理する
  - 非同期解決中に選択が変わっても、キー押下時に確定したPIDのURLだけを扱う
  - **Correctness Criteria**: 設定キーと選択中エージェントセッションの一意なURLが両方揃った場合だけ、ブラウザ起動がちょうど1回発生する
  - **Left to Implementation**: 非同期ヘルパー名、URLオープナー注入方法、ログ文面
- **Frontend Constraints**: 非同期処理中にUIを停止しない。URL無しではパネル状態と選択状態を変更しない。パネルを閉じるのはURL確定後のみ。
- **テスト**: Red Phaseでキー照合の修飾キー差分、対象・非対象選択、URL有無、起動1回、既存`cmd+r`非回帰を追加し、Green Phaseで最小の非同期処理と注入点を実装する。
- **Manual Verification**: プルリクエスト作成済みClaude Codeセッションと、Step 0成立時はCodexセッションを個別に選び設定キーを押す → 対応するGitHubプルリクエストだけが既定ブラウザで開く → 別セッションのURLではないことを確認する

---

## Step 4: 設定例と利用方法を文書化

- **概要**: 実際の設定ファイル名と初回対応範囲、データ無し時の挙動を明記する。
- **変更ファイル**: `bookmarks.example.yml`, `README.md`, `README_ja.md`
- **参照する定数**: `DEFAULT_OPEN_PR_HOTKEY`
- **実装メモ**:
  - リポジトリの実装上の設定ファイル名は `bookmarks.yml` であり、ユーザー要望の `bookmarks.yaml` とは拡張子が異なる。現行パス `~/.config/focusbm/bookmarks.yml` を正として明記する。
  - 設定例: `settings.hotkey.openSessionPullRequest: "cmd+p"`。
  - 初回対応はtmux外のClaude Codeと、Step 0の契約を確認できたCodex実行形態に限定する。Claude Codeはセッション索引に`prUrl`が記録されている場合だけ、Codexは正規PR URL源を確認できた場合だけ開けると明記する。
  - プルリクエストが無い場合は何も開かないこと、設定変更後は既存の設定再読み込み操作またはアプリ再起動が必要なことを記載する。
- **依存 Step**: Step 2, Step 3
- **振る舞い仕様**: 対象外（文書変更のみ）
- **テスト**: 対象外: 文書・設定例のみ
- **Manual Verification**: YAML例を `YAMLDecoder` でデコードし、説明したキーがモデルへ反映されることを確認する

---

# Acceptance Criteria

**機能要件**:

- 選択中のtmux外Claude CodeプロセスのPIDが `~/.claude/sessions/<pid>.json` のセッションIDへ解決される。
- 同じセッションIDを持つ `sessions-index.json` エントリに一意で有効なGitHub `prUrl` があれば、設定キーで既定ブラウザに開く。
- CodexはStep 0の2契約が成立した実行形態だけで有効になり、選択PIDと正規PR URLが単一ロールアウトへ厳密に対応する場合だけ開く。契約未成立時は何も開かない。
- プルリクエストが無い、データが破損、URLが競合、非対象項目を選択中の場合は、ブラウザを開かずパネルも閉じない。
- `settings.hotkey.openSessionPullRequest` を省略すると `cmd+p`、変更すると指定キーだけで発動する。
- `cmd+r`、数字キー、ブックマークのアルファベットショートカット、矢印、Escape、通常文字入力の既存挙動が維持される。

**品質・安全**:

- セッション・索引ファイルは読み取り専用で扱い、書き換えない。
- Codexの内部SQLiteスキーマを安定APIとして扱わず、契約未確認のフィールドやロールアウト本文から推測しない。
- 外部文字列から任意コマンドを実行せず、検証済みの `https://github.com/{owner}/{repo}/pull/{number}` URLのみ `NSWorkspace` へ渡す。
- ファイル探索はメインスレッドを塞がず、失敗はアプリ停止へ波及しない。
- 解析ロジックは一時ディレクトリと依存注入で再現可能な単体テストを持つ。

**ドキュメント**:

- `bookmarks.example.yml`, `README.md`, `README_ja.md` に設定キー、既定値、対象範囲、プルリクエスト無し時の挙動が記載される。

---

# Docs to Update

| パス | 更新内容 | 必須条件 |
|------|---------|----------|
| `bookmarks.example.yml` | `settings.hotkey.openSessionPullRequest` の例とコメント | 常に必須 |
| `README_ja.md` | 日本語の操作方法・設定・制約 | 常に必須 |
| `README.md` | 英語の操作方法・設定・制約 | 公開READMEの内容同期のため必須 |
| `docs/manual-test-checklist.md` | 実セッションでの手動確認項目 | プロジェクトが新機能を手動回帰対象に含める場合は必須 |

---

# Don'ts（禁止事項）

- 作業ディレクトリやGitブランチだけでセッションを推定しない。同じブランチの別セッションへ誤接続するため。
- JSONL本文を全文走査して最初に見つかったGitHub URLを採用しない。レビューURLや例示URLを誤採用するため。
- Codexのcwd、Gitブランチ、開始・更新時刻だけでロールアウトを選ばない。同一条件の並行セッションを区別できないため。
- Codexの通常メッセージ、ユーザー入力、汎用ツール出力、レビュー取得結果を正規PR URL源として扱わない。
- `gh` コマンドやGitHub APIを呼んで「現在のブランチのプルリクエスト」へ置き換えない。
- `SearchPanel.startLocalKeyMonitor()` 内で同期的に再帰ファイル探索しない。
- URLが見つかる前にパネルを閉じない。
- 既存の `cmd+r` や項目ショートカットを設定値で暗黙に上書きしない。
- Claude Codeの管理ファイルを書き換えない。
- エージェント固有形式まで共通化する抽象化を先行実装しない。共通境界はURL検証と解決結果に限定し、実データ契約を確認できた解決器だけを登録する。

---

# Risks

| リスク | 対策 |
|--------|------|
| Claude Codeの内部ファイル形式が将来変更される | 小さなプロバイダーに隔離し、欠損キーを失敗扱いにする。固定フィクスチャで契約テストを持つ |
| PID再利用で古いセッションへ誤接続する | 登録JSON内PIDを再確認し、可能なら`procStart`と実プロセス開始時刻を照合する |
| `sessions-index.json` の再帰探索が遅い | キー押下時のみバックグラウンド実行し、将来必要なら更新時刻付きキャッシュをプロバイダー内へ追加する。初回実装では投機的キャッシュを入れない |
| 同一セッションに異なる`prUrl`が存在する | 安全側で開かず、競合をログへ記録する |
| 設定キーが既存操作と衝突する | 予約キー検証を行い、既定値へフォールバックして警告する |
| `bookmarks.yaml` と実ファイル `bookmarks.yml` の認識差 | 実装で使用する `BookmarkStore.storePath` に合わせ、文書で `.yml` を明記する |
| tmux内Claude Codeにも期待される可能性 | 初回対象外として明記し、tmuxペインからセッションPIDを一意に特定できる契約を別要件で調査する |
| Codex PIDとロールアウトIDを一意に対応付けられない | Step 0を実装ゲートにし、cwd・ブランチ・時刻で推定せずCodex解決器を無効のままにする |
| Codex JSONL内の例示・レビューURLを誤採用する | 正規PR URLの構造化契約が確認できるまで本文・汎用ツール出力を読まず、Codexでは何も開かない |
| Codex CLIとDesktop / IDE拡張で保存契約が異なる | 実行形態ごとに契約テストを持ち、検証済み形態だけを有効化する |

---

# Verification

**Automated**: `swift test`
