---
title: "focusbm 全体リファクタリング計画"
status: planning
created: "2026-06-11"
mission_id: "20260611-120143-29486-001"
---

# Commander's Intent

## Purpose（即時目標）

focusbm コードベースに長年蓄積した 5 種類の無駄（P1〜P5）を、**振る舞い不変（全テスト green 維持）** を絶対前提としてフェーズ分割 RGR 方式で除去する。成果物は保守性・認知負荷改善であり、機能追加は一切行わない。

## Higher Intent（上位の狙い）

A1（保守性が価値の源泉）/ A2（認知負荷最小化）の実現。無駄の除去は手段であり、目的は「将来の変更コストを下げる構造」。Primary Truth は `swift test` 終了コード（LSP 赤波線・Phase Complete マーカーを真実源にしない）。

## スコープ外（A5 遵守）

- FloatingWindowProvider の AX 非同期化（振る舞い変更リスク > 無駄除去便益 → 別ミッション化推奨）
- SearchItem switch-over 型多態化（18 サイト規模の Protocol Witness 化 → 別ミッション化推奨）

---

# 5 Waste パターン（P1〜P5）

| ID | パターン | 主な物証 |
|----|---------|---------|
| P1 | Process() 直接生成が 5 ファイル・実測 18 呼出サイト（実測 2026-06-11）に散在。DI なし・テスト困難 | TmuxProvider / ProcessProvider / AppleScriptBridge / focusbm.swift / FocusBMApp.swift |
| P2 | God 型: TmuxProvider(848行)/SearchViewModel(434行)/AppDelegate(353行) | TmuxProvider.swift / SearchViewModel.swift / FocusBMApp.swift |
| P3 | log() が TmuxProvider:185 と ProcessProvider:83 の 2 箇所に private static で重複定義。絵文字辞書は TmuxProvider 1 ファイルで定義（定義 2 関数: :192 agentCommandToEmoji / :491 terminalBundleIdToEmoji）、ProcessProvider・Models が参照（BookmarkRow には定義・参照ともゼロ） | TmuxProvider.swift（定義元）/ ProcessProvider.swift / Models.swift（参照のみ）|
| P4 | SearchView で LazyVStack / LazyVGrid の ForEach ブロック 35 行×2 が重複 | SearchView.swift:49-122 |
| P5 | AppDelegate が setupHotkey/setupStatusItem/setupSearchPanel 等で YAMLStorage.loadYAML() を 5 重呼出（実測 6 サイト中 FocusBMApp.swift が 5 箇所: :38/:198/:246/:298/:322。SearchViewModel.swift:36 の 1 箇所は Phase3 で単一化済みのため PhaseE スコープ外） | FocusBMApp.swift:38,198,246,298,322 |

---

# ベースライン（実測値）

- `swift test`: **310 tests, 全 green, 終了コード 0**
- `Process()` 直接使用: TmuxProvider / ProcessProvider / AppleScriptBridge / focusbm.swift / FocusBMApp.swift（実測 5 ファイル・18 呼出サイト（実測 2026-06-11）: TmuxProvider 8 箇所 / ProcessProvider 4 箇所 / AppleScriptBridge 2 箇所 / FocusBMApp.swift 2 箇所 / focusbm.swift 2 箇所）
- `log()` 独自定義: TmuxProvider.swift:185、ProcessProvider.swift:83（各型が private static func log を保有）
- 絵文字辞書: TmuxProvider.swift で 2 関数（:192 agentCommandToEmoji / :491 terminalBundleIdToEmoji）を定義（実測 2026-06-11: 定義 1 ファイル / 参照 2 ファイル: ProcessProvider.swift:119 / Models.swift:372,374）
- YAML 読み込み: 実測 6 サイト（実測 2026-06-11）: FocusBMApp.swift 5 箇所（:38/:198/:246/:298/:322）+ SearchViewModel.swift 1 箇所（:36、Phase3 で単一化済み）/ YAMLStorage.swift（正常）

---

# Progress Map

