# 教訓: リファクタリング計画フェーズ（2026-06-11）

## メタ情報
- カテゴリ: process / architecture
- 重要度: high（L-A, L-C, L-E, L-C2-1, L-C2-2）/ medium（L-B, L-D, L-C2-3, L-C2-4）
- 作成日: 2026-06-11
- ソース: 20260611-120143-29486-001

## 教訓一覧

### L-A [high] 計画書の定量数値は grep 実測で確定せよ

感覚値を PLAN.md に記載すると verify フェーズで medium 差異が検出され、訂正コストが発生する。
`grep -r` / `wc -l` 等で実測した値のみ記載すること。

**適用場面**: Phase0（先行調査）実施時、PLAN.md 数値記入時。

---

### L-B [medium] 同一制約値は define once, reference many（Markdown でも）

touched_lines 上限・scope_constraint など複数箇所参照の定数値は1か所で定義し、他は参照形式にする。
数値不整合によるバグを防ぐ。

---

### L-C [high] 双方向循環依存は「逆方向依存」と区別して記録せよ

A→B かつ B→A の双方向循環依存と単方向逆依存は分割難度が大幅に異なる。
有向グラフで実測し、双方向循環依存は明示区別して記録すること。
双方向循環依存が存在する Phase は staff-validation 必須とする。

---

### L-D [medium] I/O 呼出点はファイル数でなく呼出サイト数で計上せよ

ファイル数計上は影響範囲を過小評価する。呼出サイト数（grep 行数）で計上する。

実測コマンド例: `grep -rn "TargetSymbol" Sources/ | wc -l`

---

### L-E [high] テストベースラインは実装者以外が独立実行して確定せよ

LSP（SourceKit）の main-cache は worktree 環境で誤検知する（教訓 L2 参照）。
`swift test` を実装者以外が独立実行した結果のみをベースラインとする。

**適用場面**: PhaseA 着手前、各 Phase の Green 判定時。

---

### L-C2-1 [high] 指示間矛盾はオーケストレータが仲裁し、実行後に追認記録を残せ

複数エージェントから矛盾する指示（例: decide-approve「G6 繰越」vs dispatch「G6 実施」）が届いた場合、
executor は dispatch 指示を優先して実行し、承認記録との不一致を Feedback フェーズで追認する。
追認なしの矛盾放置は次サイクルで繰越タスクの二重実施を引き起こす。

**適用条件**: 複数エージェントから矛盾する指示が届いた場合。
**汎化原則**: 「実行してから追認」の方が「追認待ちで停止」より全体スループットが高い。ただし追認記録は必須。

---

### L-C2-2 [high] supervisor の FAIL 報告は executor 完了後タイムスタンプと照合してから採否判定せよ

supervisor が「executor 未実行・全 AC FAIL」と報告した場合、git reflog 等で executor 完了を確認してから
採否判定すること。supervisor 報告単独での AC FAIL 確定は禁止。

**根拠**: supervisor の観測タイミングが executor 完了前であった場合、報告はタイミングアーティファクトになる。
**対策**: verify-adherence が git reflog を参照できる権限を持つことが証跡確定の鍵。
**汎化原則**: 非同期マルチエージェント環境では「観測時刻 vs 完了時刻」のズレを常に疑う。

---

### L-C2-3 [medium] 証跡ファイルの末尾切断は申し送りの最後に明示せよ

/tmp 申し送りファイルが途中切断された場合、aggregator は「被覆済み（他系統で補完）」か
「欠落（内容不明）」かを明示分類する。「被覆済み」であれば実害なし。

**適用条件**: /tmp 申し送りファイルの参照時、複数系統からの証跡収集時。

---

### L-C2-4 [medium] PLAN.md 内の同一型定数は PhaseID と行番号をペアで記載せよ

PLAN.md に同一数値（例: token_budget: 50,000）が複数 Phase に存在する場合、
数値のみの言及は Phase 混同を引き起こす。行番号と PhaseID を必ずペアで記載すること。

実例: `PLAN.md:369 token_budget: 50,000 (PhaseE)` vs `PLAN.md:xxx token_budget: 200 (PhaseA scope_constraint)`

---

## メタパターン

計画フェーズで定量調査を省略すると verify フェーズで必ず medium 差異が検出される。
Phase0 必須チェックリスト（固定）:
1. grep 実測による数値確定
2. 依存方向の有向グラフ実測（双方向 vs 単方向の区別）
3. 呼出サイト数の実測
4. テストベースラインの独立実行確認

マルチエージェント実行固有チェックリスト（cycle 2 追加）:
5. 矛盾指示の仲裁記録（実行後追認）
6. supervisor/executor 報告の時系列照合（タイムスタンプ確認）
7. 申し送りファイル切断の被覆状況明示

## 次サイクル引継ぎ

- PhaseA（辞書集約 + log() 共通化）と PhaseE（YAML 統合）を spawn_batch で並列開始可能
- PhaseB / PhaseC は staff-validation 必須（双方向循環依存）
- DAG 着手順: spawn_batch=[PhaseA, PhaseE] → PhaseD/PhaseB → PhaseC
- PhaseA scope_constraint: touched_lines <= 200行（超過時 risk=high で再走）
- G6 繰越不要（cycle 2 で実施済み・追認済み）

## 関連教訓
- `stigmergy/lessons-index.md` — 全教訓インデックス
- L2: SourceKit LSP main-cache 誤検知 → `.serena/memories/focusbm-sourcekit-lsp-main-cache-diagnostics`
- L1: worktree strict 同一ファイル直列化 → `.serena/memories/focusbm-worktree-strict-same-file-serialization`
