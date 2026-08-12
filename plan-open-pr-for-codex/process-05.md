# Process 5: BackgroundRefreshService の PR 並列解決（機能B本体）

## Implementation Brief（コピペ用）

- 背景: `BackgroundRefreshService.swift`（全106行）は `interval` デフォルト15秒（L14）、`weak var viewModel` を持ち、`refresh()`（L42-57）が utility キューで `TmuxProvider.listAIAgentPanes` / `ProcessProvider.listNonTmuxAIProcesses` を取得し、メインスレッドで `applyBackgroundCache` へ渡す（スリープ中はスキップ）。ここに PR URL の並列解決を追加する。
- 目的: `refresh()` を拡張し、取得済み tmuxPanes/aiProcesses からユニーク cwd 集合を作り、TTL 内キャッシュ済み cwd を除外した残りを `GitHubPullRequestCLI.resolveURLString(timeout: GH_TIMEOUT_SEC)` で並列解決（同時 `PR_RESOLVE_MAX_CONCURRENT` まで）し、結果をメインスレッドで `applyBackgroundCache(prURLs:)` へ渡す。
- 変更範囲: `Sources/FocusBMApp/BackgroundRefreshService.swift`、`Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift`（新規）
- ローカル定数表（正本: PLAN.md の ★ Constants。本 process 使用分のみ。生成時転記）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| GH_TIMEOUT_SEC | 5 | 秒 | gh pr view 実行上限 |
| PR_CACHE_TTL_SEC | 300 | 秒 | cwd 単位キャッシュ有効期限 |
| PR_RESOLVE_MAX_CONCURRENT | 4 | 個 | 同一周期内 gh 並列上限 |
| BACKGROUND_REFRESH_INTERVAL_SEC | 15 | 秒 | 既存周期（変更しない・参照のみ） |

- 禁止事項（該当 Don'ts のみ）:
  - `BACKGROUND_REFRESH_INTERVAL_SEC`（既存 `interval` デフォルト15秒）を変更しない
  - gh CLI をメインスレッドで同期実行しない
  - PR 取得失敗時に UI 割り込み（NSAlert 等）を出さない
  - 数値リテラル直書き禁止。`GH_TIMEOUT_SEC` / `PR_RESOLVE_MAX_CONCURRENT` は名前付き定数として定義し参照する
- 適用される横断方針（インライン展開）:
  - gh CLI をメインスレッドで同期実行しない（utility キュー上で実行）
  - `SearchItem` enum に新規ケースを追加しない（本 process は enum に触れない）
  - PR 取得失敗時に UI 割り込み（NSAlert 等）を出さない — バッジ非表示のみ（負キャッシュとして記録するのみ）
  - 既存 `applyBackgroundCache` のシグネチャ変更はデフォルト引数で互換維持（P04 で対応済み。本 process はその契約を利用するのみ）
  - 数値リテラル直書き禁止（定数として定義し名前参照）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`refresh()`（L42-57）の既存フロー（utility キューで tmuxPanes/aiProcesses を取得 → メインスレッドで `applyBackgroundCache`）に、PR URL 解決ステップを追加する。取得した tmuxPanes/aiProcesses から cwd のユニーク集合を作り、`viewModel`（weak）から既存 `prURLCache` のスナップショットを取得して TTL 内（`PR_CACHE_TTL_SEC`）のものを除外する。残りの cwd について `GitHubPullRequestCLI.resolveURLString(workingDirectory:timeout: GH_TIMEOUT_SEC)` を `DispatchSemaphore` + `DispatchGroup`（または同等の仕組み）で同時 `PR_RESOLVE_MAX_CONCURRENT` まで並列実行する。解決失敗（nil 返却）の cwd は「負キャッシュ」として `fetchedAt` のみ記録し（url は nil 相当）、TTL 内は再試行しない。全解決完了後、メインスレッドで `viewModel?.applyBackgroundCache(tmuxPanes:aiProcesses:prURLs:)` へ新しいキャッシュ（既存 TTL 内キャッシュ + 新規解決結果のマージ）を渡す。resolver 関数はテスト容易性のためイニシャライザ注入（デフォルトは `GitHubPullRequestCLI.resolveURLString`）とする。