| Phase | Title | Status | Depends On |
|-------|-------|--------|-----------|
| Phase0 | 先行調査（W6 ギャップ確定） | ☑ done | - |
| PhaseA | 辞書集約 + log() 共通化（P3） | ☐ planning | Phase0 |
| PhaseD | SearchView 層 構造重複除去（P4） | ☐ planning | PhaseA |
| PhaseB | ShellRunner/ProcessRunner 抽出 + DI 化（P1） | ☐ planning | PhaseA |
| PhaseC | 検出ロジック統合 + TmuxProvider 分割（P2/P3 後半） | ☐ planning | PhaseB |
| PhaseE | SearchViewModel/AppDelegate 分割 + YAML 統合（P2/P5） | ☐ planning | Phase0 |

**DAG**: `Phase0 → {PhaseA, PhaseE}` → `PhaseA → {PhaseD, PhaseB}` → `PhaseB → PhaseC`

**Overall**: ☑ 1/6 completed（Phase0 先行調査完了済み）

---

# DAG（有向非巡回グラフ）

## ノード定義

```
nodes:
  - Phase0
  - PhaseA
  - PhaseD
  - PhaseB
  - PhaseC
  - PhaseE

edges:
  - from: Phase0  → to: PhaseA   (reason: 先行調査完了後に実装開始)
  - from: Phase0  → to: PhaseE   (reason: 先行調査完了後に独立並列発射)
  - from: PhaseA  → to: PhaseD   (reason: BookmarkRow.swift 同一ファイル編集の直列化 [L1])
  - from: PhaseA  → to: PhaseB   (reason: 辞書/log 集約後に Process 抽象化)
  - from: PhaseB  → to: PhaseC   (reason: ShellRunner 抽出後に検出統合)

parallel_batches:
  - wave: wave0   nodes: [Phase0]           spawn: single
  - wave: wave1   nodes: [PhaseA, PhaseE]   spawn: spawn_batch  (touched_files 完全非競合)
  - wave: wave2   nodes: [PhaseD]           spawn: single-after-A  (BookmarkRow 競合でA待ち)
  - wave: wave2   nodes: [PhaseB]           spawn: single-after-A
  - wave: wave3   nodes: [PhaseC]           spawn: single-after-B
```

## 並列 / 直列の根拠

| 並列 | 根拠 |
|------|------|
| PhaseA ‖ PhaseE | touched_files 完全非競合（Lib 辞書/log vs VM/AppDelegate/YAML） |

| 直列（edge） | 根拠 |
|-------------|------|
| A → D | BookmarkRow.swift 同一ファイル編集の直列化（L1 同一ファイル直列化原則） |
| A → B | 辞書/log 集約が Process 抽象化の前提（EmojiCatalog への import が安定してから） |
| B → C | ShellRunner DI 化後に検出ロジック統合（依存方向の確定が必要） |

---

# フェーズ詳細

---

## Phase0: 先行調査（W6 ギャップ確定）

**Status**: ☑ done（実施済み）

| ID | ギャップ | 結論 |
|----|---------|------|
| T0.1 | AppIconProvider が Process 依存か | Process 非依存（NSWorkspace.icon 使用）→ P1 対象外 |
| T0.2 | Package.swift 新規 target が必要か | 不要。既存 FocusBMLib/FocusBMApp 内にファイル追加で対応可 |
| T0.3 | FloatingWindowProvider AX 非同期化 | 振る舞い変更リスク大 → 今回スコープ外（Commander 承認済み） |
| T0.4 | BookmarkRowTests.swift 存在確認 | 未作成 → PhaseD の Red として新規作成対象に組込 |

**risk**: low / **token_budget**: 8,000 / **scope_constraint**: コード変更 0 行

---

## PhaseA: 辞書集約 + log() 共通化（P3 一部）

**Waste**: P3（log() 重複・絵文字辞書散在）

**touched_files**:
- `Sources/FocusBMLib/TmuxProvider.swift`（log 定義削除・絵文字辞書 2 関数(:192/:491)を EmojiCatalog へ移動）
- `Sources/FocusBMLib/ProcessProvider.swift`（log 定義削除・terminalBundleIdToEmoji 参照を EmojiCatalog 経由に置換）
- `Sources/FocusBMLib/Models.swift`（agentCommandToEmoji 参照を EmojiCatalog 経由に置換: :372/:374）
- `Sources/FocusBMLib/(新規) EmojiCatalog.swift`（絵文字辞書を単一定義）
- `Sources/FocusBMLib/(新規) DebugLog.swift`（log() を単一定義）
- ※ BookmarkRow.swift は絵文字定義・参照ともゼロ（実測 2026-06-11）のため PhaseA 対象外（PhaseD のフォント/panel 統合のみ）

