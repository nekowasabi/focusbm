---
task_id: T-20260815-opencode-pi-process
title: OpenCode / Pi を AI エージェントプロセス表示に載せる
status: planning
created: "2026-08-15"
scope:
  - Sources/FocusBMLib/ProcessProvider.swift
  - Sources/FocusBMLib/TmuxProvider.swift
  - Sources/FocusBMLib/Models.swift
  - Tests/focusbmTests/ProcessProviderTests.swift
  - Tests/focusbmTests/TmuxProviderTests.swift
  - Tests/focusbmTests/ModelsTests.swift
  - README.md
  - README_ja.md
depends_on: []
risk_flags:
  - performance
quality_gate:
  command: "swift test --filter 'ProcessProviderTests|TmuxProviderTests|ModelsTests|SearchViewModelOrderingTests|SessionPullRequestResolverTests'"
commit_mode: manual
light_mode: true
---

# OpenCode / Pi プロセス表示 実装計画

検索パネルの AI エージェント一覧に、既存の Claude / Aider / Gemini / Copilot / Codex / Hermes と同じ経路で OpenCode と Pi を出す。PR オープン・色・非 TTY Desktop は触らない。

---

# Commander's Intent

## Purpose

OpenCode と Pi が起動中なのに検索パネルへ出ない穴を埋める。検出と行表示だけを足す。

## End State

- 非 tmux の対話プロセスと tmux ペインの両方で OpenCode / Pi が一覧に出る
- 表示名は `OpenCode` / `Pi`、絵文字は既存デフォルト `🤖`
- `swift test` の既存エージェント契約が全緑
- cmd+p の PR 解決は `opencode` / `pi` を登録しない

## Key Tasks

1. `aiAgentCommands` に `opencode` / `pi` を追加し、tmux 側のハードコード判定を同期する
2. `pi` の誤検出を title 部分一致と `/{cmd} ` フォールバックで起こさない
3. Hermes 追加と同型のテストと README 既存リストへの追記

---

# 確定判断（実装中に再質問しない）

| ID | 判断 | 内容 |
|---|---|---|
| D1 | OpenCode の正体 | anomalyco/opencode CLI。コマンド名は `opencode`。このマシンは `/opt/homebrew/bin/opencode` → Cellar `1.3.13` |
| D2 | Pi の正体 | mariozechner / earendil-works の pi-coding-agent。コマンド名は `pi`。ユーザー環境で `brew install pi-coding-agent` が進行中だった |
| D3 | 表示名 | 非 tmux / tmux とも `OpenCode` / `Pi`（Hermes 特例と同じ人間可読名） |
| D4 | 絵文字 | 専用絵文字は作らない。`agentCommandToEmoji` の default `🤖` を使う |
| D5 | tmux title | `opencode` は title 部分一致を追加する。`pi` は title に入れない（英語ペイン誤爆） |
| D6 | tmux command 直判定 | `isAIAgent` / `aiAgentReason` のハードコードに `opencode` と `pi` を追加する（Hermes 踏襲。配列参照への大規模整理はしない） |
| D7 | node 解決 | `aiAgentCommands` 追加だけで `resolveNodeAgentCommand` は追随する。ただし `pi` は `/{cmd} ` フォールバックを使わない（D8） |
| D8 | `pi` の誤検出ガード | (1) title.contains("pi") 禁止 (2) `resolveNodeAgentCommand` で `pi` は `bin/pi` または cmdline に `pi-coding-agent` / `@earendil-works` / `@mariozechner` があるときだけ採用 (3) 非 tmux pgrep は既存 `processNamePattern("pi")` のまま |
| D9 | デーモン除外 | 汎用 `serve` は `daemonSubcommands` に入れない。`opencode` のトークン列 `opencode` + `serve` だけ除外。`pi -p` / `--mode rpc` は除外しない（短命・証拠不足） |
| D10 | Desktop | `opencode-cli` sidecar / OpenCode.app / 非 TTY は出さない。`isRecoverableAIProcess` を緩めない |
| D11 | PR オープン | `SessionPullRequestResolver` に登録しない |
| D12 | 検索クエリ | `SearchViewModel` の haystack は変えない。非 tmux は raw `command` で当たる（`opencode` / `pi`）。表示名 `OpenCode` での非 tmux 検索不一致は Hermes と同じ既知契約 |
| D13 | README | 既存 Supported リストへ 2 件だけ追記。Codex / Copilot 欠落の一括修正は別件 |
| D14 | 設定 | YAML フラグは作らない。`showTmuxAgents` の意味は変えない |

