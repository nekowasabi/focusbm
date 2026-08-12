# Process 4: SearchViewModel の prURLCache + prLabel(for:)

## Implementation Brief（コピペ用）

- 背景: `SearchViewModel.swift`（L19-22）は `floatingWindowCache` / `tmuxPaneCache` / `aiProcessCache` を保持し、`applyBackgroundCache(tmuxPanes:aiProcesses:)`（L101-111）で代入後に `isActive` なら `updateItems(allowAutoExecute:false)` を呼んで再描画する。PR 番号表示のためには、cwd をキーに解決済み PR URL とその取得時刻を保持するキャッシュと、`SearchItem` から表示用ラベルを引く関数が必要。
- 目的: `prURLCache: [String: (url: URL, fetchedAt: Date)]`（cwd キー）を追加し、`applyBackgroundCache` に `prURLs` 引数を追加する（デフォルト値で互換維持、nil なら既存キャッシュ維持）。`prLabel(for: SearchItem) -> String?` を追加し、tmuxPane/aiProcess の cwd でキャッシュを引いて `"#<番号>"` を返す。
- 変更範囲: `Sources/FocusBMApp/SearchViewModel.swift`、`Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift`（新規）
- ローカル定数表（正本: PLAN.md の ★ Constants。本 process 使用分のみ。生成時転記）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| PR_CACHE_TTL_SEC | 300 | 秒 | cwd 単位キャッシュ有効期限 |

- 禁止事項（該当 Don'ts のみ）:
  - `SearchItem` enum に新規ケースを追加しない（prLabel は `BookmarkRow` の別引数で渡す。本 process は enum に触れない）
  - `applyBackgroundCache` の既存呼び出し元・テストを壊すシグネチャ変更をしない（デフォルト引数で互換維持）
  - 数値リテラル直書き禁止。`PR_CACHE_TTL_SEC` は名前付き定数として定義し参照する
- 適用される横断方針（インライン展開）:
  - gh CLI をメインスレッドで同期実行しない（本 process はキャッシュ保持・参照のみで gh 実行は行わない）
  - `SearchItem` enum に新規ケースを追加しない（prLabel は `BookmarkRow` の別引数で渡す）
  - PR 取得失敗時に UI 割り込み（NSAlert 等）を出さない — バッジ非表示のみ
  - 既存 `applyBackgroundCache` のシグネチャ変更はデフォルト引数で互換維持（既存呼び出し元・テストを壊さない）
  - 数値リテラル直書き禁止（定数として定義し名前参照）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`SearchViewModel` に `prURLCache: [String: (url: URL, fetchedAt: Date)]`（cwd キー）を追加する。`applyBackgroundCache(tmuxPanes:aiProcesses:prURLs:)` の `prURLs` 引数（デフォルト `nil`）を追加し、非 nil のときのみ `prURLCache` を置換する（既存の tmuxPanes/aiProcesses 代入と同様、代入後 `isActive` なら `updateItems(allowAutoExecute:false)` を呼ぶ）。`prLabel(for: SearchItem) -> String?` を追加し、`.tmuxPane`/`.aiProcess` の cwd（`sessionPullRequestURL(for:)` L414-427 と同様の cwd 抽出方針）でキャッシュを引き、TTL（`PR_CACHE_TTL_SEC`）内であれば URL path の末尾要素から `"#<番号>"` を組み立てて返す。`.bookmark`/`.floatingWindow` は常に nil。

## Affected Files

- `Sources/FocusBMApp/SearchViewModel.swift`（L19-22 付近に `prURLCache` 追加、L101-111 の `applyBackgroundCache` にデフォルト引数付き `prURLs` 追加、新規 `prLabel(for:)` メソッド追加）
- `Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift`（新規、全体）

## Symbol Targets

