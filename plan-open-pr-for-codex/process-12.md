# Process 12: prLabel キャッシュ挙動テスト

## Implementation Brief（コピペ用）

- 背景: P04 で `SearchViewModel` に `prURLCache: [String: (url: URL, fetchedAt: Date)]`（cwd キー）、`applyBackgroundCache(prURLs:)` の拡張、`prLabel(for: SearchItem) -> String?` が追加される。キャッシュ未取得時の nil 返却、TTL（`PR_CACHE_TTL_SEC`）切れ時の再取得扱い、bookmark/floatingWindow アイテムへの非適用、既存引数のみでの互換動作をテストで担保する必要がある。
- 目的: `Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift` にキャッシュ挙動の一連のテストを追加する。
- 変更範囲: `Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift`（新規）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| PR_CACHE_TTL_SEC | 300 | 秒 | prURLCache のエントリ有効期限。テストでは fetchedAt を過去に注入して TTL 切れを再現する |

- 禁止事項（該当 Don'ts のみ）:
  - 実 gh・実ネットワークに依存するテストを書かない（`prURLCache` への直接注入、または background 解決のモック注入で代替する）
  - 数値リテラル直書き禁止。`PR_CACHE_TTL_SEC` は名前付き定数として参照する（テスト内の期待値表明としての秒数指定は可）
  - `applyBackgroundCache(prURLs:)` の既存引数（P05 以前からの呼び出し元互換のためのデフォルト引数）を壊す形のテストを書かない
- 適用される横断方針（インライン展開）:
  - テストは実 gh・実ネットワークに依存しない（クロージャ/プロバイダ注入・直接のキャッシュ注入でモック）
  - 既存テスト（41件）を壊さない・変更しない
  - テストクラスに docblock を付与し、配下メソッドを正常系/異常系に分類した一覧を記述。各テストメソッドにも担保内容の docblock
  - 数値リテラルは定数参照（テスト内の期待値表明は可）
- 出力順序: 1) 実装 2) セルフレビュー 3) 修正 4) 再レビュー 5) 更新対象ドキュメント確認 6) 品質ゲート実行

## Overview

`SearchViewModelPRCacheTests.swift` を新設し、以下を検証する: (1) `prURLCache` に未取得の cwd に対して `prLabel(for:)` が nil を返す、(2) キャッシュ後（`prURLCache` に URL を注入した状態）で `prLabel(for:)` が `"#123"` 形式の文字列を返す、(3) bookmark・floatingWindow 種別の `SearchItem` は常に nil を返す（cwd 概念がないため）、(4) `fetchedAt` を `PR_CACHE_TTL_SEC` 超過相当の過去日時に注入した場合に TTL 切れとして扱われる（nil または再取得対象と判定される）、(5) `applyBackgroundCache(prURLs:)` を既存引数のみで呼び出しても互換動作する（デフォルト引数によりコンパイル・実行が通る）。

## Affected Files

- `Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift`（新規）

## Symbol Targets

```yaml
- file: Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift
  symbols:
    - name: SearchViewModelPRCacheTests
      kind: test_class
      body_start_line: n/a (新規ファイル)
      body_end_line: n/a
      line_hint: n/a
  patch_only: false
  disjoint_guarantee: true  # テストファイル1:1、他 process はこのファイルを触らない
  pre_flight_checks: [git_clean, "P04 完了確認（SearchViewModel.prURLCache / applyBackgroundCache(prURLs:) 拡張 / prLabel(for:) 実装済みであること）"]
```

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P12-VG-01 | green | test | agent | true | `swift test --filter SearchViewModelPRCacheTests` | Tests/FocusBMAppTests/SearchViewModelPRCacheTests.swift | exit code == 0 | `swift test` の `Executed N tests` 行 | {failure_class: "test_failure", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "escalate_to_human"} | SC-03, SC-04 | TEST-GREEN, SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 12
- gate_ids: [P12-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-12.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: `prURLCache` への直接注入（internal アクセス、または注入用の internal init/setter）を使う — 実 gh・background 解決を経由せずにキャッシュ状態を直接構成することで、テストを決定論的かつ高速にするため。
- Why: TTL 切れの検証は `fetchedAt` を `Date() - PR_CACHE_TTL_SEC - マージン` 相当の過去日時に注入して行う — 実時間で `PR_CACHE_TTL_SEC`（300秒）待つのは非現実的なため、日時注入で即座に再現する。
- テストクラス docblock には「正常系: 未取得→nil、キャッシュ後→"#123"、互換引数呼び出し」「異常系: bookmark/floatingWindow→常に nil、TTL 切れ→nil 相当」の分類一覧を明記する。

## Behavior Specification

対象外: テスト process のため Behavior Specification は実装側 P04 の BEH-04-* を正本とする。本 process が test_ref として実体化する behavior_id は以下。

| behavior_id | 実装側正本 | 本 process での test_ref |
|---|---|---|
| BEH-04-01 | process-04.md | SearchViewModelPRCacheTests.prLabel_returnsNil_whenNotCached |
| BEH-04-02 | process-04.md | SearchViewModelPRCacheTests.prLabel_returnsFormattedString_whenCached |
| BEH-04-03 | process-04.md | SearchViewModelPRCacheTests.prLabel_returnsNil_forNonCwdItemKinds |
| BEH-04-04 | process-04.md | SearchViewModelPRCacheTests.prLabel_treatsExpiredTTLAsUncached |
| BEH-04-05 | process-04.md | SearchViewModelPRCacheTests.applyBackgroundCache_worksWithExistingArgumentsOnly |

## Red Phase

- [ ] 5系統のテストメソッド（未取得nil・キャッシュ後表示・非cwd種別nil・TTL切れ・互換引数）を追加する。P04（依存 process）が未完了の時点で追加した場合は、`prURLCache`／`prLabel(for:)` 未実装のためコンパイルエラーまたは失敗になることを確認する。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P12-VG-01
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "SearchViewModel の prLabel/prURLCache 未実装のため追加テストが失敗する（Red 相当）"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Green Phase

- [ ] P04 完了後に、追加したテストが green になることを確認する。P04 が本 process より先に完了している場合は Red Phase を「Red 省略: 実装先行のため n/a」として扱い、本 Phase から開始してよい。

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P12-VG-01
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] テストメソッド名・docblock の整理（アサーション内容は変えない）
- [ ] `swift test --filter SearchViewModelPRCacheTests` が引き続き green であることを確認

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P12-VG-01
- status: unverified
- command_or_action: swift test --filter SearchViewModelPRCacheTests
- exit_code: n/a
- expected: "Executed N tests, with 0 failures"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

対象外: 自動テストで十分。

## Dependencies

- Requires: P04
- Blocks: P50

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process は ViewModel のキャッシュロジックのユニットテストであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
