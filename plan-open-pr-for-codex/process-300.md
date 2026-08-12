# Process 300: レトロスペクティブ

## Implementation Brief（コピペ用）

- 背景: 本計画は gh CLI のタイムアウト付き呼び出し（GH_TIMEOUT_SEC）、BackgroundRefreshService での並列 PR 解決（PR_RESOLVE_MAX_CONCURRENT）、TTL キャッシュ（PR_CACHE_TTL_SEC）という3つの設計判断を含む。実装完了後、これらの設計が意図どおり機能したか、計画時点の想定と実装後の実測に差異がなかったかを振り返り、教訓として永続化する。
- 目的: gh タイムアウト設計・並列解決設計・負キャッシュの効果・計画とのずれを振り返り、知見を .serena/memories/ と stigmergy/ に永続化する。
- 変更範囲: なし（実行のみ。教訓ファイルへの追記を除きコード変更なし）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants）: 定数なし
- 禁止事項（該当 Don'ts のみ）:
  - 本 process でコードを変更しない（振り返りで問題を発見した場合は新規 Issue / 別計画として起票し、本 process 内で実装修正しない）
- 適用される横断方針（インライン展開）:
  - 変更は計画の Affected Files 内に限定する（本 process はコード対象ファイルなし。教訓ファイルへの追記のみ）
  - 数値リテラル直書き禁止（振り返り記述で GH_TIMEOUT_SEC 等に言及する場合は定数名を併記する）
  - 失敗時 UI 割り込み禁止・fail-closed 方針が実装後も維持されているかを振り返り観点に含める
- 出力順序: 1) 実装（対象外） 2) セルフレビュー（振り返り内容の一貫性確認） 3) 修正（対象外） 4) 再レビュー（対象外） 5) ドキュメント確認（教訓ファイルの内容確認） 6) 品質ゲート実行

## Overview

実装完了後（P200 完了後）に以下の観点で振り返りを行う。
- gh タイムアウト設計: `Process.terminate()` によるタイムアウト処理で子プロセスが残らないか、P01 実装時の実測結果を確認する。
- 並列解決設計: `PR_RESOLVE_MAX_CONCURRENT`（4個）が実際の cwd 数・実行時間に対して妥当だったか。
- 負キャッシュの効果: PR が存在しない cwd への重複 gh 呼び出しが `PR_CACHE_TTL_SEC`（300秒）内で抑制されたか。
- 計画とのずれ: 実装中に PLAN-open-pr-for-codex.md の想定（Assumptions / Open Questions・Risks）と異なる挙動・判断があったか。

## Affected Files

なし（実行のみ。教訓ファイル自体は .serena/memories/ および stigmergy/ 配下）

## Symbol Targets

n/a（実行のみ。pre_flight_checks: [git_clean]）

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P300-VG-01 | green | manual | agent | false | `ls stigmergy/lessons.jsonl .serena/memories/ 2>&1` | stigmergy/lessons.jsonl, .serena/memories/ | 教訓が1件以上永続化されている（対象パスのいずれかに本タスク由来の新規エントリが存在する） | `ls` 出力および追記した教訓ファイルの該当行を逐語引用 | {failure_class: "knowledge_not_persisted", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "await_input"} | SC-05 | QUALITY-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 300
- gate_ids: [P300-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-300.appendix.md（実行時に Read しない）

## Implementation Notes

- 振り返り対象の3設計判断（タイムアウト・並列解決・負キャッシュ）は PLAN-open-pr-for-codex.md の ★ Constants（GH_TIMEOUT_SEC / PR_RESOLVE_MAX_CONCURRENT / PR_CACHE_TTL_SEC）に対応する。振り返り記述でもこれらは定数名で参照する。
- 教訓の保存先は本ファイル末尾の Knowledge Phase チェックリストに従う。重要度が高い知見のみプロジェクト CLAUDE.md 相当（MEMORY.md 等）へ追記する。

## Behavior Specification

対象外: 実行のみ（振り返り・知見永続化であり、コードの外部挙動を変更しない）

## Green Phase

- [ ] gh タイムアウト設計: terminate 後に子プロセスが残らないか、P01 の Manual Verification / テスト実測結果を確認する
- [ ] 並列解決設計: PR_RESOLVE_MAX_CONCURRENT の妥当性を、P05 実装時の観測（並列数・実行時間）から評価する
- [ ] 負キャッシュの効果: PR_CACHE_TTL_SEC 内での重複 gh 呼び出し抑制が機能したかを P12 のテスト結果から評価する
- [ ] 計画とのずれ: PLAN-open-pr-for-codex.md の Assumptions / Open Questions・Risks と実装後の実態を突合し、差異があれば記録する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P300-VG-01
- status: unverified
- command_or_action: 上記4観点の振り返りを実施し、要点を教訓ファイルへの追記に先立って整理する
- exit_code: n/a
- expected: "4観点それぞれについて振り返り結果が言語化されている"
- observed: "{実行時に振り返り要点を逐語引用}"
- attempt: 1
```

## Refactor Phase

- [ ] 振り返り記述の重複・冗長箇所を整理する（内容は変えない）
- [ ] ★ Constants の値が定数名併記になっているか再確認する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P300-VG-01
- status: unverified
- command_or_action: 振り返り記述のセルフレビュー
- exit_code: n/a
- expected: "数値リテラル直書きが0件（定数名併記のみ）"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Knowledge Phase: 知見の永続化

- [ ] .serena/memories/ に教訓を保存（mcp__serena__write_memory、ファイル名 lessons-{topic} 形式。例: `lessons-open-pr-for-codex`）
- [ ] stigmergy/ に教訓・パターンを記録（stigmergy/lessons.jsonl 追記 または stigmergy/patterns/{category}.md）
- [ ] 重要度が高い知見を Memory（CLAUDE.md またはプロジェクト CLAUDE.md / MEMORY.md）に追記
- [ ] `command -v brv` を確認し、利用可能なら byterover に保存（不在ならスキップ、エラーにしない）

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P300-VG-01
- status: unverified
- command_or_action: ls stigmergy/lessons.jsonl .serena/memories/
- exit_code: n/a
- expected: "教訓が1件以上永続化されている"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

対象外: 教訓ファイルの存在確認（P300-VG-01）で機械的に検証できるため、追加の人間検証は必須としない

## Dependencies

- Requires: P200
- Blocks: なし

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process は振り返り・知見永続化のみであり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
