---
task_id: "T-20260701-fix-focus"
title: "tmux AI エージェント選択時のターミナル誤表示修正"
status: planning
created: "2026-07-01"
scope:
  - Sources/FocusBMLib/TmuxProvider.swift
  - Sources/FocusBMLib/ActivationTarget.swift
  - Tests/focusbmTests/TmuxProviderTests.swift
  - Tests/focusbmTests/ActivationTargetTests.swift
  - README.md
  - README_ja.md
depends_on: []
risk_flags:
  - frontend
  - performance
quality_gate:
  command: "swift test"
  min_quality_score: "-"
commit_mode: manual
---

# Commander's Intent

## Purpose
絞り込み画面で AI エージェントの tmux pane を選んだとき、取得済みの tmux client / terminal 対応情報を実際のフォーカス処理へ反映し、意図しないターミナルで session/window が表示される問題をなくす。

## End State
選択した tmux pane は、その pane が属する tmux window に対応する client tty を優先して切り替えられ、対応情報がない場合のみ既存の安全なフォールバックに戻る。

## Key Tasks
- tmux client 対応情報を session 単位ではなく window 単位で保持する。
- `switch-client -c <tty>` を到達可能なフォーカス経路に組み込む。
- 回帰テストと README の tmux 連携説明を更新する。

---

# ★ Constants（唯一の正・他は定数名で参照）

| 定数名 | 値 | 単位 | 備考 |
|-------|-----|------|------|
| SYMBOL_LINE_TOLERANCE | 10 | 行 | symbol 行番号推定の許容幅 |
| MIN_PARALLEL_DIFF_LINES | 20 | 行 | micro-exec 並列化候補から小差分を除外する目安 |
| MAX_CONFLICT_MATRIX_ROWS | 40 | 行 | Conflict Matrix の肥大化警告しきい値 |
| MAX_TERMINAL_ANCESTOR_DEPTH | 10 | 段 | 既存の端末祖先プロセス探索上限 |

> このセクションが数値の単一ソース。process ファイルおよびコード・コメントでは定数名のみを参照し、数値リテラルを書かない。

---

# Scope

**対象**:
- `TmuxProvider` の client map 構築・pane への terminal/client 情報付与・focusPane 分岐
- `ActivationTarget` の terminal client 情報の扱い（必要最小限）
- `TmuxProviderTests` / `ActivationTargetTests` の回帰テスト
- README の tmux 連携・ターミナル検出説明

**対象外（理由付き）**:
- tmux session/window の新規作成機能 — 今回は既存 pane のフォーカス不具合修正に限定
- AI エージェント検出条件の追加 — 誤表示の原因は検出条件ではなくフォーカス先選択
- ブラウザ・floating window 復元 — tmux 経路と独立
- ターミナルアプリ別の AppleScript 個別制御 — `switch-client -c` と既存 activate で直せる範囲を先に固定

---

# Assumptions / Open Questions（外部挙動に影響する未決定事項）

| 種別 | 項目 | 内容 | 外部挙動への影響 | 解決方針 |
|------|------|------|----------------|----------|
| Assumption | 同一 session 複数 client | `tmux list-clients` で得られる現在 window が pane の window と一致する client を最優先する | 対象 window を表示する terminal の選択精度が上がる | Process 01 で実装し Process 10 で固定 |
| Assumption | 対応 client 不在 | window 単位の client が見つからない場合は session 単位の既存フォールバックを使う | detached session や非表示 window でも既存動作を壊さない | Process 01 の Behavior Specification に固定 |

---

# Required Sections（risk_flags 連動）

| Flag | 必須セクション | 反映先 |
|------|---------------|--------|
| frontend | Frontend Constraints | process-01 / process-10 |
| performance | Performance & Scalability | process-01 / process-10 |

対象外: security — 認証・秘密情報・外部通信を扱わない。  
対象外: external_api — 外部 API 追加なし。  
対象外: multi_id — 永続 ID 設計なし。  
対象外: data_migration — データ保存形式変更なし。  
対象外: backwards_incompatible — 既存 YAML 設定の互換性を維持する。

# Decision-Complete チェック（15観点）

| 観点 | 状態 | 記載先 / 対象外理由 |
|------|------|-------------------|
| Goal / Success Criteria | 記載済 | Commander's Intent + Acceptance Criteria |
| Scope / Non-goals | 記載済 | Scope |
| Existing Behavior（変えないもの） | 記載済 | Scope 対象外 / Don'ts |
| Public Interfaces / Contracts | 記載済 | process-01 Behavior Specification |
| Data Model / State | 記載済 | process-01 post_state |
| Behavior / Edge Cases | 記載済 | process-01 / process-10 |
| Error Handling | 記載済 | process-01 detached / fallback 分岐 |
| Security / Privacy | 対象外: 理由記載済 | Required Sections |
| Performance / Scalability | 記載済 | process-01 / process-10 |
| Concurrency / Async | 記載済 | process-01 reactive 分岐 |
| Migration / Compatibility | 記載済 | process-01 互換性基準 |
| Observability | 記載済 | process-01 debug log 方針 |
| Testing | 記載済 | process-10 |
| Rollout / Operations | 記載済 | process-200 |
| Maintainability | 記載済 | process-300 |

