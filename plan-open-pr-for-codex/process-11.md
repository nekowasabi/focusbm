# Process 11: gh タイムアウトテスト

## Implementation Brief（コピペ用）

- 背景: P01 で新設される `GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout:)` は `GH_TIMEOUT_SEC` 超過時に呼び出し元プロセスを terminate して nil を返す設計だが、この挙動が実装通りに動くこと（呼び出しがタイムアウト値+マージン内に戻ること）をテストで担保する必要がある。
- 目的: `Tests/focusbmTests/GitHubPullRequestCLITests.swift` にタイムアウト・正常系・異常系のテストを追加する。
- 変更範囲: `Tests/focusbmTests/GitHubPullRequestCLITests.swift`（P01 で新設されたファイルへの追記、または P01 が未着手ならテストファイル自体を新設）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| GH_TIMEOUT_SEC | 5 | 秒 | resolveURLString のタイムアウト上限。テスト側では短縮 timeout 引数を注入して高速化する |

- 禁止事項（該当 Don'ts のみ）:
  - 実 gh・実ネットワークに依存するテストを書かない（長時間プロセスは `/bin/sleep` 等のローカルプロセスで代替する）
  - 数値リテラル直書き禁止。テスト内の期待値表明としての秒数は可だが、`GH_TIMEOUT_SEC` 自体は名前付き定数を参照する
- 適用される横断方針（インライン展開）:
  - テストは実 gh・実ネットワークに依存しない（タイムアウトテストのみ `/bin/sleep` 等のローカルプロセス使用可）
  - 既存テスト（41件）を壊さない・変更しない
  - テストクラスに docblock を付与し、配下メソッドを正常系/異常系に分類した一覧を記述。各テストメソッドにも担保内容の docblock
  - 数値リテラルは定数参照（テスト内の期待値表明は可）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`GitHubPullRequestCLITests.swift` に以下のテストを追加する: (1) 正常出力（trim 済み1行）が返ること、(2) 非ゼロ exit で nil が返ること、(3) `GH_TIMEOUT_SEC` を超過する長時間プロセス（`/bin/sleep` 相当のコマンドをモック実行対象として利用、または `timeout` 引数に短縮値を注入）で nil が返り、呼び出しがタイムアウト値+マージン内に復帰すること。テスト実行時間を抑えるため、`resolveURLString` の `timeout` 引数に短い値（例: 1秒未満）を注入できる設計を前提にテストを書く。

## Affected Files

- `Tests/focusbmTests/GitHubPullRequestCLITests.swift`（P01 で新設想定。本 process はテスト追加のみ）

## Symbol Targets

```yaml
- file: Tests/focusbmTests/GitHubPullRequestCLITests.swift
  symbols:
    - name: GitHubPullRequestCLITests
      kind: test_class
      body_start_line: n/a (P01 新設ファイルへの追記)
      body_end_line: n/a
      line_hint: n/a
  patch_only: false
  disjoint_guarantee: true  # テストファイル1:1、他 process はこのファイルを触らない
  pre_flight_checks: [git_clean, "P01 完了確認（GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout:) 実装済みであること）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P11-VG-01 | green | test | agent | true | `swift test --filter GitHubPullRequestCLITests` | Tests/focusbmTests/GitHubPullRequestCLITests.swift | exit code == 0 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-02 | TEST-GREEN, SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 11
- gate_ids: [P11-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-11.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: 実 gh でなくローカル長時間プロセス（`/bin/sleep` 相当）を使う — CI・オフライン環境で決定論的にタイムアウトを再現するため。実 gh のネットワーク遅延に依存すると、テストが不安定（flaky）になる。
- Why: `resolveURLString` の `timeout` 引数に短縮値を注入する設計を推奨する — `GH_TIMEOUT_SEC`（5秒）をそのままテストで待つと実行時間が伸びる。テスト対象の関数が timeout を引数で受け取れる設計（P01 のシグネチャ `resolveURLString(workingDirectory:timeout:)` が既にこれを満たす）を利用し、短い timeout 値（例: 0.5秒）を渡して高速化する。
- Notes: テスト実行時間に注意。短縮 timeout を注入しない場合、タイムアウトテストは実時間 `GH_TIMEOUT_SEC`（5秒）程度かかる。短縮 timeout 引数の注入によりテストを高速化する設計を推奨する。

## Behavior Specification

対象外: テスト process のため Behavior Specification は実装側 P01 の BEH-01-* を正本とする。本 process が test_ref として実体化する behavior_id は以下。

| behavior_id | 実装側正本 | 本 process での test_ref |
|---|---|---|
| BEH-01-01 | process-01.md | GitHubPullRequestCLITests.resolveURLString_returnsURL_whenGHSucceeds |
| BEH-01-02 | process-01.md | GitHubPullRequestCLITests.resolveURLString_returnsNil_whenGHFails |
| BEH-01-03 | process-01.md | GitHubPullRequestCLITests.resolveURLString_returnsNil_whenTimeoutExceeded |

## Red Phase

- [ ] 3つのテストメソッド（正常系1・異常系2）を追加する。P01（依存 process）が未完了の時点で追加した場合は、`GitHubPullRequestCLI` 未実装のためコンパイルエラーまたは失敗になることを確認する。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P11-VG-01
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "GitHubPullRequestCLI 未実装のため追加テストが失敗する（Red 相当）"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] P01 完了後に、追加したテストが green になることを確認する。P01 が本 process より先に完了している場合は Red Phase を「Red 省略: 実装先行のため n/a」として扱い、本 Phase から開始してよい。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P11-VG-01
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] テストメソッド名・docblock の整理（アサーション内容は変えない）
- [ ] `swift test --filter GitHubPullRequestCLITests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P11-VG-01
- status: unverified
- command_or_action: swift test --filter GitHubPullRequestCLITests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

対象外: 自動テストで十分。

## Dependencies

- Requires: P01
- Blocks: P50

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process はライブラリ内部プロセス実行機能のユニットテストであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