---

# ★ Constants

| 定数名 | 値 | 単位 | 使う Step |
|---|---|---|---|
| `AI_AGENT_COMMAND_OPENCODE` | `opencode` | command | 1, 2, 3 |
| `AI_AGENT_COMMAND_PI` | `pi` | command | 1, 2, 3 |
| `DISPLAY_NAME_OPENCODE` | `OpenCode` | label | 3 |
| `DISPLAY_NAME_PI` | `Pi` | label | 3 |
| `DEFAULT_AGENT_EMOJI` | `🤖` | glyph | 3 |
| `PI_NODE_MARKERS` | `bin/pi`, `pi-coding-agent`, `@earendil-works`, `@mariozechner` | substr | 2 |
| `OPENCODE_SERVE_PATTERN` | `(^|/)opencode[[:space:]]+serve([[:space:]]|$)` | regex | 1 |
| `PROCESS_NAME_PATTERN_OPENCODE` | `(^|/)opencode([[:space:]]|$)` | regex | 1 |
| `PROCESS_NAME_PATTERN_PI` | `(^|/)pi([[:space:]]|$)` | regex | 1 |
| `RESOLVE_NODE_MAX_DEPTH` | 3 | hop | 2（既存） |
| `PARENT_WALK_MAX` | 20 | hop | 1（既存） |

コードへ新規 public 定数を増やす必要はない。上表は計画の単一ソース。実装は既存の `aiAgentCommands` 配列と局所判定に埋め込む。

---

# Scope

**対象**:

- `ProcessProvider.aiAgentCommands` への `opencode` / `pi` 追加
- OpenCode `serve` の対話除外（D9）
- `TmuxPane.isAIAgent` / `aiAgentReason` / `agentName` の同期
- `resolveNodeAgentCommand` の `pi` ガード（D8）
- 非 tmux `SearchItem.displayName` の表示名特例
- Hermes 同型テスト
- `README.md` / `README_ja.md` の既存 Supported リスト

**対象外（理由付き）**:

- `SessionPullRequestResolver` への登録 — OpenCode / Pi のセッション↔PR 契約が無い
- OpenCode Desktop / `opencode-cli` / 非 TTY — 現行は `terminalBundleId` 必須
- 非 tmux へのステータス色 — `.aiProcess` の `agentDisplay` は常に nil（既存契約）
- ShortcutBar の agentEmoji 化 — アプリアイコン経路のまま
- `showTmuxAgents` の系統分割 — 既存ゲートを変えない
- Codex の `agentName` switch 欠落 / README の Codex・Copilot 欠落 — 別バグ
- `command == "agent"` の整理 — 今回無関係
- `aiAgentCommands` を単一ソースにする大規模リファクタ — Hermes 踏襲でハードコード同期に留める
- YAML 新フラグ — D14

---

# Assumptions / Open Questions

外部挙動は D1–D14 で確定済み。未決の Open Question は無し。