**scope_constraint**: touched_lines <= 200 行（純粋データ移動のみ。検出ロジック本体は触らない）

**risk**: medium / **token_budget**: 30,000

**staff-validation**: 不要（低〜中リスク）

### RGR ステップ

#### Red
```
# 新規テストが失敗することを確認
# Tests/focusbmTests/(新規) EmojiCatalogTests.swift を作成し fail を記録
# Tests/focusbmTests/(新規) DebugLogTests.swift を作成し fail を記録
swift test 2>&1 | grep -E "failed|error"
# fail ログを Red 証跡として保存
```

#### Green
1. `EmojiCatalog.swift` に絵文字辞書（TmuxProvider:192/:491 の 2 定義）→1 箇所集約
2. `DebugLog.swift` に `log()` 共通化（`DebugLog.log(_:)` 等）
3. 各呼出元でリダイレクト（TmuxProvider / ProcessProvider / BookmarkRow / Models）
4. `swift test` 終了コード 0 確認

#### Refactor
1. 旧辞書定義・旧 log 定義の orphan を削除
2. 重複コメント整理

**anti_pattern_guard**: 絵文字/log の全箇所を横断 grep してから着手（実測確認済み 2026-06-11: 絵文字定義 1 ファイル(TmuxProvider)・参照 2 ファイル(ProcessProvider/Models)・log 定義 2 箇所）

**完了基準**:
```bash
# AC-3: log() 定義が1箇所のみ
grep -rn "private.*func log\|private static func log" Sources/ | wc -l
# 結果 = 1（DebugLog のみ）

# AC-4: 絵文字辞書が1箇所のみ
grep -rn "terminalBundleIdToEmoji\|agentCommandToEmoji" Sources/ | grep "func "
# 結果 = 1（EmojiCatalog のみ）

swift test 2>&1 | tail -3
# 終了コード 0、テスト数 >= 310
```

---

## PhaseD: SearchView 層 構造重複除去（P4）

**依存**: PhaseA 完了後（BookmarkRow.swift の同一ファイル編集 L1）

**Waste**: P4（LazyVStack / LazyVGrid 重複 ForEach ブロック）

**touched_files**:
- `Sources/FocusBMApp/SearchView.swift`（共通 ViewBuilder/ViewModifier 抽出）
- `Sources/FocusBMApp/BookmarkRow.swift`（フォント解決 3 箇所→1 ViewModifier・panel close+activate 4 回→1 ヘルパー）
- `Sources/FocusBMApp/SearchPanel.swift`（panel ヘルパー利用側）
- `Tests/FocusBMAppTests/(新規) BookmarkRowTests.swift`（T0.4 より新規作成）

**scope_constraint**: touched_lines <= 200（switch-over-SearchItem 18 サイトの型多態化は別ミッション）

**risk**: medium / **token_budget**: 28,000

**staff-validation**: 不要

### RGR ステップ

#### Red
```bash
# BookmarkRowTests.swift 新規作成 → fail 確認
# 既存 SearchViewModelGridTests を Red 基線として fail 確認（意図的な Red なし）
swift test 2>&1 | grep "BookmarkRowTests"
```

#### Green
1. SearchView で `LazyVStack` / `LazyVGrid` の ForEach ブロックを共通 `@ViewBuilder` に抽出
2. フォント解決 3 箇所→1 `ViewModifier`
3. `panel close + activate` 4 回→1 ヘルパー関数に抽出

#### Refactor
1. 重複コード削除
2. `swift test` 全 green 再確認

**完了基準**:
```bash
# SearchView に同一 ForEach ブロックが 2 個存在しないこと
# swift test 310 件以上 green
swift test 2>&1 | tail -3
```

---

## PhaseB: ShellRunner/ProcessRunner 抽出 + DI 化（P1）

**依存**: PhaseA 完了後

**Waste**: P1（Process() 直接生成: 実測 5 ファイル・18 呼出サイト（実測 2026-06-11））

**touched_files**:
- `Sources/FocusBMLib/(新規) ShellRunner.swift`（ShellRunnerProtocol + 本実装）
- `Sources/FocusBMLib/TmuxProvider.swift`（Process() 置換）
- `Sources/FocusBMLib/ProcessProvider.swift`（Process() 置換）
- `Sources/FocusBMLib/AppleScriptBridge.swift`（Process() 置換）
- `Sources/focusbm/focusbm.swift`（Process() 置換）
- `Sources/FocusBMApp/FocusBMApp.swift`（Process() 置換）