> **Left to Implementation 禁則**: 外部挙動・データ契約・エラー挙動・ユーザー体験・セキュリティ・互換性・テスト条件は Left to Implementation に残さない。

---

# Progress Map

| Process | Title | Status | Disjoint | Type | File |
|---------|-------|--------|----------|------|------|
| 01 | tmux client window 対応と focusPane 経路修正 | ☐ planning | n | react | [→ plan-fix-focus/process-01.md](plan-fix-focus/process-01.md) |
| 10 | tmux フォーカス回帰テスト追加 | ☐ planning | n | 変換 | [→ plan-fix-focus/process-10.md](plan-fix-focus/process-10.md) |
| 200 | README tmux 連携説明更新 | ☐ planning | n.a. | - | [→ plan-fix-focus/process-200.md](plan-fix-focus/process-200.md) |
| 300 | OODA レトロスペクティブと知見保存 | ☐ planning | n.a. | - | [→ plan-fix-focus/process-300.md](plan-fix-focus/process-300.md) |

**Type 列凡例**:
- `変換` = transformation / `react` = reactive / `both` = 両面 / `-` = behavior_scope:false

**Disjoint 列凡例**:
- `y` = 並列実行可 / `n` = worktree isolation または直列推奨 / `n.a.` = symbol_targets 非該当

**DAG**: `01→10→200→300`
**DAG凡例**: `{A,B}` = 並列実行可能、`A→B` = A完了後にB実行、`|` = 独立した依存チェーン
**Overall**: ☐ 0/4 completed

---

# Conflict Matrix

| Process | Symbols (file:symbol) | Disjoint | Confidence | Evidence |
|---------|----------------------|----------|------------|----------|
| 01 | Sources/FocusBMLib/TmuxProvider.swift:buildClientMap | false | medium | Serena overview + code lines |
| 01 | Sources/FocusBMLib/TmuxProvider.swift:parseClientMapOutput | false | medium | Serena overview + code lines |
| 01 | Sources/FocusBMLib/TmuxProvider.swift:listAllPanes | false | medium | Serena overview + code lines |
| 01 | Sources/FocusBMLib/TmuxProvider.swift:focusPaneArgs | false | medium | Serena overview + code lines |
| 01 | Sources/FocusBMLib/TmuxProvider.swift:focusPane | false | medium | Serena overview + code lines |
| 01 | Sources/FocusBMLib/ActivationTarget.swift:activate | true | medium | Serena overview + code lines |
| 10 | Tests/focusbmTests/TmuxProviderTests.swift | false | medium | test file |
| 10 | Tests/focusbmTests/ActivationTargetTests.swift | true | medium | test file |
| 200 | README.md / README_ja.md | n/a | high | doc-only |
| 300 | - | n/a | high | process-only |

---

# Acceptance Criteria（要約）

**機能要件**:
- [ ] window 単位で一致する tmux client tty がある場合、その tty を `switch-client -c` の対象にする。
- [ ] window 単位の client が無い場合は session 単位フォールバックを維持する。
- [ ] `preferredTerminal` は terminal 表示名の上書きではなく、client tty 選択を破壊しない。
- [ ] 選択後は対象 pane が属する window と pane が tmux 上で選択される。

**品質・安全**:
- API なし。HTTP ステータス網羅は対象外。
- 既存 YAML と既存ブックマーク復元経路を破壊しない。
- `tmux` コマンド失敗時の既存 non-fatal / fatal 方針を維持する。

**ドキュメント**:
- README / README_ja に window 単位 client 選択とフォールバックの説明を追加する。

---

# Docs to Update

| パス | 更新内容 | 必須条件 |
|------|---------|----------|
| README.md | tmux Integration の Terminal detection 説明を更新 | Process 01 完了後 |
| README_ja.md | tmux 連携のターミナル検出説明を日本語で追加 | Process 01 完了後 |

---

# Don'ts（禁止事項）

- `preferredTerminal` だけで全 tmux pane の表示先を強制しない。
- `clientTTY` が存在する pane を detached 扱いしない。
- 同一 session 内の全 window に同じ terminal 情報を無条件コピーしない。
- `switch-client` 失敗時に既存の `select-window` / `select-pane` フォールバックまで止めない。
- README で「必ず特定ウィンドウを前面化できる」と断定しない。アプリ内の最前面 window は OS / terminal 側の挙動に依存する。

---

# Risks

| リスク | 対策 |
|--------|------|
| tmux client の window 情報が現在表示中 window しか表さない | window 一致を最優先し、不一致時は session フォールバックに限定 |
| 同一 terminal アプリの複数 window は bundleId activate だけでは完全指定できない | 今回は `switch-client -c` で tmux client を固定し、AX window 制御は対象外として明記 |
| tmux バージョン差で format 展開が空になる | parse 時に空欄を許容し、既存フォールバックを維持 |

---

# Verification

**Manual**: 詳細は各 process の Manual Verification を参照  
**Automated**: `swift test`  
**Rebuild test 観点**: この PLAN と process ファイルだけで、外部挙動が「window 一致 client 優先・session fallback 維持」と再現されること。  
**解釈一意性テスト**: 重要判断は `switch-client -c` の到達不能解消と window 単位 client map に限定され、実装者間で外部挙動が分岐しないこと。