| premise_id | claim | kind | evidence | status |
|---|---|---|---|---|
| PR-01 | 検出正本は `ProcessProvider.aiAgentCommands`（現在 6 件、OpenCode/Pi なし） | static | `Sources/FocusBMLib/ProcessProvider.swift:38` | verified |
| PR-02 | tmux の command 直判定と title 判定は配列を参照せずハードコード | static | `Sources/FocusBMLib/TmuxProvider.swift:66-79` | verified |
| PR-03 | `resolveNodeCommand ∈ aiAgentCommands` なら tmux で AI 扱い | static | `Sources/FocusBMLib/TmuxProvider.swift:61-63` | verified |
| PR-04 | node 解決は `bin/{cmd}` または `/{cmd} ` | static | `Sources/FocusBMLib/TmuxProvider.swift` `resolveNodeAgentCommand` | verified |
| PR-05 | 非 tmux 表示名は `hermes` だけ `"Hermes"`、他は raw command | static | `Sources/FocusBMLib/Models.swift:386` | verified |
| PR-06 | 専用絵文字は copilot/codex/hermes のみ、他は `🤖` | static | `Sources/FocusBMLib/TmuxProvider.swift:295-301` | verified |
| PR-07 | デーモン除外は `" " + marker` 部分一致。汎用 `serve` は未登録 | static | `Sources/FocusBMLib/ProcessProvider.swift:45-53` | verified |
| PR-08 | リポジトリ内に opencode / pi-coding-agent 言及は 0 | static | 調査 grep 0 件 | verified |
| PR-09 | このマシンに `opencode` バイナリはある。実行中プロセスは無い | dynamic | `command -v opencode` → `/opt/homebrew/bin/opencode`。`ps` に対話プロセス無し | verified |
| PR-10 | `pi` バイナリは未インストール。`brew install pi-coding-agent` が観測された | dynamic | `ls /opt/homebrew/bin/pi` 不在。`ps` に brew install | verified |
| PR-11 | パネル表示は `SearchView` → `BookmarkRow`。メニューバーはライブ AI 行を出さない | static | 調査報告 `FocusBMApp.swift:216-245` | verified |
| PR-12 | `supports("opencode"|"pi")` 相当の PR 解決は未登録のままが正しい | static | `SessionPullRequestResolver.swift:17-24`（claude/codex のみ） | verified |

---

# Required Sections

| Flag | 必須セクション | 反映先 |
|---|---|---|
| performance | pgrep 6→8 回。`pi` 誤ヒット時の後段コスト | D8 / Risks |
| security | 対象外: プロセス列挙と表示のみ。cwd を外部送信しない | — |
| external_api | 対象外: 新規外部 API なし | — |
| frontend | 対象外: SwiftUI の状態機械は触らない。行は既存 `SearchItem` 投影 | — |
| multi_id | 対象外: 新規 ID 体系なし。既存 `aiprocess-{pid}` / paneId | — |
| data_migration | 対象外: 永続データ変更なし | — |
| backwards_incompatible | 対象外: 既存コマンドの意味を変えない | — |

# Decision-Complete チェック

| 観点 | 状態 | 記載先 |
|---|---|---|
| Goal / Success Criteria | 記載済 | Commander's Intent + Acceptance Criteria |
| Scope / Non-goals | 記載済 | Scope |
| Existing Behavior | 記載済 | D11–D14 / Don'ts |
| Public Interfaces | 記載済 | 表示名 D3、絵文字 D4、検出コマンド D1–D2 |
| Data Model / State | 記載済 | 新規型なし。`aiAgentCommands` とハードコード同期 |
| Behavior / Edge Cases | 記載済 | Step 1–3 の振る舞い仕様 |
| Error Handling | 記載済 | 検出失敗は非表示。既存どおり例外を投げない |
| Security / Privacy | 対象外 | プロセス一覧表示のみ |
| Performance | 記載済 | Risks / D8 |
| Concurrency / Async | 対象外 | 既存 refresh 周期を変えない |
| Migration / Compatibility | 記載済 | D10–D14 |
| Observability | 記載済 | 既存 debug log が新コマンドにも乗る |
| Testing | 記載済 | 各 Step のテスト + Verification |
| Rollout / Operations | 記載済 | 一括リリース。設定変更なし |
| Maintainability | 記載済 | Hermes 同型。配列一本化はしない（D6） |

---

# 実装ステップ

## Step 1: 非 tmux 検出に OpenCode / Pi を追加する