```yaml
- file: Sources/FocusBMApp/SearchViewModel.swift
  symbols:
    - name: prURLCache
      kind: property
      body_start_line: 19
      body_end_line: 22
      line_hint: 20 (SYMBOL_LINE_TOLERANCE=20行 許容)
    - name: applyBackgroundCache(tmuxPanes:aiProcesses:prURLs:)
      kind: method
      body_start_line: 101
      body_end_line: 111
      line_hint: 105
    - name: prLabel(for:)
      kind: method
      body_start_line: n/a (新規追加)
      body_end_line: n/a
      line_hint: applyBackgroundCache 直後
  patch_only: false
  disjoint_guarantee: true
  pre_flight_checks: [git_clean, "applyBackgroundCache の既存呼び出し元を grep で確認"]
- file: Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift
  symbols:
    - name: SearchViewModelPRCacheTests
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
| P04-VG-01 | red | test | agent | true | `swift test --filter SearchViewModelPRCacheTests` | Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift | exit code != 0（prURLCache/prLabel 未実装のため想定理由で失敗） | 失敗テスト名を含む出力1行 | {failure_class: "expected_red_not_observed", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-04, BEH-04-01 | TEST-RED |
| P04-VG-02 | green | test | agent | true | `swift test --filter SearchViewModelPRCacheTests` | Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift, Sources/FocusBMApp/SearchViewModel.swift | exit code == 0、失敗0件 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-04, BEH-04-01 | TEST-GREEN |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 04
- gate_ids: [P04-VG-01, P04-VG-02]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN.md の ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-04.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: cwd キー — pid キーだと同一リポジトリの複数セッションで重複 gh 呼び出しが起きるため。
- Why: `prLabel` を `SearchItem` に持たせない — `FocusBMLib` の純データ enum に App 層の表示都合を混ぜないため。
- Why: `applyBackgroundCache` の `prURLs` 引数はデフォルト `nil` で追加 — 既存呼び出し元（BackgroundRefreshService 以外の箇所や既存テスト）を壊さずに機能追加するため。nil のときは既存 `prURLCache` を維持し、上書きしない。
- `prLabel(for:)` の cwd 抽出は `sessionPullRequestURL(for:)`（L414-427）の cwd 判定方針（`.aiProcess` は `workingDirectory`、`.tmuxPane` は `currentPath`）と揃える。

## Behavior Specification

- System Type: transformation

| behavior_id | 入力 | 出力 | pre_state | post_state | invariants | test_ref |
|---|---|---|---|---|---|---|
| BEH-04-01 | TTL 内キャッシュ済み cwd を持つ `.aiProcess` | `"#123"` | prURLCache に該当 cwd の (url, fetchedAt) あり | 変化なし | prURLCache は cwd→(URL,取得時刻) の辞書 | SearchViewModelPRCacheTests.prLabel_returnsHashNumber_whenCwdCached |
| BEH-04-02 | 未キャッシュ cwd を持つ `.tmuxPane` | nil | prURLCache に該当 cwd なし | 変化なし | キャッシュ未ヒットは nil を返し例外を出さない | SearchViewModelPRCacheTests.prLabel_returnsNil_whenCwdNotCached |
| BEH-04-03 | `.bookmark` / `.floatingWindow` | nil | 任意 | 変化なし | cwd を持たない SearchItem は常に nil | SearchViewModelPRCacheTests.prLabel_returnsNil_forBookmarkAndFloatingWindow |
| BEH-04-04 | `applyBackgroundCache(tmuxPanes:aiProcesses:prURLs:)` を prURLs 非nilで呼出 | なし（副作用） | prURLCache は旧値 | prURLCache が新値に置換され、isActive なら updateItems が走る | 既存 tmuxPaneCache/aiProcessCache の代入契約と同様の再描画契約を維持 | SearchViewModelPRCacheTests.applyBackgroundCache_replacesPRCache_whenPrURLsProvided |
| BEH-04-05 | `applyBackgroundCache(tmuxPanes:aiProcesses:)`（prURLs省略） | なし（副作用） | prURLCache は旧値 | prURLCache は旧値のまま維持 | デフォルト引数で既存呼び出し元の挙動を変えない | SearchViewModelPRCacheTests.applyBackgroundCache_keepsPRCache_whenPrURLsOmitted |

### Correctness Criteria

- SC-04: TTL 判定は「現在時刻 - fetchedAt <= PR_CACHE_TTL_SEC」で行われ、TTL 超過キャッシュは prLabel で nil 相当に扱われる。

### Left to Implementation

- `prLabel` 内部での URL path 分割ヘルパの命名
- TTL 判定を `prLabel` 内で行うか、専用の内部ヘルパ関数に切り出すか

## Frontend Constraints

- AbortController 不要（SwiftUI）。
- cleanup: なし（値型キャッシュのみ）。
- state リセット: プロセス一覧の cwd が消えてもキャッシュは TTL 失効に任せる（積極削除しない）。
- エラー時表示: 既存表示維持（バッジ非表示のみ）。

## Red Phase

- [ ] `Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift` を作成し、BEH-04-01〜05 に対応するテストを書く（`prURLCache`/`prLabel`/`applyBackgroundCache(prURLs:)` 未実装のためコンパイルエラーまたはテスト失敗になることを確認）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P04-VG-01
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "テストが prURLCache/prLabel 未実装により失敗する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] `Sources/FocusBMApp/SearchViewModel.swift` に `prURLCache` / `applyBackgroundCache(prURLs:)` / `prLabel(for:)` を実装し、Red Phase のテストを通す

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P04-VG-02
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 命名・重複コードの整理（挙動を変えない）
- [ ] `swift test --filter SearchViewModelPRCacheTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P04-VG-02
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- シナリオ1（executor: agent）: `prURLCache` に TTL 内の cwd を1件セットした状態で `prLabel(for:)` を呼び、`"#<番号>"` が返ることを `swift test` の出力で確認する。
- シナリオ2（executor: agent）: `applyBackgroundCache` を `prURLs: nil` で呼び出し、既存 `prURLCache` が変化しないことを `swift test` の出力で確認する。

## Dependencies

- Requires: なし
- Blocks: P05, P06, P12

対象外: HTTP Status Coverage / Visual Verification — 本 process はビューモデルの状態管理ロジックであり、HTTP サーバー・画面表示検証のいずれにも該当しない（gh CLI の exit code で扱う）。
