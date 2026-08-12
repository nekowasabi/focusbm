# Process 2: Resolver の command 注入対応と gh 呼び出し移行

## Implementation Brief（コピペ用）

- 背景: `ClaudeSessionPullRequestResolver`（`Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift`、全130行）は `command` が常に `"claude"` 前提で書かれており（第2経路 `sessionIndexPullRequestURL` L79-107 が `~/.claude/sessions/` に依存）、gh 呼び出しも自前の static メソッド（L52-73）で行っている。codex 用にも使えるようにするため、`command` を注入可能にし、gh 呼び出しを P01 の `GitHubPullRequestCLI` へ委譲する。
- 目的: `command` プロパティを public init のデフォルト引数 `"claude"` で注入可能にし、gh 呼び出しを `GitHubPullRequestCLI.resolveURLString` へ委譲する。
- 変更範囲: `Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift`
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| GH_TIMEOUT_SEC | 5 | 秒 | GitHubPullRequestCLI.resolveURLString 呼び出し時のタイムアウト指定 |

- 禁止事項（該当 Don'ts のみ）:
  - 型名 `ClaudeSessionPullRequestResolver` をリネームしない
  - 既存 internal init `init(homeDirectory:fileManager:pullRequestURLProvider:)`（L23-29）のシグネチャを破壊しない（既存テストが注入している）
  - 数値リテラル直書き禁止。`GH_TIMEOUT_SEC` を名前参照する
- 適用される横断方針（インライン展開）:
  - gh CLI をメインスレッドで同期実行しない
  - 既存公開 API はデフォルト引数で互換維持（既存テストを壊さない）
  - gh 失敗・タイムアウト時は nil を返す fail-closed
  - 数値リテラル直書き禁止
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`ClaudeSessionPullRequestResolver` に `command: String`（デフォルト `"claude"`）を追加する。既存の public init にデフォルト引数として追加し、既存呼び出し元（引数なし）の挙動を変えない。`pullRequestURLFromGitHubCLI` の実体を `GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout: GH_TIMEOUT_SEC)` への委譲に置き換える。第2経路 `sessionIndexPullRequestURL`（L79-107）は `command == "claude"` の場合のみ実行するようガードを追加する。

## Affected Files

- `Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift`（L1-130 のうち、init 周辺・`pullRequestURLFromGitHubCLI`・`resolveURL` 内の分岐に変更）

## Symbol Targets

```yaml
- file: Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift
  symbols:
    - name: command
      kind: stored_property
      body_start_line: n/a (新規プロパティ)
      body_end_line: n/a
      line_hint: 10-20 (既存プロパティ群の近辺)
    - name: init (public)
      kind: initializer
      body_start_line: n/a
      body_end_line: n/a
      line_hint: 1-29 付近
    - name: pullRequestURLFromGitHubCLI
      kind: static_method
      body_start_line: 52
      body_end_line: 73
      line_hint: 52-73
    - name: resolveURL(for:workingDirectory:)
      kind: method
      body_start_line: 31
      body_end_line: 37
      line_hint: 31-37
  patch_only: false
  disjoint_guarantee: true  # evidence: rtk cat -n 実測、当該ファイルを触るのは P02 のみ
  pre_flight_checks: [git_clean, "既存 internal init シグネチャ確認（init(homeDirectory:fileManager:pullRequestURLProvider:) L23-29）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P02-VG-01 | red | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | Tests/focusbmTests/SessionPullRequestResolverTests.swift | 追加した command 注入確認テストが「デフォルト実装未対応」等の想定理由で失敗（exit code != 0） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, BEH-02-01 | TEST-RED |
| P02-VG-02 | green | test | agent | true | `swift test --filter SessionPullRequestResolverTests` | Tests/focusbmTests/SessionPullRequestResolverTests.swift, Sources/FocusBMLib/ClaudeSessionPullRequestResolver.swift | exit code == 0（既存テスト無修正で通ることを含む） | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-01, SC-02, BEH-02-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 02
- gate_ids: [P02-VG-01, P02-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-02.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: 型リネームでなく command 注入 — 既存テスト2ファイル（`SessionPullRequestResolverTests.swift`、`SessionPullRequestShortcutTests.swift`）を無傷に保つため。型を分けたり名前を変えたりすると呼び出し元・テストの両方に波及するが、command をプロパティとして持たせるだけなら既存の "claude" 用途は default 引数で無変更のまま維持できる。
- Why: 第2経路（`sessionIndexPullRequestURL`）を `command == "claude"` の場合のみ有効にする — `~/.claude/sessions/` は Claude 固有のディレクトリ構造であり、codex には対応する概念が存在しないため。codex インスタンスは cwd 経路（`workingDirectoryPullRequestURL`）のみで完結させる。
- gh 呼び出しの実体は P01 の `GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout:)` に委譲し、`GH_TIMEOUT_SEC` を渡す。既存の internal init で注入される `pullRequestURLProvider` はテスト用のモック経路として維持し、gh 委譲呼び出しとは別に共存させる（`pullRequestURLProvider` が設定されていればそちらを優先する既存の分岐を壊さない）。

## Behavior Specification

- System Type: transformation

| behavior_id | 入力 | 出力 | pre_state | post_state | invariants | test_ref |
|---|---|---|---|---|---|---|
| BEH-02-01 | command 未指定でインスタンス化 | 従来と同じ挙動（cwd 経路→sessionIndex フォールバック） | resolvers 未生成 | インスタンス生成、command=="claude" | 既存テストが無修正で通る | SessionPullRequestResolverTests（既存一式） |
| BEH-02-02 | command="codex" でインスタンス化 | cwd 経路のみで解決、失敗時 nil | resolvers 未生成 | インスタンス生成、command=="codex" | sessionIndex 経路を呼び出さない | SessionPullRequestResolverTests.codexCommand_doesNotUseSessionIndex（予定名） |

### Correctness Criteria

- SC-01: `command` 省略時のデフォルト値は `"claude"` であり、既存の public/internal init 呼び出し元はソース変更なしでコンパイルが通る。
- SC-02: 既存の `SessionPullRequestResolverTests.swift` および `SessionPullRequestShortcutTests.swift` が無修正のまま green である。
- SC-03: `command == "codex"` のインスタンスは `sessionIndexPullRequestURL` を呼び出さない。

### Left to Implementation

- `command` プロパティの private(set) か let かの選択
- gh 呼び出し委譲箇所の内部ヘルパ関数分割

## Red Phase

- [ ] `Tests/focusbmTests/SessionPullRequestResolverTests.swift` に command 注入・codex 分岐の確認テストを追加し、未実装のため失敗することを確認する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P02-VG-01
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "追加テストが command 未対応により失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `command` プロパティ追加、gh 呼び出しの `GitHubPullRequestCLI` への委譲、`sessionIndexPullRequestURL` の command ガードを実装する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P02-VG-02
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 委譲箇所・分岐の整理（挙動を変えない）
- [ ] `swift test --filter SessionPullRequestResolverTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P02-VG-02
- status: unverified
- command_or_action: swift test --filter SessionPullRequestResolverTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: `command` を省略してインスタンス化し、既存の cwd→sessionIndex フォールバックが変わらないことを既存テストの green で確認する。
- シナリオ2（executor: agent）: `command: "codex"` で注入したインスタンスが `sessionIndexPullRequestURL` を呼ばないことをテストで確認する（呼ばれたら `~/.claude/sessions/` 依存の副作用が起きるため、モックで未呼び出しを検証）。

## Dependencies

- Requires: P01
- Blocks: P03

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はライブラリ内部のリゾルバ実装であり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