## Affected Files

- `Sources/FocusBMApp/BackgroundRefreshService.swift`（`refresh()` L42-57 を拡張、イニシャライザに resolver 注入パラメータを追加）
- `Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift`（新規、全体。resolver をクロージャ注入してモック）

## Symbol Targets

```yaml
- file: Sources/FocusBMApp/BackgroundRefreshService.swift
  symbols:
    - name: refresh()
      kind: method
      body_start_line: 42
      body_end_line: 57
      line_hint: 45 (SYMBOL_LINE_TOLERANCE=20行 許容)
    - name: init(...)
      kind: initializer
      body_start_line: n/a (既存イニシャライザに resolver 注入引数を追加)
      body_end_line: n/a
      line_hint: 14 付近
  patch_only: false
  disjoint_guarantee: false
  pre_flight_checks: [git_clean, "P01/P04 完了確認"]
- file: Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift
  symbols:
    - name: BackgroundRefreshServicePRTests
      kind: test_class
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
| P05-VG-01 | red | test | agent | true | `swift test --filter BackgroundRefreshServicePRTests` | Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift | exit code != 0（PR 並列解決未実装のため想定理由で失敗） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-05, BEH-05-01 | TEST-RED |
| P05-VG-02 | green | test | agent | true | `swift test --filter BackgroundRefreshServicePRTests` | Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift, Sources/FocusBMApp/BackgroundRefreshService.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-05, BEH-05-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 05
- gate_ids: [P05-VG-01, P05-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN.md の ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-05.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: 負キャッシュ — 失敗 cwd を毎周期叩き直すと gh 未認証環境で15秒（BACKGROUND_REFRESH_INTERVAL_SEC）ごとに無駄なプロセスが立つため、失敗も `fetchedAt` を記録して TTL 内は再試行しない。
- Why: resolver をイニシャライザ注入 — `GitHubPullRequestCLI.resolveURLString` を直接呼ぶ実装だとテストで実 gh プロセスを起動する必要が生じ、CI で不安定になるため、クロージャ注入でモック可能にする。
- Why: `DispatchSemaphore` + `DispatchGroup` による同時実行数制御 — `PR_RESOLVE_MAX_CONCURRENT` を超える同時 gh プロセス起動を防ぎ、資源枯渇（プロセス数上限）を避けるため。
- `viewModel` は既存同様 `weak` 参照。解決処理の途中で `viewModel` が nil になった場合は結果の書き戻しを no-op とする（既存 `refresh()` のスリープ中スキップと同様の安全側動作）。

## Behavior Specification

- System Type: reactive

| behavior_id | 現状態 | イベント | ガード | 次状態 | 事後条件 | test_ref |
|---|---|---|---|---|---|---|
| BEH-05-01 | 未キャッシュ cwd | refresh 周期発火 | TTL 内キャッシュなし | 解決中 | GitHubPullRequestCLI が該当 cwd に対して1回呼ばれる | BackgroundRefreshServicePRTests.refresh_resolvesOnlyUncachedOrExpiredCwds |
| BEH-05-02 | 解決中 | resolver がURLを返す | 成功 | キャッシュ済(URL) | applyBackgroundCache(prURLs:) に該当 cwd の (url, fetchedAt) が含まれる | BackgroundRefreshServicePRTests.refresh_cachesResolvedURL_onSuccess |
| BEH-05-03 | 解決中 | resolver が nil を返す／タイムアウト | 失敗・タイムアウト | 負キャッシュ(nil, fetchedAt) | 同一 cwd への再呼び出しは TTL 内では発生しない | BackgroundRefreshServicePRTests.refresh_recordsNegativeCache_onFailure |
| BEH-05-04 | TTL 内キャッシュ済み cwd | refresh 周期発火 | TTL 内 | スキップ | 該当 cwd に対し resolver が呼ばれない | BackgroundRefreshServicePRTests.refresh_skipsResolution_forCwdWithinTTL |
| BEH-05-05 | TTL 切れキャッシュ済み cwd | refresh 周期発火 | TTL 切れ | 解決中（再解決対象） | 該当 cwd に対し resolver が再度呼ばれる | BackgroundRefreshServicePRTests.refresh_resolvesAgain_whenCacheExpired |
| BEH-05-06 | 任意 | refresh 周期発火 | viewModel 解放済み(nil) | no-op | resolver・applyBackgroundCache いずれも呼ばれない | BackgroundRefreshServicePRTests.refresh_noOp_whenViewModelDeallocated |
| BEH-05-07 | 未キャッシュ cwd が PR_RESOLVE_MAX_CONCURRENT を超えて存在 | refresh 周期発火 | 資源上限 | 順次解決（同時実行数上限あり） | 同時に実行中の resolver 呼び出し数が PR_RESOLVE_MAX_CONCURRENT を超えない | BackgroundRefreshServicePRTests.refresh_limitsConcurrency_toMaxConcurrent |
| BEH-05-08 | 任意 | スリープ中に refresh 周期到達 | 既存スリープスキップ挙動 | スキップ（既存挙動維持） | PR 解決処理も含め周期全体がスキップされる | BackgroundRefreshServicePRTests.refresh_skipsEntirely_duringSleep |

### Correctness Criteria

- SC-05: 同一周期内で同一 cwd への gh 呼び出しは最大1回。
- SC-06: TTL 内 cwd への呼び出しは0回。
- SC-07: 並列数が `PR_RESOLVE_MAX_CONCURRENT` を超えない。

### Left to Implementation

- 並列化手段の選択（`DispatchSemaphore` + `DispatchGroup` か `OperationQueue.maxConcurrentOperationCount` か）
- 負キャッシュの内部表現（`(url: URL?, fetchedAt: Date)` か専用型か）の詳細

## Frontend Constraints

- AbortController 不要（SwiftUI・バックグラウンドサービス）。
- cleanup: なし（既存 `refresh()` のライフサイクルに従う）。
- state リセット: なし（負キャッシュ・正キャッシュとも TTL 失効に任せる）。
- エラー時表示: 既存表示維持（バッジ非表示のみ。NSAlert 等の割り込みを出さない）。

## Red Phase

- [ ] `Tests/FocusBMAppTests/BackgroundRefreshServicePRTests.swift` を作成し、BEH-05-01〜08 に対応するテストを書く（resolver クロージャ注入未実装のためコンパイルエラーまたはテスト失敗になることを確認）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P05-VG-01
- status: unverified
- command_or_action: swift test --filter BackgroundRefreshServicePRTests
- exit_code: n/a
- expected: "テストが PR 並列解決未実装により失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `Sources/FocusBMApp/BackgroundRefreshService.swift` の `refresh()` を拡張し、resolver 注入・TTL 判定・並列解決・負キャッシュを実装して Red Phase のテストを通す

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P05-VG-02
- status: unverified
- command_or_action: swift test --filter BackgroundRefreshServicePRTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 命名・重複コードの整理（挙動を変えない）
- [ ] `swift test --filter BackgroundRefreshServicePRTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P05-VG-02
- status: unverified
- command_or_action: swift test --filter BackgroundRefreshServicePRTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: モック resolver を注入した `refresh()` 実行で、TTL 内 cwd がスキップされ未キャッシュ cwd のみ解決されることを `swift test` の出力で確認する。
- シナリオ2（executor: human）: 実機で gh 認証済み環境の SearchPanel を開き、初回表示ではバッジが出ない cwd の行が、約15秒後（BACKGROUND_REFRESH_INTERVAL_SEC）の再表示で PR バッジが出ることを目視確認する。executor: human のみ残った場合は unverified として報告する。

## Dependencies

- Requires: P01, P04
- Blocks: P100

対象外: HTTP Status Coverage / Visual Verification — 本 process はバックグラウンドサービスのロジックであり、HTTP サーバー・画面表示検証のいずれにも該当しない（gh CLI の exit code で扱う）。
