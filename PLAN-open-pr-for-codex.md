---
task_id: "T-20260730-open-pr-for-codex"
title: "Codex セッションの PR オープン対応と絞り込み画面への PR 番号表示"
status: planning
created: "2026-07-30"
scope:
  - Sources/FocusBMLib/SessionPullRequestResolver.swift
  - Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift
  - Sources/FocusBMLib/GitHubPullRequestCLI.swift
  - Sources/FocusBMApp/SearchViewModel.swift
  - Sources/FocusBMApp/BackgroundRefreshService.swift
  - Sources/FocusBMApp/BookmarkRow.swift
  - Sources/FocusBMApp/SearchView.swift
depends_on: []
risk_flags:
  - performance
  - external_api
  - frontend
quality_gate:
  command: "swift build && swift test"
  min_quality_score: "-"
commit_mode: manual
loop_ready: true
---

# Commander's Intent

## Purpose
Codex セッションでも既存の PR オープン体験（cmd+p）を提供し、絞り込み画面で PR 有無を一目で把握できるようにする。PR 解決の第1経路（cwd + `gh pr view`）は Claude 固有情報を含まない汎用実装であり、リゾルバ登録の拡大と表示配線のみで実現できる。

## End State
Claude / Codex 双方の cwd ベース PR 解決が共有ロジック（タイムアウト付き）で動作し、SearchPanel の各 AI エージェント行に PR 番号がバックグラウンド解決・キャッシュ経由で表示される。

## Key Tasks
- gh 呼び出しの共有化・タイムアウト化と Codex 向けリゾルバ登録（機能A）
- cwd 単位 PR キャッシュと BackgroundRefreshService での並列解決（機能Bの基盤）
- BookmarkRow への PR 番号バッジ表示配線（機能Bの可視化）

---

# ★ Constants（唯一の正・他は定数名で参照）

| 定数名 | 値 | 単位 | 備考 |
|-------|-----|------|------|
| GH_TIMEOUT_SEC | 5 | 秒 | gh pr view 実行上限（既存は無制限） |
| PR_CACHE_TTL_SEC | 300 | 秒 | cwd 単位 PR キャッシュの有効期限 |
| PR_RESOLVE_MAX_CONCURRENT | 4 | 個 | 同一周期内の gh 並列実行数上限 |
| BACKGROUND_REFRESH_INTERVAL_SEC | 15 | 秒 | 既存値。変更しない |
| GATE_ID_FORMAT_PROCESS | `P{NN}-VG-{NN}` | - | process 内ゲート ID |
| GATE_ID_FORMAT_INTEGRATION | `W{NN}-IG-{NN}` | - | wave 統合ゲート ID |
| GATE_ID_FORMAT_FINAL | `FINAL-VG-{NN}` | - | 最終ゲート ID |
| GATE_TABLE_COLUMNS | 12 | 列 | Verification Gates 表の列数 |
| AGGREGATE_KEY_FORMAT | `{task_id}:{gate_id}` | - | gate-results.jsonl 集約キー |
| MAX_CONFLICT_MATRIX_ROWS | 50 | 行 | 超過時は process 分割を warn |
| MIN_PARALLEL_DIFF_LINES | 10 | 行 | 未満は wave 並列でなく serial 化 |
| SYMBOL_LINE_TOLERANCE | 20 | 行 | symbol 行番号推定の許容ずれ |

> 数値の単一ソース。他箇所では定数名のみ参照し数値直書きしない。

---

# Scope

**対象**: Codex で cmd+p による PR オープン有効化（要件A） / cwd 経由の汎用 gh 解決を Claude・Codex で共有 / gh 呼び出しへの GH_TIMEOUT_SEC 導入（無制限ハング是正） / SearchPanel の PR 番号バッジ表示（要件B） / BackgroundRefreshService での cwd 単位 PR 並列解決 + TTL キャッシュ

