# Process 1: GitHubPullRequestCLI 新設とタイムアウト実装

## Implementation Brief（コピペ用）

- 背景: `ClaudeSessionPullRequestResolver` 内の `pullRequestURLFromGitHubCLI`（L52-73）は `gh pr view` を Process+Pipe で同期実行しているが、タイムアウトがなく、gh がハングするとメインスレッドを含む呼び出し元をブロックしうる。この責務を独立ファイルへ切り出し、タイムアウト付きで再実装する。
- 目的: `gh pr view --json url --jq .url` をタイムアウト付きで実行する `GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout:)` を新設する。
- 変更範囲: `Sources/FocusBMLib/GitHubPullRequestCLI.swift`（新規）、`Tests/focusbmTests/GitHubPullRequestCLITests.swift`（新規）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| GH_TIMEOUT_SEC | 5 | 秒 | gh pr view 実行上限 |

- 禁止事項（該当 Don'ts のみ）:
  - 型名 `ClaudeSessionPullRequestResolver` を変更しない（本 process では触れない）
  - 数値リテラル直書き禁止。`GH_TIMEOUT_SEC` は名前付き定数として定義し参照する
- 適用される横断方針（インライン展開）:
  - gh CLI をメインスレッドで同期実行しない（呼び出し側がバックグラウンドキューから呼ぶ前提。本ファイル自体はスレッド非依存に実装する）
  - gh 失敗・タイムアウト時は nil を返す fail-closed（例外送出・UI 割り込み禁止）
  - 数値リテラル直書き禁止（GH_TIMEOUT_SEC は名前参照）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`gh pr view --json url --jq .url` を `/usr/bin/env gh` 経由で実行し、標準出力の1行を trim して返す static 関数を持つ新規ファイルを作成する。既存の `ClaudeSessionPullRequestResolver.pullRequestURLFromGitHubCLI`（L52-73）のロジックを踏襲しつつ、`DispatchQueue.asyncAfter` によるウォッチドッグでタイムアウト時に `process.terminate()`（必要なら interrupt 後 force）を行う。

## Affected Files

- `Sources/FocusBMLib/GitHubPullRequestCLI.swift`（新規、全体）
- `Tests/focusbmTests/GitHubPullRequestCLITests.swift`（新規、全体）

## Symbol Targets

```yaml
- file: Sources/FocusBMLib/GitHubPullRequestCLI.swift
  symbols:
    - name: GitHubPullRequestCLI
      kind: struct_or_enum
      body_start_line: 1
      body_end_line: n/a (新規ファイル)
      line_hint: n/a
    - name: resolveURLString(workingDirectory:timeout:)
      kind: static_method
      body_start_line: n/a (新規ファイル)
      body_end_line: n/a
      line_hint: n/a
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks: [git_clean]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P01-VG-01 | red | test | agent | true | `swift test --filter GitHubPullRequestCLITests` | Tests/focusbmTests/GitHubPullRequestCLITests.swift | exit code != 0（追加アサーションが想定理由で失敗） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, BEH-01-01 | TEST-RED |
| P01-VG-02 | green | test | agent | true | `swift test --filter GitHubPullRequestCLITests` | Tests/focusbmTests/GitHubPullRequestCLITests.swift, Sources/FocusBMLib/GitHubPullRequestCLI.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, BEH-01-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 01
- gate_ids: [P01-VG-01, P01-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-01.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: 独立ファイルに切り出す（`ClaudeSessionPullRequestResolver` 内に留めない）— P02/P03 で codex 用インスタンスからも同一ロジックを再利用するため、Claude 固有ファイルへの依存を避ける。
- Why: `Timer` でなく `DispatchQueue.asyncAfter` によるウォッチドッグ — RunLoop 非依存で、バックグラウンドキューから呼び出しても確実に発火するため。
- タイムアウト実装は「`asyncAfter` で `GH_TIMEOUT_SEC` 後に `process.terminate()` を呼ぶ」実装を基本とし、`process.terminate()` で止まらない場合は追加で `force` 相当の後処理を検討してよい（内部実装の詳細は Left to Implementation）。
- 既存 `pullRequestURLFromGitHubCLI`（`ClaudeSessionPullRequestResolver.swift` L52-73）のコマンド組み立て・Pipe 読み取りロジックをそのまま移植し、挙動（`/usr/bin/env gh pr view --json url --jq .url`、trim済み1行返却）を変えない。

## Behavior Specification

- System Type: transformation

| behavior_id | 入力 | 出力 | pre_state | post_state | invariants | test_ref |
|---|---|---|---|---|---|---|
| BEH-01-01 | PR が存在する cwd | URL 文字列 | プロセス未実行 | gh 実行済み・terminate 不要 | メインスレッドをブロックしない（呼び出し側規約） | GitHubPullRequestCLITests.resolveURLString_returnsURL_whenGHSucceeds |
| BEH-01-02 | PR が存在しない cwd／gh 失敗 | nil | プロセス未実行 | gh 実行済み（非0終了） | 例外を送出しない | GitHubPullRequestCLITests.resolveURLString_returnsNil_whenGHFails |
| BEH-01-03 | GH_TIMEOUT_SEC 超過 | nil | プロセス実行中 | プロセス terminate 済み | 呼び出し元スレッドは GH_TIMEOUT_SEC 程度で復帰する | GitHubPullRequestCLITests.resolveURLString_returnsNil_whenTimeoutExceeded |

### Correctness Criteria

- SC-01: `resolveURLString` は PR あり cwd で trim 済み URL 文字列を返す。
- SC-02: gh 失敗（非0終了）時は nil を返し、例外を送出しない。
- SC-03: `GH_TIMEOUT_SEC` 超過時は nil を返し、プロセスを terminate する。
- SC-04: 数値リテラル `5` は `GH_TIMEOUT_SEC` という名前付き定数として1箇所に定義されている。

### Left to Implementation

- ウォッチドッグ用の内部ヘルパ関数名・分割方法
- `terminate()` 後の `interrupt`/force 処理の具体的な段階分け

## Red Phase

- [ ] `Tests/focusbmTests/GitHubPullRequestCLITests.swift` を作成し、BEH-01-01〜03 に対応するテストを書く（`GitHubPullRequestCLI` 未実装のためコンパイルエラーまたはテスト失敗になることを確認）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P01-VG-01
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "テストが GitHubPullRequestCLI 未実装により失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `Sources/FocusBMLib/GitHubPullRequestCLI.swift` を実装し、Red Phase のテストを通す

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P01-VG-02
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 命名・重複コードの整理（挙動を変えない）
- [ ] `swift test --filter GitHubPullRequestCLITests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P01-VG-02
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: PR が存在するリポジトリの cwd で `resolveURLString` を呼び、URL 文字列が返ることを `swift test` の出力で確認する。データ状態: テスト内でモック（`pullRequestURLProvider` 相当の注入経路がなければ実 gh 呼び出しをスキップするテスト設計にする）。
- シナリオ2（executor: agent）: gh を持たない/失敗する環境相当の入力で nil が返ることを `swift test` の出力で確認する。

## Dependencies

- Requires: なし
- Blocks: P02, P05, P11

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はライブラリ内部のプロセス実行機能であり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