- **概要**: `aiAgentCommands` に 2 コマンドを足し、OpenCode の `serve` だけを対話一覧から外す。
- **変更ファイル**:
  - `Sources/FocusBMLib/ProcessProvider.swift:38` — 配列末尾に `opencode`, `pi`
  - `Sources/FocusBMLib/ProcessProvider.swift:47-53` — `isDaemonCommandLine` に D9 のトークン列判定を追加
  - `Tests/focusbmTests/ProcessProviderTests.swift:188-195` — `contains("opencode")` / `contains("pi")`
  - 同ファイル daemon 節 — `opencode serve` は true、`opencode run "please serve the app"` は false
- **参照する定数**: `AI_AGENT_COMMAND_*`, `OPENCODE_SERVE_PATTERN`, `PROCESS_NAME_PATTERN_*`
- **実装メモ**:
  - `processNamePattern` は変更しない。`opencode` / `pi` は既存関数で `(^|/)name([[:space:]]|$)` になる
  - `serve` を `daemonSubcommands` に足すと `run` プロンプトの " serve " を誤除外する。regex は `opencode` の直後トークンだけを見る
  - `listNonTmuxAIProcesses` 本体は触らない。配列追加で pgrep が 2 回増える
- **依存 Step**: —
- **振る舞い仕様**（System Type: transformation）:
  - `aiAgentCommands` 走査 → `opencode` / `pi` の PID が候補に入る
  - cmdline が `OPENCODE_SERVE_PATTERN` に一致 → 候補から除外、post_state は一覧非掲載
  - `opencode` / `opencode run "..."` → 生存・非デーモン・非 tmux・terminal 解決済みなら `AIProcess` 1 件
  - `pip` / `ping` / `epic` → `PROCESS_NAME_PATTERN_PI` 非一致（既存単語境界）
  - **Completion Criteria**:
    - Given 配列が更新済み When `test_aiAgentCommands_containsExpected` Then `opencode` と `pi` を含む
    - Given cmdline `opencode serve` When `isDaemonCommandLine` Then true
    - Given cmdline `opencode run please serve the app` When `isDaemonCommandLine` Then false
  - **Left to Implementation**: `isDaemonCommandLine` 内の局所ヘルパ名
- **テスト**: Red で配列 assert と serve 判定を先に落とす → Green で配列と判定を足す
- **Manual Verification**: `opencode` をターミナルで起動 → パネルに非 tmux 行が出る。`opencode serve` は出ない（executor: human。Pi 未インストールなら Pi 非 tmux は unverified）

## Step 2: tmux 検出を同期し、`pi` の node 誤解決を塞ぐ

- **概要**: command 直判定・reason・title（opencode のみ）を足す。`pi` の `/{cmd} ` フォールバックを切る。
- **変更ファイル**:
  - `Sources/FocusBMLib/TmuxProvider.swift:66-79` — `isAIAgent` の command 列に `opencode` / `pi`。title に `t.contains("opencode")` のみ追加
  - 同ファイル `91-107` — `aiAgentReason` を同じ分岐に同期
  - 同ファイル `resolveNodeAgentCommand`（約 972-988） — `cmd == "pi"` のとき `args.contains("/pi ")` を使わない。`PI_NODE_MARKERS` のいずれか、または `bin/pi`
  - `Tests/focusbmTests/TmuxProviderTests.swift` — Hermes 同型: command / title(opencode) / title(pi は false) / node resolved / ghost shell
- **参照する定数**: `AI_AGENT_COMMAND_*`, `PI_NODE_MARKERS`, `RESOLVE_NODE_MAX_DEPTH`
- **実装メモ**:
  - `resolvedNodeCommand ∈ aiAgentCommands` は配列追加だけで OpenCode に効く
  - `/{cmd} ` を `pi` に使うと `/usr/local/pi something` やパス断片に当たる
  - シェル残存 title だけでは出ない既存 ghost 契約を維持。`title == "pi"` でも command が zsh なら false
  - `codex` が command switch に無い既存欠落は直さない（D13 と同様別件）