**scope_constraint**: touched_lines <= 200 行（18 呼出サイトの実測値に基づき再設定。1 コミット = 1 ファイル厳守 [M1]）

**risk**: high / **token_budget**: 15,000 tokens

**staff-validation**: 必須（TCC/権限依存・振る舞い不変が核心）

### 必須制約 M1（Commander 承認条件）

> PhaseB は 1 コミット = 1 ファイル。各コミット後に `swift test` 全 310 green を確認できない場合は即 `git revert HEAD` して再試行。一括コミット禁止。

### RGR ステップ

#### Red
```bash
# ShellRunnerProtocol + Mock のテスト作成
# Tests/focusbmTests/(新規) ShellRunnerTests.swift
# 既存 ProcessProviderTests / TmuxProviderTests を DI 差込み形に拡張し fail 確認
swift test 2>&1 | grep "ShellRunnerTests"
```

#### Green
1. `ShellRunner.swift` に `ShellRunnerProtocol`（run/runWithOutput）+ 本実装を定義
2. ファイル単位で段階置換（順序: TmuxProvider → ProcessProvider → AppleScriptBridge → focusbm.swift → FocusBMApp.swift）
3. 各ファイル置換後に `swift test` 全 green 確認
4. **除外対象**: `sysctlParentPID` / `proc_pidinfo` 系の低レベルシステムコール（perf-001 温存）

#### Refactor
1. 旧ボイラープレート削除
2. Mock を `@testable` 経由で整理

**anti_pattern_guard**:
- `sysctl` / `proc_pidinfo` 系は ShellRunner 化しない
- 置換前に `grep -rn "Process()" Sources/` で全箇所リストアップし除外を明示

**完了基準（AC-2）**:
```bash
grep -rn "Process()" Sources/ | grep -v "ShellRunner\|// exclude\|sysctl\|proc_pidinfo"
# 結果 = 0 件

swift test 2>&1 | tail -3
# 終了コード 0、テスト数 >= 310
```

---

## PhaseC: 検出ロジック統合 + TmuxProvider 分割（P2/P3 後半）

**依存**: PhaseB 完了後

**Waste**: P2（TmuxProvider God 型 848 行）/ P3（TmuxProvider ⇄ ProcessProvider 双方向循環依存（実測 2026-06-11）: TmuxProvider→ProcessProvider（aiAgentCommands・getCommandLineArgs 参照）+ ProcessProvider→TmuxProvider（terminalBundleIdToEmoji・sysctl 2 関数・findTerminalAppForTTY 参照）。PhaseA で emoji 経路 1 本を先に断ち、残る sysctl/TTY 系を PhaseC で TerminalDetector へ依存反転集約）

**touched_files**:
- `Sources/FocusBMLib/TmuxProvider.swift`（分割元・削除）
- `Sources/FocusBMLib/ProcessProvider.swift`（双方向循環依存の解消）
- `Sources/FocusBMLib/(新規) TerminalDetector.swift`（TTY/親子 PID/作業ディレクトリ解決を集約・sysctl 系依存を反転）
- `Sources/FocusBMLib/(新規) TmuxSession*.swift`（session 構築ロジック抽出先）

**scope_constraint**: 3 サブタスクに分割し各 <= 300 行。逸脱時 risk=high で即 re-run [M2]

**risk**: high / **token_budget**: 55,000

**staff-validation**: 必須（Cynefin=Complex・双方向循環依存あり）

### 必須制約 M2（Commander 承認条件）

> C.1/C.2/C.3 の各サブタスクで独立に Red→Green→Refactor を回し、各サブ完了時点で全 310 維持を必須。

### RGR ステップ

#### C.1: TTY/親子 PID/作業ディレクトリ解決の TerminalDetector 抽出

**Red**
```bash
# Tests/focusbmTests/(新規) TerminalDetectorTests.swift 作成 → fail 確認
swift test 2>&1 | grep "TerminalDetectorTests"
```

**Green**
- `TerminalDetector.swift` 新規作成
- `findTerminalAppForTTY` / `findTerminalByAncestorProcess` / TTY 解決ロジックを移動
- ProcessProvider→TmuxProvider の循環依存（sysctl 2 関数・findTerminalAppForTTY 参照）を TerminalDetector へ依存反転集約（PhaseA で emoji 経路は解消済みの前提）

