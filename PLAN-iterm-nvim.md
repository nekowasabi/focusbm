---
task_id: "T-20260815-iterm-nvim"
title: "iTerm2 の tmux 内 Neovim ペインへの安全な切替と固定 Ex コマンド実行"
status: planning
created: "2026-08-15"
scope:
  - Sources/FocusBMLib/Models.swift
  - Sources/FocusBMLib/YAMLStorage.swift
  - Sources/FocusBMLib/TmuxProvider.swift
  - Sources/FocusBMLib/AppleScriptBridge.swift
  - Sources/FocusBMLib/BookmarkRestorer.swift
  - Sources/FocusBMLib/NvimTmuxRestorer.swift
  - Tests/focusbmTests
  - README.md
  - README_ja.md
  - bookmarks.example.yml
depends_on: []
risk_flags: [security, external_api, backwards_incompatible]
quality_gate:
  command: "swift test && swift build && git diff --check"
  min_quality_score: "-"
commit_mode: manual
loop_ready: true
---

# Commander's Intent

## Purpose

iTerm2 上の tmux 内で起動した特定の Neovim ペインを、どこからでも FocusBM の YAML ブックマークで開き、固定 Ex コマンドまで安全に実行できるようにする。

## End State

設定した絶対作業ディレクトリに一致する `nvim` ペインだけが iTerm2 で前面化され、tmux の対象ペインが選択された後に、設定済み Ex コマンドが一度だけ送信される。不確実な対象には一切入力を送らない。

## Key Tasks

- YAML 状態型と後方互換のある設定検証を追加する。
- tmux の列挙順を保つ厳格な候補・クライアント検証を実装する。
- iTerm2 の TTY セッションを AppleScript で選択し、固定入力を送る。

---

# ★ Constants（唯一の正・他は定数名で参照）

| 定数名 | 値 | 単位 | 備考 |
|---|---:|---|---|
| ITERM2_BUNDLE_ID | `com.googlecode.iterm2` | bundle identifier | 初期版で許可する唯一のターミナル |
| NVIM_PANE_COMMAND | `nvim` | command | `pane_current_command` の完全一致条件 |
| APPLESCRIPT_TIMEOUT_SECONDS | 5 | 秒 | 既存 `AppleScriptBridge.run` のタイムアウト |
| GATE_TABLE_COLUMNS | 12 | 列 | Verification Gates の列数 |
| PLAN_REVISION | 1 | revision | execution contract の初版 |

---

# Scope

**対象**:

- `state.type: itermNvim` の YAML ブックマーク。
- iTerm2 上の tmux クライアントに接続された `nvim` ペインの切替と Ex コマンド送信。
- YAML、tmux、AppleScript の単体テストと英日ドキュメント。

**対象外（理由付き）**:

- Terminal、Ghostty、WezTerm — 初期版は iTerm2 固定で誤送信面を増やさない。
- tmux 外の Neovim — 対象の tmux クライアントとペインを検証できない。
- `vim`、ラッパー、タイトル推測による候補化 — `nvim` 完全一致だけを安全な対象とする。
- 対話入力、任意コマンド入力、Neovim RPC — ユーザーが選択した固定 Ex コマンド送信の範囲外。
- `tmux send-keys` — iTerm 入力送信という要求と異なる将来の安全モード候補。

---

# Assumptions / Open Questions（外部挙動に影響する未決定事項）

なし（外部挙動はすべて decision-complete に確定済み）。

---

# Required Sections（risk_flags 連動）

| Flag | 必須セクション | 反映先 |
|---|---|---|
| security | 入力検証・誤送信防止 | Process 01–04 の Behavior Specification |
| external_api | iTerm2 AppleScript と失敗時フォールバック | Process 03–04 |
| backwards_incompatible | public enum case と既存 YAML 互換性 | Process 01 |
| performance | 対象外: ローカル短命プロセスのみで性能目標は増やさない | Risks |
| frontend | 対象外: 既存検索パネルの表示・状態遷移は変更しない | Scope |

---

# Decision-Complete チェック（15観点）

| 観点 | 状態 | 記載先 / 対象外理由 |
|---|---|---|
| Goal / Success Criteria | 記載済 | Commander's Intent / Acceptance Criteria |
| Scope / Non-goals | 記載済 | Scope |
| Existing Behavior | 記載済 | Don'ts / Process 04 の不変条件 |
| Public Interfaces / Contracts | 記載済 | Process 01 の YAML 契約 |
| Data Model / State | 記載済 | Process 01・04 の Behavior Specification |
| Behavior / Edge Cases | 記載済 | Process 02–04 |
| Error Handling | 記載済 | Process 04 の fail-closed 契約 |
| Security / Privacy | 記載済 | Process 01・03・04 |
| Performance / Scalability | 対象外: ローカル列挙のみ | Risks |
| Concurrency / Async | 記載済 | Process 04 |
| Migration / Compatibility | 記載済 | Process 01 |
| Observability | 記載済 | Process 04 |
| Testing | 記載済 | Process 10 / Final Gates |
| Rollout / Operations | 記載済 | Process 200 / 手動検証 |
| Maintainability | 記載済 | Process 分割・テスト・Docs to Update |