**対象外**: aider/gemini/copilot/hermes 等への拡大（Codex 限定要件） / CLI 側 PR 表示（SearchPanel 限定） / `.bookmark`/`.floatingWindow` 行への PR 表示（cwd なし） / gh 未インストール環境の専用エラー表示（既存 fail-closed 踏襲、バッジ非表示のみ） / PR のマージ/クローズ状態の視覚差分（番号表示のみ） / session-index フォールバックの Codex 対応（Codex は該当構造なし）

---

# Assumptions / Open Questions

| 種別 | 項目 | 内容 | 外部挙動への影響 | 解決方針 |
|------|------|------|----------------|------------------------|
| Assumption | Codex 対応方式 | `ClaudeSessionPullRequestResolver` に command 注入可能化（既定 "claude"）、"codex" にも登録。型名は不変 | supports("codex")==true | 採択済み |
| Assumption | バッジ表示形式 | `#123` 形式を下段 HStack に表示。未取得時は非表示 | 表示のみ | 採択済み |
| Assumption | タイムアウト実装 | Foundation に組込みなしのため遅延 terminate 方式で自作 | GH_TIMEOUT_SEC 超過で nil | Process 1 |

---

# Required Sections（risk_flags 連動）

| Flag | 必須セクション | 反映先 |
|------|---------------|--------|
| performance | 並列度上限・TTL・タイムアウト制約 | process-01/05 |
| external_api | gh CLI 依存・失敗時フォールバック | process-01/05 |
| frontend | Frontend Constraints | process-04/06 |

> 対象外: security / multi_id / data_migration / backwards_incompatible（新規認証情報なし・ID体系不変・永続データ不変・API互換維持）

# Decision-Complete チェック（15観点）

| 観点 | 状態 | 記載先 |
|------|------|-------------------|
| Goal / Success Criteria | 済 | Commander's Intent + Acceptance Criteria |
| Scope / Non-goals | 済 | Scope |
| Existing Behavior | 済 | Scope 対象外 |
| Public Interfaces | 済 | 各 process の Behavior Spec |
| Data Model / State | 済 | prURLCache の pre/post state |
| Behavior / Edge Cases | 済 | 各 process 異常系 |
| Error Handling | 済 | gh失敗はnil/非表示 |
| Security / Privacy | 対象外: gh既存認証のみ、URL構造検証済み | - |
| Performance / Scalability | 済 | PR_RESOLVE_MAX_CONCURRENT等 |
| Concurrency / Async | 済 | process-05 状態遷移 |
| Migration / Compatibility | 対象外: 永続データ不変・API互換 | - |
| Observability | 対象外: 専用ログ要件外 | - |
| Testing | 済 | Acceptance Criteria + Red/Green/Refactor |
| Rollout / Operations | 対象外: 既存bundle.shのみ | - |
| Maintainability | 済 | gh呼び出し集約 |

---

# Progress Map

| Process | Title | Status | Disjoint | Type | File |
|---------|-------|--------|----------|------|------|
| 01 | GitHubPullRequestCLI 新設とタイムアウト実装 | ☐ planning | y | 変換 | [→ process-01](plan-open-pr-for-codex/process-01.md) |
| 02 | Resolver の command 注入対応と gh 呼び出し移行 | ☐ planning | y | 変換 | [→ process-02](plan-open-pr-for-codex/process-02.md) |
| 03 | codex リゾルバ登録（機能A本体） | ☐ planning | y | 変換 | [→ process-03](plan-open-pr-for-codex/process-03.md) |
| 04 | SearchViewModel の prURLCache + prLabel(for:) | ☐ planning | y | 変換 | [→ process-04](plan-open-pr-for-codex/process-04.md) |
| 05 | BackgroundRefreshService の PR 並列解決（機能B本体） | ☐ planning | n.a. | react | [→ process-05](plan-open-pr-for-codex/process-05.md) |
| 06 | BookmarkRow への prLabel 表示 | ☐ planning | y | 変換 | [→ process-06](plan-open-pr-for-codex/process-06.md) |
| 10 | [test] codex リゾルバ対応テスト | ☐ planning | y | - | [→ process-10](plan-open-pr-for-codex/process-10.md) |
| 11 | [test] gh タイムアウトのユニットテスト | ☐ planning | y | - | [→ process-11](plan-open-pr-for-codex/process-11.md) |
| 12 | [test] prLabel キャッシュ挙動テスト | ☐ planning | y | - | [→ process-12](plan-open-pr-for-codex/process-12.md) |
| 13 | [test] BookmarkRow バッジ表示テスト | ☐ planning | y | - | [→ process-13](plan-open-pr-for-codex/process-13.md) |
| 50 | [follow] 既存ショートカットテスト回帰確認 | ☐ planning | n.a. | - | [→ process-50](plan-open-pr-for-codex/process-50.md) |
| 100 | [quality] build / test 全体通過確認 | ☐ planning | n.a. | - | [→ process-100](plan-open-pr-for-codex/process-100.md) |
| 200 | [docs] README / architecture 更新 | ☐ planning | n.a. | - | [→ process-200](plan-open-pr-for-codex/process-200.md) |
| 300 | [OODA] レトロスペクティブ | ☐ planning | n.a. | - | [→ process-300](plan-open-pr-for-codex/process-300.md) |