**Refactor** → 旧定義削除、`swift test` 全 green 確認

#### C.2: TmuxProvider から session 構築ロジックを分割ファイルへ移動

**Red** → 移行テスト fail 記録

**Green**
- `TmuxSession*.swift`（命名は実装時に確定）に session 構築ロジックを移動
- TmuxProvider は 300 行以下を目安にスリム化

**Refactor** → `swift test` 全 green 確認

#### C.3: 重複検出ロジック・旧逆依存削除

**Red** → 削除前に全参照 grep で孤立確認

**Green** → 削除実施

**Refactor** → `swift test` 全 green 確認

**完了基準**:
```bash
# TmuxProvider.swift の行数が 300 行以下
wc -l Sources/FocusBMLib/TmuxProvider.swift

# ProcessProvider→TmuxProvider の直接 import がないこと
grep -n "TmuxProvider" Sources/FocusBMLib/ProcessProvider.swift

swift test 2>&1 | tail -3
```

---

## PhaseE: SearchViewModel/AppDelegate 分割 + YAML 統合（P2/P5）

**依存**: Phase0 完了後（PhaseA/B/C と touched_files 非競合 → wave1 で並列発射可）

**Waste**: P2（SearchViewModel God 型 434 行・AppDelegate 353 行）/ P5（YAML 実測 6 サイト: FocusBMApp.swift 5 箇所(:38/:198/:246/:298/:322) + SearchViewModel.swift:36 の 1 箇所。PhaseE 対象は FocusBMApp.swift の 5 箇所のみ — SearchViewModel:36 は Phase3 で単一化済みのためスコープ外（実測 2026-06-11））

**touched_files**:
- `Sources/FocusBMApp/SearchViewModel.swift`（責務抽出）
- `Sources/FocusBMApp/FocusBMApp.swift`（AppDelegate YAML 多重読込を単一化・責務抽出）
- `Sources/FocusBMLib/YAMLStorage.swift`（単一読込エントリーポイント確認・必要なら整理）

**scope_constraint**: 3 サブタスクに分割し各 <= 300 行 [M2]。migrateV1YAML 後方互換契約は不変。

**risk**: high / **token_budget**: 50,000

**staff-validation**: 必須（永続化スキーマ接触・migrateV1YAML 後方互換）

### RGR ステップ

#### Red
```bash
# YAMLStorageMigrationTests を後方互換基線として確認
# VM 分割テスト fail 記録
swift test 2>&1 | grep "YAMLStorageMigrationTests"
```

#### Green（サブタスク分割）

**E.1: AppDelegate YAML 多重読込の単一化（P5 解消）**
- FocusBMApp.swift の 5 箇所（:38/:198/:246/:298/:322）で個別呼出している `loadYAML()` を起動時 1 回の単一呼出に集約（SearchViewModel:36 は Phase3 で単一化済み・触らない）
- Phase3 で SearchViewModel 側に適用した同型修正を AppDelegate 側に適用

**E.2: SearchViewModel 責務抽出**
- `shortcutAssignments` / `gridToIndex` / `labelToIndex` 等のインデックス計算責務を別型に抽出
- `autoExecute` / `columns` 等の設定責務を AppSettings に集約
- 各抽出後に `swift test` 全 green 確認

**E.3: AppDelegate 責務抽出**
- ホットキー設定・ステータスバー設定・パネル設定を専用クラス/構造体に抽出

#### Refactor
1. 重複削除
2. `swift test` 全 green 確認

**anti_pattern_guard**: YAML 読込を全箇所横断検索後に着手（実測確認済み 2026-06-11: FocusBMApp.swift 5 箇所・SearchViewModel.swift 1 箇所の計 6 サイト。`grep -rn "loadBookmarks\|loadYAML\|\.yml" Sources/FocusBMApp/`）

**完了基準（AC-5）**:
```bash
grep -rn "loadBookmarks\|YAMLStorage\|\.yml\|readBookmarks" Sources/FocusBMApp/ | grep -v "//"
# FocusBMApp.swift 内の YAML 読込が YAMLStorage 経由の 1 箇所のみ

swift test 2>&1 | grep "YAMLStorageMigrationTests"
# 全 green

swift test 2>&1 | tail -3
# 終了コード 0、テスト数 >= 310
```

