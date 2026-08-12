# Process 3: codex リゾルバ登録（機能A本体）

## Implementation Brief（コピペ用）

- 背景: `SessionPullRequestResolver.init()`（`Sources/FocusBMLib/SessionPullRequestResolver.swift` L17-20）は `["claude": ClaudeSessionPullRequestResolver()]` のみを登録しており、`supports(command:)`（L26-28）は `"codex"` に対して false を返す。P02 で command 注入対応が完了したため、codex 用インスタンスを登録する。
- 目的: `init()` を変更し、`"claude"` と `"codex"` の両方を resolvers に登録する。
- 変更範囲: `Sources/FocusBMLib/SessionPullRequestResolver.swift`
- ローカル定数表: 本 process で使用するローカル定数はなし（PR_RESOLVE_MAX_CONCURRENT は設計余地として P01 で言及済みで、本 process では未使用）
- 禁止事項（該当 Don'ts のみ）:
  - 型名 `ClaudeSessionPullRequestResolver` を変更しない
  - `init(resolvers:)`（L22-24、拡張点）のシグネチャを破壊しない
- 適用される横断方針（インライン展開）:
  - 既存公開 API はデフォルト引数で互換維持（既存テストを壊さない）
  - gh 失敗・タイムアウト時は nil を返す fail-closed（P01/P02 で担保済みの経路をそのまま利用）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`SessionPullRequestResolver.init()`（L17-20）内の resolvers 初期化を `["claude": ClaudeSessionPullRequestResolver(), "codex": ClaudeSessionPullRequestResolver(command: "codex")]` に変更する。`supports(command:)`（L26-28）のロジック自体は変更不要（resolvers に登録されたキーの有無を見る実装のため、登録が増えれば自然に `supports("codex")` が true になる想定）。

## Affected Files

- `Sources/FocusBMLib/SessionPullRequestResolver.swift`（L17-20 の init() 内、resolvers 辞書リテラル）

## Symbol Targets

```yaml
- file: Sources/FocusBMLib/SessionPullRequestResolver.swift
  symbols:
    - name: init()
      kind: initializer
      body_start_line: 17
      body_end_line: 20
      line_hint: 17-20
  patch_only: true
  disjoint_guarantee: true  # evidence: rtk cat -n 実測、当該ファイルを触るのは P03 のみ
  pre_flight_checks: [git_clean, symbol_exists]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P03-VG-01 | red | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | Tests/focusbmTests/SessionPullRequestResolverTests.swift | codex 登録確認テストが「supports(\"codex\") が false」という想定理由で失敗（exit code != 0） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, BEH-03-01 | TEST-RED |
| P03-VG-02 | green | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | Tests/focusbmTests/SessionPullRequestResolverTests.swift, Sources/FocusBMLib/SessionPullRequestResolver.swift | exit code == 0 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, SC-02, BEH-03-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 03
- gate_ids: [P03-VG-01, P03-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-03.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: `init(resolvers:)`（既存の拡張点、L22-24）を使わず `init()` 自体を変更する — codex 登録はデフォルトの標準構成として全呼び出し元に一律で有効化すべき機能であり、呼び出し元ごとに `init(resolvers:)` で個別に組み立てさせるのは「機能Aの標準提供」という目的に対して余計な手間を強いるため。
- codex 用インスタンスは P02 で追加した `command: "codex"` 注入経路を使う。P02 の invariants（command="codex" は sessionIndex 経路を使わない）により、codex 用インスタンスは cwd 経路のみで解決する。
- `supports(command:)`（L26-28）の実装がキー存在チェックである前提を踏まえ、本 process ではロジック変更を行わない（実装が異なっていた場合は pre_flight で確認し、必要なら本 process 内で対応する）。

## Behavior Specification

- System Type: transformation

| behavior_id | 入力 | 出力 | pre_state | post_state | invariants | test_ref |
|---|---|---|---|---|---|---|
| BEH-03-01 | `SessionPullRequestResolver()` 生成 | resolvers に "claude"・"codex" 両キーが存在 | resolvers={"claude": r} | resolvers={"claude": r1, "codex": r2} | supports("codex")==true、supports("aider")==false は不変 | SessionPullRequestResolverTests.codexResolver_isRegistered（予定名） |

### Correctness Criteria

- SC-01: `SessionPullRequestResolver().supports(command: "codex")` が true を返す。
- SC-02: `SessionPullRequestResolver().supports(command: "aider")`（未対応コマンド）が false を返す（既存不変の再確認）。

### Left to Implementation

- なし（辞書リテラルへの1エントリ追加のみで完結する想定）

## Red Phase

- [ ] `SessionPullRequestResolverTests.swift` に `supports("codex")==true` および `supports("aider")==false` のテストを追加し、現状（"codex" 未登録）で失敗することを確認する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P03-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "supports(\"codex\") が false のため失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `init()`（L17-20）の resolvers に `"codex": ClaudeSessionPullRequestResolver(command: "codex")` を追加する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P03-VG-02
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 追加箇所の可読性確認（挙動を変えない、辞書リテラルの整形のみ許容）
- [ ] `swift test --filter SessionPullRequestResolverTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P03-VG-02
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: `SessionPullRequestResolver().supports(command: "codex")` が true を返すことを `swift test` の出力で確認する。
- シナリオ2（executor: human）: 実際の Codex セッション（cwd に GitHub リポジトリ）で cmd+p を押し、絞り込み画面に PR 番号が表示され、選択すると GitHub PR がブラウザで開くことを目視確認する。データ状態確認: 対象セッションの cwd に対応する GitHub リポジトリに実際に PR が存在すること。

## Dependencies

- Requires: P02
- Blocks: P10, P50

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はライブラリ内部のリゾルバ登録変更であり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない（メニューバー UI 上の目視確認は Manual Verification のシナリオ2で扱う）。