**Type**: 変換=transformation / react=reactive / `-`=doc-only。**Disjoint**: y=並列可 / n=worktree必須 / n.a.=非該当。
**DAG**: `1→{2,11} | 2→3→{10,50} | 4→{5,6,12} | 1→5 | 6→13 | {10,11,12,13,50}→100→200→300`
**Overall**: ☐ 0/14 completed
> Disjoint 列は各 process の Symbol Targets の disjoint_guarantee から転記。根拠は rtk cat -n 実測読了。process-05 のみシグネチャ波及のため n.a.。

---

# Wave Progress Map

> 相互依存なし かつ Conflict Matrix 上で symbol 衝突なしの Process 群を同一 Wave にまとめる。

| Wave | Processes | Depends on Wave | Disjoint | Status |
|------|-----------|------------------|----------|--------|
| W01 | P01, P04 | - | y | ☐ planning |
| W02 | P02, P05, P11, P12 | W01 | y（P02=Lib/P05=App/テストは別ファイル） | ☐ planning |
| W03 | P03, P06 | W02 | y（P03=Lib/P06=App、競合なし） | ☐ planning |
| W04 | P10, P13, P50 | W03 | y（各テストファイル独立） | ☐ planning |
| W05 | P100 | W04 | n.a. | ☐ planning |
| W06 | P200 | W05 | n.a. | ☐ planning |
| W07 | P300 | W06 | n.a. | ☐ planning |

---

# Execution Contract

> 機械可読な正本は refs/make-plan-gates.md §1 の execution_contract スキーマ準拠。本セクションは要約参照。