---

# Done-Definition（D1〜D9 全充足 = 完了）

| # | 完了条件 | 検証方法（Primary Truth） | 検証種別 |
|---|---------|----------------------|---------|
| D1 | 全フェーズ完了後、テスト総数が減らず全 green | `swift test` 終了コード 0 かつ テスト数 >= 310 | 自動 |
| D2 | RGR 遵守の物証（各フェーズで Red/Green/Refactor の 3 記録） | git log またはフェーズ完了マーカーに 3 記録 | 人間検証 |
| D3 | P1 除去: Process() 直接生成の集約 | AC-2 grep 0 件 + 除外リスト提出 | 自動+人間確認 |
| D4 | P3 除去: log()/絵文字辞書集約 | AC-3/AC-4 grep 定義 1 箇所のみ | 自動 |
| D5 | P2 除去: God 型分割 | 各 touched_lines が scope_constraint 内 | 自動 |
| D6 | P5 除去: YAML 多重読込解消 | AC-5 YAML 読込 1 箇所のみ、MigrationTests green | 自動 |
| D7 | 振る舞い不変 | YAMLStorageMigrationTests / SearchViewModelGridTests が期待値無変更で green | 自動 |
| D8 | scope 規律 | 各フェーズの実 touched_lines が scope_constraint 内（逸脱時 re-run 記録存在） | 人間検証 |
| D9 | 自動/人間検証の分離記録 | Phase Complete マーカーに「自動 Pass」と「人間検証 Pass」を別欄で記録 | 人間検証 |

**判定**: D1〜D9 全充足 = approved。1 つでも未達 = rejected（該当フェーズを re-run）。

---

# Acceptance Criteria（AC-1〜AC-10）

### AC-1: テスト数・全 green 維持（全フェーズ共通）
```bash
swift test 2>&1 | tail -3
# 終了コード 0 / テスト数 >= 310 / failed 0 件
```

### AC-2: Process() 直接生成の集約（PhaseB 完了条件）
```bash
grep -rn "Process()" Sources/ | grep -v "ShellRunner\|// exclude\|sysctl\|proc_pidinfo"
# 結果 = 0 件
```

### AC-3: log() 定義の単一化（PhaseA 完了条件）
```bash
grep -rn "private.*func log\|private static func log" Sources/ | wc -l
# 結果 = 1 以下（DebugLog のみ）
```

### AC-4: 絵文字辞書の単一化（PhaseA 完了条件）
```bash
grep -rn "terminalBundleIdToEmoji\|agentCommandToEmoji" Sources/ | grep "func "
# 結果 = 1 箇所（EmojiCatalog のみ）
```

### AC-5: YAML 読み込みの単一化（PhaseE 完了条件）
```bash
grep -rn "loadBookmarks\|YAMLStorage\|\.yml\|readBookmarks" Sources/FocusBMApp/ | grep -v "//"
# FocusBMApp.swift 内が YAMLStorage 経由 1 箇所のみ
```

### AC-6: コミット粒度の遵守（M1 必須条件）
```bash
git log --oneline
# PhaseB は 1 コミット = 1 ファイル。対象ファイル名がメッセージに明記
```

### AC-7: RGR サイクルの証跡（M2 必須条件）
各フェーズのコミットログに Red / Green / Refactor の 3 記録が存在すること。

### AC-8: touched_lines の scope_constraint 遵守（D8）
```bash
git diff --stat <phase-start-sha>..<phase-end-sha>
# PhaseA: <= 200 行 / PhaseB: ファイルごと <= 200 行（実測 18 呼出サイト根拠）/ PhaseC/E: <= 300 行 / PhaseD: <= 200 行
```

### AC-9: 既存テストの期待値無変更（D7）
```bash
git diff <phase-start-sha>..HEAD -- Tests/
# YAMLStorageMigrationTests.swift / SearchViewModelGridTests.swift の XCTAssert* 行に変更なし
```

### AC-10: スコープ外確定事項の非実装確認（A5 遵守）
```bash
git diff --name-only
# FloatingWindowProvider の AX 非同期化関連コード変更なし
# SearchItem 型多態化（switch-over 解消）関連コード変更なし
```

---

# リスク管理