---

# Progress Map

| Process | Title | Status | Disjoint | Type | File |
|---|---|---|---|---|---|
| 01 | YAML 状態型と互換性 | ☐ planning | y | 変換 | [→ process-01.md](plan-iterm-nvim/process-01.md) |
| 02 | tmux 候補選定・入力前検証 | ☐ planning | y | 変換 | [→ process-02.md](plan-iterm-nvim/process-02.md) |
| 03 | iTerm2 セッション選択・入力送信 | ☐ planning | y | 変換 | [→ process-03.md](plan-iterm-nvim/process-03.md) |
| 04 | ブックマーク復元の安全な統合 | ☐ planning | n | both | [→ process-04.md](plan-iterm-nvim/process-04.md) |
| 10 | 統合回帰テスト | ☐ planning | n | both | [→ process-10.md](plan-iterm-nvim/process-10.md) |
| 200 | 利用者向け設定文書 | ☐ planning | y | - | [→ process-200.md](plan-iterm-nvim/process-200.md) |
| 300 | 実行後の知見永続化 | ☐ planning | n.a. | - | [→ process-300.md](plan-iterm-nvim/process-300.md) |

**DAG**: `{01,02,03}→04→{10,200}→300`

**Overall**: ☐ 0/7 completed

---

# Wave Progress Map

| Wave | Processes | Depends on Wave | Disjoint | Status |
|---|---|---|---|---|
| W01 | P01, P02, P03 | - | y | ☐ planning |
| W02 | P04 | W01 | n（統合 API に依存） | ☐ planning |
| W03 | P10, P200 | W02 | y | ☐ planning |
| W04 | P300 | W03 | n.a. | ☐ planning |

---

# Execution Contract

```yaml
execution_contract:
  task_id: T-20260815-iterm-nvim
  plan_revision: 1
  loop_ready: true
  objective: "iTerm2 の tmux 内 nvim ペインを安全に選択し固定 Ex コマンドを一度だけ送信する"
  success_criteria:
    - id: SC-01
      text: "itermNvim ブックマークが既存 YAML を壊さず復号・保存できる"
    - id: SC-02
      text: "完全一致した iTerm2/tmux/nvim 候補だけを tmux 列挙順で選び、検証失敗時は入力しない"
    - id: SC-03
      text: "iTerm2 の同一 TTY セッションを前面化して固定 Ex コマンドを一度だけ送る"
    - id: SC-04
      text: "自動テスト、ビルド、差分検査、実機手動確認が完了する"
  policies:
    - "YAML の exCommand は空・先頭コロン・CR/LF/NUL を拒否する"
    - "global fallback client、current window/current session、System Events、再試行送信を使わない"
    - "候補、TTY、pane ID、iTerm2 session のいずれかが不明なら fail-closed とする"
  gates:
    - { gate_id: "P01-VG-green", phase: green, type: test, executor: agent, required: true, command: "swift test", input_scope: "P01", pass_criteria: "exit 0", evidence_spec: "Swift Testing pass 行", failure_policy: {failure_class: test, retryable: true, retry_budget_source: task_retry_budget, terminal_action: escalate_plan_repair}, criterion_refs: [SC-01], policy_refs: ["YAML validation"] }
    - { gate_id: "P02-VG-green", phase: green, type: test, executor: agent, required: true, command: "swift test", input_scope: "P02", pass_criteria: "exit 0", evidence_spec: "TmuxProvider tests pass", failure_policy: {failure_class: test, retryable: true, retry_budget_source: task_retry_budget, terminal_action: safe_stop}, criterion_refs: [SC-02], policy_refs: ["fail-closed client resolution"] }
    - { gate_id: "P03-VG-green", phase: green, type: test, executor: agent, required: true, command: "swift test", input_scope: "P03", pass_criteria: "exit 0", evidence_spec: "AppleScriptBridge tests pass", failure_policy: {failure_class: test, retryable: true, retry_budget_source: task_retry_budget, terminal_action: safe_stop}, criterion_refs: [SC-03], policy_refs: ["exact TTY"] }
    - { gate_id: "P10-VG-regression", phase: green, type: test, executor: agent, required: true, command: "swift test", input_scope: "P01,P02,P03,P04,P10", pass_criteria: "exit 0 and all tests pass", evidence_spec: "test summary", failure_policy: {failure_class: regression, retryable: true, retry_budget_source: task_retry_budget, terminal_action: safe_stop}, criterion_refs: [SC-01, SC-02, SC-03], policy_refs: ["existing behavior"] }
    - { gate_id: "FINAL-VG-build", phase: final, type: quality, executor: agent, required: true, command: "swift build && git diff --check", input_scope: "task_delta", pass_criteria: "both commands exit 0", evidence_spec: "exit codes", failure_policy: {failure_class: quality, retryable: true, retry_budget_source: task_retry_budget, terminal_action: safe_stop}, criterion_refs: [SC-04], policy_refs: ["quality"] }
    - { gate_id: "FINAL-VG-iterm-manual", phase: final, type: manual, executor: human, required: true, command: "実機 iTerm2/tmux/nvim 手順", input_scope: "running FocusBM", pass_criteria: "対象だけが前面化され Ex が1回実行される", evidence_spec: "人間の観測", failure_policy: {failure_class: environment, retryable: false, retry_budget_source: task_retry_budget, terminal_action: await_input}, criterion_refs: [SC-03, SC-04], policy_refs: ["Automation permission"] }
  required_gates: [P01-VG-green, P02-VG-green, P03-VG-green, P10-VG-regression, FINAL-VG-build, FINAL-VG-iterm-manual]
  completion_rule: "全 required_gates が pass。ただし human gate は未実行なら unverified として残す"
```