```yaml
execution_contract:
  schema_version: 2
  plan_revision: 1
  task_id: "T-20260730-open-pr-for-codex"
  loop_ready: true
  objective: "Claude/Codex 双方の cwd ベース PR 解決が共有ロジックで動作し、SearchPanel 行に PR 番号がバックグラウンド反映される"
  goal_condition_projection: "codex セッションで cmd+p が PR を開き、絞り込み画面に PR 番号バッジが遅延なく（未取得時は非表示のまま）表示され、swift build && swift test が exit 0"
  non_goals: ["aider/gemini 等への拡大", "CLI 側表示", "PR 状態の視覚差分", "session-index 経路の Codex 対応"]
  constraints: ["gh をメインスレッドで同期実行しない", "SearchItem enum にケース追加しない", "既存公開 API はデフォルト引数で互換維持", "失敗時 UI 割り込み禁止（バッジ非表示のみ）"]
  success_criteria:
    - {id: SC-01, statement: "supports(command:\"codex\") == true かつ codex の cwd から PR URL が解決される"}
    - {id: SC-02, statement: "gh 呼び出しが GH_TIMEOUT_SEC で打ち切られ nil を返す"}
    - {id: SC-03, statement: "prLabel がキャッシュ有→\"#<番号>\" / 無→nil を返し、BookmarkRow がバッジ表示/非表示を切替える"}
    - {id: SC-04, statement: "同一周期内の同一 cwd への重複 gh 呼び出しゼロ、TTL 内キャッシュはスキップされる"}
    - {id: SC-05, statement: "swift build && swift test が exit 0（既存41+新規テスト全通過）"}
  policies:
    - {id: TEST-RED, statement: "期待した理由で失敗する"}
    - {id: TEST-GREEN, statement: "対象テストが成功する"}
    - {id: SCOPE-01, statement: "変更を Affected Files 内に限定する"}
    - {id: DONT-01, statement: "禁止事項を新規導入しない"}
    - {id: QUALITY-01, statement: "品質コマンドが成功する"}
  gates: "各 process の Verification Gates 表 + Integration/Final Gates（下記）の全行"
  required_gates: [P01-VG-01, P01-VG-02, P02-VG-01, P02-VG-02, P03-VG-01, P03-VG-02, P04-VG-01, P04-VG-02, P05-VG-01, P05-VG-02, P06-VG-01, P06-VG-02, P10-VG-01, P11-VG-01, P12-VG-01, P13-VG-01, P50-VG-01, P100-VG-01, W03-IG-01, FINAL-VG-01, FINAL-VG-02]
  completion_rule: "全 required_gates が pass かつ必須条件に Unverified がない"
  await_input_rule: "人間の判断または承認を得れば安全に再開できる"
  safe_stop_rule: "再試行枯渇、取得不能な権限、破壊的判断、安全な継続不能"
  change_set_source: "git_task_delta"
  evidence_projection: evaluator_visible_summary
```

---

# Conflict Matrix

| Process | Symbols (file:symbol) | Disjoint | Confidence | Evidence |
|---------|----------------------|----------|------------|----------|
| 01 | Sources/FocusBMLib/GitHubPullRequestCLI.swift:resolveURLString | true | medium | 新規ファイル（衝突対象なし） |
| 02 | Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift:init / :command / :pullRequestURLFromGitHubCLI | true | high | rtk cat -n 実測読了（02のみ触る） |
| 03 | Sources/FocusBMLib/SessionPullRequestResolver.swift:init() | true | high | rtk cat -n 実測読了（03のみ触る） |
| 04 | Sources/FocusBMApp/SearchViewModel.swift:prURLCache / :applyBackgroundCache / :prLabel(for:) | true | high | rtk cat -n 実測読了（04のみ触る） |
| 05 | Sources/FocusBMApp/BackgroundRefreshService.swift:refresh() | n/a | high | applyBackgroundCache のシグネチャ変更(P04)に依存 |
| 06 | Sources/FocusBMApp/BookmarkRow.swift:body / Sources/FocusBMApp/SearchView.swift:body | true | high | rtk cat -n 実測読了（06のみ触る） |
| 10 | Tests/focusbmTests/SessionPullRequestResolverTests.swift | true | high | テストファイル1:1対応 |
| 11 | Tests/focusbmTests/GitHubPullRequestCLITests.swift | true | high | 新規テストファイル |
| 12 | Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift | true | high | 新規テストファイル |
| 13 | Tests/FocusBMAppTests/BookmarkRowPRLabelTests.swift | true | high | 新規テストファイル |
| 50 | Tests/FocusBMAppTests/SessionPullRequestShortcutTests.swift | n/a | high | 回帰確認のみ |
| 100 | - | n/a | high | build/test実行のみ |
| 200 | README.md / stigmergy/focusbm-architecture.md | n/a | high | doc-only |
| 300 | - | n/a | high | レトロスペクティブのみ |

---

# Integration Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---------|-------|------|----------|----------|---------|-------------|---------------|---------------|----------------|----------------|-------------|
| W03-IG-01 | green | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | W01〜W03 の task_delta 和集合 | exit 0 かつ失敗テスト0件（codex登録+command注入+タイムアウトの統合確認） | GoalEvidence（observedに出力末尾1行を逐語引用） | {failure_class: test_failure, retryable: true, retry_budget_source: task_retry_budget, terminal_action: await_input} | SC-01, SC-02 | TEST-GREEN, SCOPE-01 |