- **依存 Step**: Step 1（配列が `resolveNode` の走査元）
- **振る舞い仕様**（System Type: transformation）:
  - command `opencode` or `pi` → `isAIAgent == true`, reason `command_match(...)`
  - command `node` + 子孫 cmdline `.../bin/opencode` → resolved `opencode` → true
  - command `node` + 子孫 cmdline `.../bin/pi` または `pi-coding-agent` → resolved `pi` → true
  - command `node` + cmdline に `/foo/pi args` のみ（マーカー無し） → resolved しない → false
  - command `zsh` + title に `opencode` → false（ghost）
  - command `zsh` + title に `pi` → false（title 非対象）
  - command `nvim` + title に `opencode` → true（既存 title 契約）
  - **Completion Criteria**: Hermes テストを `opencode` / `pi` に複製し、pi title と `/pi ` 単独は false を必須にする
  - **Left to Implementation**: マーカー判定の局所関数名
- **テスト**: 上記 6 分岐を `@Test` で固定。`test_isAIAgent_piInTitle` は **false** が合格
- **Manual Verification**: tmux で `opencode` 起動 → `focusbm tmux-list` に出る。Pi 導入後に `pi` でも同様（executor: human）

## Step 3: 表示名を Hermes 型にし、絵文字は default のままにする

- **概要**: 行ラベルを `OpenCode` / `Pi` にする。絵文字 switch は増やさない。
- **変更ファイル**:
  - `Sources/FocusBMLib/TmuxProvider.swift:207-236` — `agentName` の command switch に `opencode`/`pi`。`resolvedNodeCommand` switch にも明示ケース（default の `capitalized` だと `Opencode` になる）
  - title フォールバックに `t.contains("opencode") → OpenCode`。`pi` は足さない
  - `Sources/FocusBMLib/Models.swift:386` — `hermes` 単独の三項演算子を、`hermes`/`opencode`/`pi` の対応に拡張
  - `Tests/focusbmTests/ProcessProviderTests.swift:116-128` 同型の displayName テスト
  - `Tests/focusbmTests/TmuxProviderTests.swift` — `test_agentName_opencodeCommand` / `_piCommand` / resolved
  - `Tests/focusbmTests/ModelsTests.swift:213-234` — emoji が `🤖` であること
- **参照する定数**: `DISPLAY_NAME_*`, `DEFAULT_AGENT_EMOJI`
- **実装メモ**:
  - `agentCommandToEmoji` に case を足さない。default が契約
  - 非 tmux 検索 haystack は raw command のまま（D12）。テストで検索まで広げない
- **依存 Step**: Step 2
- **振る舞い仕様**（System Type: transformation）:
  - tmux command `opencode` → agentName `OpenCode` → displayName `"{termEmoji} {statusEmoji} OpenCode — {basename}"`
  - tmux command `pi` → `Pi`
  - 非 tmux command `opencode` → `"{termEmoji} OpenCode — {basename}"`（色なし）
  - emoji 入力 `opencode`/`pi` → `🤖`
  - **Completion Criteria**: displayName / agentName / emoji の 3 系統テストが PASS
  - **Left to Implementation**: Models 側を switch にするか小さな辞書にするか
- **テスト**: Red で表示名と `🤖` を先に落とす
- **Manual Verification**: パネル行のラベルが `OpenCode` / `Pi` で、アイコンがロボット（executor: human）

## Step 4: README の既存 Supported リストへ追記する

- **概要**: コードと README の差分を、今回足す 2 件だけ埋める。
- **変更ファイル**:
  - `README.md` 「Supported AI agents」（Hermes の次）
  - `README_ja.md:359-364` 同様
- **参照する定数**: `AI_AGENT_COMMAND_*`, `DISPLAY_NAME_*`
- **実装メモ**:
  - 追記形: `OpenCode (\`opencode\`)` / `Pi (\`pi\`)`
  - Codex / Copilot をこの PR で足さない（D13）
- **依存 Step**: Step 1
- **振る舞い仕様**: 対象外（doc-only）
- **テスト**: 対象外。Verification で見出し直下に 2 行があること
- **Manual Verification**: 対象外: 自動確認で十分（`rg` でリストに 2 件）

---

# Acceptance Criteria

**機能要件**:

- [ ] `ProcessProvider.aiAgentCommands` が `opencode` と `pi` を含む
- [ ] 非 tmux の対話 `opencode` が一覧に出る（terminal 解決済み・非デーモン・非ゾンビ）
- [ ] tmux で command が当該名、または node/deno/bun + 解決済みコマンドのとき AI 行になる
- [ ] 表示名が `OpenCode` / `Pi`、絵文字が `🤖`
- [ ] `opencode serve` は出ない。`opencode run "please serve the app"` はデーモン扱いしない
- [ ] title に `pi` があるだけでは出ない
- [ ] `/foo/pi args` だけの node 子孫は Pi に解決しない
- [ ] 既存エージェント（claude/aider/gemini/copilot/codex/hermes）のテストが全緑
- [ ] `SessionPullRequestResolver` は `opencode`/`pi` を support しない

**品質・安全**: HTTP ステータス対象外（ローカルプロセス列挙）。誤検出は D8/D9 のテストで固定。

**ドキュメント**: README / README_ja の既存 Supported リストに 2 件。

---

# Docs to Update

| パス | 更新内容 | 必須条件 |
|---|---|---|
| `README.md` | Supported AI agents に OpenCode / Pi | 必須 |
| `README_ja.md` | サポート対象に OpenCode / Pi | 必須 |
| `docs/manual-test-checklist.md` | — | 対象外: AI エージェント節なし。新設しない |
| `stigmergy/` | — | 対象外: エージェント一覧なし |

---

# Don'ts

- `SessionPullRequestResolver` に推測で登録しない（pattern: `supports\(\"opencode\"\)` / `supports\(\"pi\"\)` 新規 0）
- `title.contains("pi")` / `t.contains("pi")` を追加しない（pattern: `contains\(\"pi\"\)` 新規 0）
- 汎用 `serve` を `daemonSubcommands` に入れない（pattern: `daemonSubcommands = \[.*serve` 新規 0）
- `isRecoverableAIProcess` を緩めて ❓ 行を復活させない
- `showTmuxAgents` の意味を変えない
- Hermes 契約テストを消して実装に合わせない
- 計画にないドキュメント新設をしない
- `aiAgentCommands` の大規模再設計・YAML enum 化を混ぜない

---

# Risks

| リスク | 対策 |
|---|---|
| `pi` の短い名前による誤検出 | D8。title 禁止 + node はマーカー必須。pgrep は単語境界のまま |
| `/{cmd} ` がパス断片に当たる | `pi` だけフォールバック無効 |
| `serve` 汎用除外が `run` プロンプトを落とす | D9 のトークン列 regex |
| tmux ハードコード漏れで系統分裂 | Step 2 を Step 1 の必須後続にし、command/reason/title/name を同 PR で同期 |
| Pi 未導入で手動確認ができない | 自動テストで契約を固定。手動は OpenCode を必須、Pi は導入後に unverified 可 |

---

# Verification

**Automated**:

```bash
swift test --filter 'ProcessProviderTests|TmuxProviderTests|ModelsTests|SearchViewModelOrderingTests|SessionPullRequestResolverTests'
```

合格: exit 0。既存 Hermes / daemon / ordering / PR resolver が回帰しない。

**手動（最大 5）**:

1. ターミナルで `opencode` 起動 → パネルに `OpenCode` 行 → 選択でフォーカス（executor: human）
2. `opencode serve` 起動 → パネルに出ない（executor: human）
3. tmux ペインで `opencode` → `focusbm tmux-list` に出る（executor: agent 可）
4. Pi 導入後、`pi` 起動で同様（未導入なら unverified）
5. 無関係な `pip` / title に `pi` だけのペインが AI 行にならない

---

# DAG

`1 → {2, 4}` → `2 → 3`

Step 4（README）は Step 1 のコマンド名確定後なら Step 2/3 と並列可。

---

# 既存挙動（変えないもの）

- メニューバーはライブ AI 行を出さない
- 非 tmux 行にステータス色を付けない
- ゾンビ・tmux 祖先・terminal 未解決は出さない
- シェル残存 title（ghost）は出さない
- cmd+p は Claude / Codex のみ
- `showTmuxAgents == false` で tmux と非 tmux AI の両方を隠す