| リスク | 確率 | 緩和策 |
|--------|------|--------|
| P1 ShellRunner 抽出で perf-001 の sysctl/proc_pidinfo 最適化を巻込み振る舞い変化 | medium | Process() のみ抽象化対象。sysctl/proc_pidinfo 系を grep で明示除外。staff-validation 併走 |
| PhaseC 検出統合で双方向循環依存（TmuxProvider ⇄ ProcessProvider: 実測 2026-06-11）解消時に循環/破壊 | high | TerminalDetector へ依存反転集約（PhaseA で emoji 経路先行断）。抽出/移動/削除の 3 サブタスクに分割しプローブ的に実施。各サブで全 310 維持確認 |
| P2 God 型分割で touched_lines が scope_constraint 逸脱 | high | 抽出/移動/削除の 3 タスク分割を必須化。逸脱検知時 risk=high で即 re-run |
| P5 型リグレッション（AppDelegate 側 YAML 5 重呼出残存の見落とし） | medium | YAML 読込を着手前に全横断 grep（実測: FocusBMApp.swift 5 箇所・SearchViewModel.swift 1 箇所）。Phase3 修正と同型を AppDelegate 側 5 箇所に適用 |
| Phase Complete マーカー過信による未検証完了 | medium | 自動テスト Pass と人間検証 Pass を別欄記録。Primary Truth=swift build/test 終了コード |

---

# 監視設定（Act フェーズ継承）

```
watch:
  - trigger: touched_lines > scope_constraint
    action: risk=high 昇格 → 即 re-run

  - trigger: Red ステップでテストが "失敗" していない
    action: 強制的に Red 証跡ログを要求（Green との分離）

trace:
  - event: フェーズ完了
    record: 自動テスト Pass (timestamp) / 人間検証 Pass (reviewer)
    format: "Phase {id} Complete — autoPass: {timestamp} | humanPass: {reviewer}"
```

---

# 参照ファイル

| ファイル | 行数 | 関連フェーズ |
|---------|------|------------|
| Sources/FocusBMLib/TmuxProvider.swift | 848 行 | A, C |
| Sources/FocusBMLib/ProcessProvider.swift | 10.4 KB | A, B, C |
| Sources/FocusBMLib/AppleScriptBridge.swift | 13.2 KB | B |
| Sources/FocusBMLib/Models.swift | 428 行 | A |
| Sources/FocusBMApp/SearchViewModel.swift | 434 行 | E |
| Sources/FocusBMApp/FocusBMApp.swift | 353 行 | B, E |
| Sources/FocusBMApp/SearchView.swift | 8.8 KB | D |
| Sources/FocusBMApp/BookmarkRow.swift | 3.4 KB | D（PhaseA から除外: 絵文字定義・参照ともゼロ、実測 2026-06-11）|
| Sources/FocusBMLib/YAMLStorage.swift | 2.2 KB | E |
| Tests/FocusBMAppTests/BookmarkRowTests.swift | 未作成 | D（Red） |

---

# 旧計画書（plan/process-*.md）整理方針

**PLAN.md が本ミッションの唯一の計画書（SSoT）である。**

`plan/process-*.md`（実測 10 ファイル: process-01〜03, process-10〜12, process-50, process-100, process-200, process-300）は過去フェーズの計画書であり、現在の PLAN.md の内容と重複・矛盾が生じる可能性がある。

## 整理ルール（後続 cycle で実行）

| ルール | 内容 |
|--------|------|
| 移動先 | `plan/archive/` ディレクトリへ移動（削除しない） |
| 実行タイミング | 全フェーズ（PhaseA〜E）完了後に一括移動 |
| 移動対象 | `plan/process-*.md` の全 10 ファイル |
| 残すもの | `PLAN.md`（本ファイル）のみ |
| 確認コマンド | `ls plan/archive/*.md \| wc -l` が 10 であること |

**注記**: 実行は cycle 2 スコープ外。後続 cycle（全フェーズ完了後）への申し送り事項として本セクションを残す。

---

# スコープ外（将来ミッション候補）

| 候補 | 理由 |
|------|------|
| FloatingWindowProvider の AX 非同期化 | 振る舞い変更リスク > 無駄除去便益（Commander 承認済み） |
| SearchItem switch-over の Protocol Witness 型多態化 | 18 サイト規模・振る舞いリスク > 便益（今回見送り） |
| Models.swift の HotkeyParser 分離 | 中規模・arch-008。別ミッション化を推奨 |