---

# Acceptance Criteria（要約）

**機能**: Codex選択中に cmd+p で PR がブラウザで開く / 絞り込み画面の対象行にキャッシュ済みPR番号が `#123` 形式で表示 / 未取得時は非表示、バックグラウンド解決後に反映

**品質・安全**: gh呼び出しは GH_TIMEOUT_SEC でタイムアウトしメインスレッドを塞がない。swift test全通過。gh失敗時はバッジ非表示のみ（UI割り込みなし）。

**ドキュメント**: README/architecture に既存記述があれば Codex対応・PR表示を反映（Process 200）。

---

# Docs to Update

| パス | 更新内容 | 必須条件 |
|------|---------|----------|
| README.md | cmd+p対応エージェントにCodex追記、PR番号表示機能を追記 | 対応エージェント一覧またはClaude専用記述が存在する場合のみ |
| stigmergy/focusbm-architecture.md | リゾルバ登録拡大とPRキャッシュ機構を追記 | 該当コンポーネント説明が既存する場合 |
| bookmarks.example.yml | 対象外: bookmarks.ymlスキーマに影響しない | 新設定キー追加時のみ（本計画では追加なし） |

---

# Don'ts（禁止事項）

- `ClaudeSessionPullRequestResolver` の型名・公開APIをテスト側修正なしに破壊的変更しない（pattern: `grep -rn "class CwdSessionPullRequestResolver" Sources/` で0件）
- gh CLI をメインスレッドで同期実行しない（type: review で確認）
- `SearchItem` enum に新規ケースを追加しない（pattern: `git diff` でSearchItem enumへの `case` 追加行0件）
- PR取得失敗時にUIへエラーダイアログ等の割り込みを出さない（pattern: `grep -rn "NSAlert" Sources/FocusBMApp/` で新規出現0件）
- ★ Constants の値をコード・コメントに数値直書きしない（定数定義箇所を除く）

---

# Risks

| リスク | 対策 |
|--------|------|
| gh並列呼び出しのプロセス爆発（cwd多数環境） | PR_RESOLVE_MAX_CONCURRENT で同時実行制限、TTLキャッシュで頻度抑制 |
| Process.terminate() がgh子プロセスを殺せずゾンビ残留 | Process 1実装時にforce終了の要否をテストで検証 |
| cwdキーの一意性崩れ（シンボリックリンク差異） | 実害は無駄なgh呼び出しのみ。標準化はしない（Noticed but not fixing） |

---

# Final Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---------|-------|------|----------|----------|---------|-------------|---------------|---------------|----------------|----------------|-------------|
| FINAL-VG-01 | final | quality | agent | true | `swift build && swift test` | task_delta 全体 | exit 0 かつ失敗テスト0件 | GoalEvidence（observedにテストサマリー行を逐語引用） | {failure_class: quality_failure, retryable: true, retry_budget_source: task_retry_budget, terminal_action: await_input} | SC-01, SC-02, SC-03, SC-04, SC-05 | QUALITY-01, TEST-GREEN |
| FINAL-VG-02 | final | conformance | agent | true | `git diff --name-only <base>..HEAD` をScope frontmatterのAffected Filesと突合し、Don'tsのgrepパターンをtask_deltaに対して実行 | task_delta 全体 | 集合外の変更ファイル0件、かつDon'ts grepの新規違反0件 | GoalEvidence（observedにdiffファイル数とgrep件数を記載） | {failure_class: conformance_failure, retryable: false, retry_budget_source: task_retry_budget, terminal_action: await_input} | SC-05 | SCOPE-01, DONT-01 |

---

# Verification

**Manual**: 各processのManual Verification参照（Codex実セッションでのcmd+p、バッジ表示の実機確認はexecutor: human）
**Automated**: `swift build && swift test`
