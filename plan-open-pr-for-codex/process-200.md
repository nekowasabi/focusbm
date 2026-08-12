# Process 200: README / architecture 更新

## Implementation Brief（コピペ用）

- 背景: README.md と stigmergy/focusbm-architecture.md には既存の PR オープン機能（cmd+p、Claude セッション対応）の記述がある可能性がある。P01〜P06 で Codex 対応と PR 番号バッジ表示が追加されたため、既存記述が存在するファイルにはその追記が必要。ただし記述が存在しないファイルを新規に書き起こす（doc-only な追加創作）はスコープ外とする。
- 目的: README.md / stigmergy/focusbm-architecture.md の既存記述を grep で確認し、該当箇所が存在する場合のみ Codex 対応・PR 番号バッジ・タイムアウト（既定5秒＝GH_TIMEOUT_SEC）を追記する。
- 変更範囲: README.md、stigmergy/focusbm-architecture.md（bookmarks.example.yml は対象外: 新設定キーを追加しないため）
- ローカル定数表（正本: PLAN-open-pr-for-codex.md ★ Constants。本 process 使用分のみ）:

| 定数名 | 値 | 単位 | 用途 |
|---|---|---|---|
| GH_TIMEOUT_SEC | 5 | 秒 | ドキュメント中で gh 呼び出しのタイムアウトに言及する際に「既定5秒（GH_TIMEOUT_SEC）」の形式で併記する |

- 禁止事項（該当 Don'ts のみ）:
  - ★ Constants の値をコード・コメント・ドキュメントに数値リテラルで直書きしない（定数名併記を必須とする。例:「既定5秒（GH_TIMEOUT_SEC）」）
  - 既存記述が存在しないファイル・セクションを新規に書き起こさない（変更しない判断も GoalEvidence の observed に grep 結果で残す）
- 適用される横断方針（インライン展開）:
  - 変更は計画の Affected Files（README.md, stigmergy/focusbm-architecture.md）内に限定する
  - 数値リテラル直書き禁止（GH_TIMEOUT_SEC は「既定5秒（GH_TIMEOUT_SEC）」のように定数名併記）
  - 失敗時 UI 割り込み禁止・fail-closed 方針をドキュメントにも正確に反映する（gh 失敗時はバッジ非表示のみで UI 割り込みなし、という実装の実際の挙動を誇張・矮小化せず記述する）
- 出力順序: 1) 実装（grep 確認 + 該当箇所への追記） 2) セルフレビュー 3) 修正 4) 再レビュー 5) ドキュメント確認（本 process 自体がドキュメント確認相当） 6) 品質ゲート実行

## Overview

以下の手順で実施する。
1. `grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md` を実行し、既存記述の有無・箇所を確認する。
2. 対応エージェント一覧や PR オープン機能の記述が存在するファイルには、Codex 対応・PR 番号バッジ表示・タイムアウト（既定5秒＝GH_TIMEOUT_SEC）を追記する。
3. 記述が存在しないファイルは変更しない。変更しない判断も grep 結果を根拠として GoalEvidence の observed に残す。
4. bookmarks.example.yml は対象外（本計画は新設定キーを追加しないため）。

## Affected Files

- `README.md`（既存記述が存在する場合のみ、該当箇所に追記）
- `stigmergy/focusbm-architecture.md`（既存記述が存在する場合のみ、該当箇所に追記）

## Symbol Targets

n/a（doc-only。pre_flight_checks: [git_clean]）

## Verification Gates

| gate_id | phase | type | executor | required | command | input_scope | pass_criteria | evidence_spec | failure_policy | criterion_refs | policy_refs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P200-VG-01 | green | grep | agent | false | `grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md && git diff --stat README.md stigmergy/focusbm-architecture.md` | README.md, stigmergy/focusbm-architecture.md | 既存記述が存在した各ファイルに Codex/PR 番号への言及が追加されている（grep ヒット）、または既存記述なしの根拠 grep 0 件が記録されている | grep 出力と `git diff --stat` の出力を逐語引用 | {failure_class: "doc_update_missing", retryable: true, retry_budget_source: task_retry_budget, terminal_action: "await_input"} | SC-05 | SCOPE-01 |

### execution_handoff

- task_id: T-20260730-open-pr-for-codex
- process: 200
- gate_ids: [P200-VG-01]
- retry_budget_source: task_retry_budget
- evidence_format: GoalEvidence

## 生成情報

- source_constants: PLAN-open-pr-for-codex.md ★ Constants
- regeneration_required_when: ★ Constants・gate・横断方針変更時
- appendix: process-200.appendix.md（実行時に Read しない）

## Implementation Notes

- Why: gate を `required: false` とした — 既存記述の有無に応じた条件付き更新であり、記述が存在しないファイルを機械的に fail 扱いにすると「書かない」という正しい判断を罰することになるため。ただし判断根拠（grep 結果）は必ず observed に記録する。
- 既存記述が見つかった場合の追記文言は、対象箇所の既存トーン・見出し構造に合わせる（新規セクションの創設ではなく、既存箇所への追記を優先する）。
- bookmarks.example.yml は本計画のスコープに含まれない（Affected Files 外）。誤って編集しないこと。

## Behavior Specification

対象外: doc-only（README / architecture ドキュメントの更新のみで、実行可能なコードの挙動変更を伴わない）

## Red Phase

対象外: 実行のみ（doc-only）

## Green Phase

- [ ] `grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md` を実行し、既存記述の有無を確認する
- [ ] 既存記述が存在するファイルには、Codex 対応・PR 番号バッジ・タイムアウト（既定5秒＝GH_TIMEOUT_SEC）を追記する
- [ ] 既存記述が存在しないファイルは変更しない

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P200-VG-01
- status: unverified
- command_or_action: grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md
- exit_code: n/a
- expected: "既存記述の有無が grep 結果で判明する"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Refactor Phase

- [ ] 追記した文言の見直し（既存トーン・表記ゆれとの整合確認。挙動記述は変えない）
- [ ] `grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md && git diff --stat README.md stigmergy/focusbm-architecture.md` を再実行し、追記が反映されていることを確認する

```
✅ **Phase Complete**（GoalEvidence）
- gate_id: P200-VG-01
- status: unverified
- command_or_action: grep -n "claude\|Claude\|cmd+p\|プルリク\|pull request" README.md stigmergy/focusbm-architecture.md && git diff --stat README.md stigmergy/focusbm-architecture.md
- exit_code: n/a
- expected: "既存記述箇所に Codex/PR 番号への言及が追加されている、または grep 0 件（記述なし）が確認できる"
- observed: "{実行時に逐語引用を記入}"
- attempt: 1
```

## Manual Verification

- executor: human — 更新後の README.md / stigmergy/focusbm-architecture.md を人間が一読し、追記内容が既存文書のトーン・粒度と整合しているか、GH_TIMEOUT_SEC の記述が数値直書きになっていないかを確認する。human のみ残った場合は unverified として報告する。

## Dependencies

- Requires: P100
- Blocks: P300

対象外: HTTP Status Coverage / Frontend Constraints / Visual Verification — 本 process は doc-only の更新であり、HTTP サーバー・フロントエンド・画面表示のいずれにも該当しない。