---

# Conflict Matrix

| Process | Symbols (file:symbol) | Disjoint | Confidence | Evidence |
|---|---|---|---|---|
| 01 | `Models.swift:AppState`, `YAMLStorage.swift:BookmarkStore/loadYAML` | true | high | Serena symbol inspection |
| 02 | `TmuxProvider.swift:TmuxProvider` | true | high | Serena symbol inspection |
| 03 | `AppleScriptBridge.swift:AppleScriptBridge` | true | high | Serena symbol inspection |
| 04 | `BookmarkRestorer.swift:BookmarkRestorer/restoreAndGetTarget`, `NvimTmuxRestorer.swift` | false | high | P01–03 API dependency |
| 10 | `Tests/focusbmTests/*` | false | high | integration tests depend on P01–04 |
| 200 | `README.md`, `README_ja.md`, `bookmarks.example.yml` | true | high | doc-only |
| 300 | `MEMORY.md`, `stigmergy/*` | n.a. | high | post-execution only |

---

# Acceptance Criteria（要約）

**機能要件**:

- `itermNvim` は絶対作業ディレクトリと `nvim` の完全一致だけを候補にする。
- 複数候補では tmux の同一列挙スナップショットの先頭だけを使う。
- iTerm2 の同一 TTY セッションを window → tab → session の順で選択し、`Esc`、`:`、`exCommand`、Enter を一度だけ送る。

**品質・安全**:

- `exCommand` の無効値、非 iTerm2、TTY 不明、global fallback、pane 検証不一致、Apple Event 拒否・タイムアウトでは入力送信回数を 0 とする。
- 既存 `browser`、`app`、`floatingWindows`、V1 `type: iterm2` 移行の挙動を変えない。

**ドキュメント**:

- 英日 README と設定例が同一の YAML 契約、Automation 権限、no-op 条件を説明する。

---

# Docs to Update

| パス | 更新内容 | 必須条件 |
|---|---|---|
| README.md | 英語の設定例・安全条件・Automation のトラブルシュート | P04 完了後 |
| README_ja.md | 日本語の同内容 | P04 完了後 |
| bookmarks.example.yml | 正しい `itermNvim` ブックマーク例 | P01 完了後 |
| MEMORY.md | 対象外: 実装後に再利用可能な知見が得られた場合のみ P300 で追記 | 実装完了後 |

---

# Don'ts（禁止事項）

- `type: iterm2` を新型名に再利用しない。既存移行処理が `app` に変換するため。
- `preferredTerminal`、全体 fallback client、先頭の実行中ターミナルを送信先に使わない。
- iTerm2 の current window/current session、System Events、固定待機時間、全ウィンドウ送信を使わない。
- `exCommand` をシェル・AppleScript に未エスケープ連結しない。コマンド本文をログに出さない。
- 失敗時に同じ Ex コマンドを再送しない。既存 `focusPane` の nonfatal 選択結果を入力許可の根拠にしない。

---

# Risks

| リスク | 対策 |
|---|---|
| tmux client の fallback が別 iTerm session を指す | window または同一 session の明示 client だけを許可し、pane ID を送信前に検証する |
| AppleScript の拒否・タイムアウト | 既存 5 秒制限を継承し、入力なしで失敗を上位へ返す |
| Esc が対象 nvim の入力モードを変える | 対象同定を fail-closed にし、固定 Ex を1回だけ送信する。実機でモード別に確認する |
| public `AppState` enum case の追加 | 全 switch を更新し、旧 YAML 回帰テストと文書更新を行う |

---

# Final Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FINAL-VG-build | final | quality | agent | true | `swift build && git diff --check` | task_delta | 両方 exit 0 | exit codes | task_retry_budget / safe_stop | SC-04 | quality |
| FINAL-VG-iterm-manual | final | manual | human | true | 実機手順 | running FocusBM | 対象だけに Ex を1回送る | 人間の観測 | no retry / await_input | SC-03,SC-04 | Automation permission |

# Verification

**Automated**: `swift test && swift build && git diff --check`

**Manual**: iTerm2 の複数 window/tab/session と tmux の複数 pane を使い、正常・複数候補・対象なし・Automation 拒否を確認する。手動ゲートが未実行なら最終状態は `unverified` とする。
