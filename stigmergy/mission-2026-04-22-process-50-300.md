# Mission Retrospective: process-50 → process-300

## Mission Summary
- 日時: 2026-04-22
- 対象 process: 50, 100, 200, 300
- 目的: bookmarkListColumns 機能の最終検証・ドキュメント化・振り返り

## Execution Timeline
- Wave 1: process-100 (swift build/test) — 280 tests pass / warning 0
- USER-REPORT 1: SearchViewModel.swift:25 の internal(set) warning → 修正コミット bed5bfa
- USER-REPORT 2: 横2列が表示されない → bookmarks.yml に bookmarkListColumns: 2 未指定が原因（実装は正常）
- Wave 2: process-50 (GUI チェックリスト docs/manual-test-checklist.md, コミット 0113023)
- Wave 2: process-200 (README + bookmarks.example.yml, コミット ab6912f)
- Wave 3: process-300 (本振り返りファイル)

## OODA 振り返り（process-300 実装ノート準拠）

### Observe: 当初仮説と実態の差分
- 当初「TUI (ncurses系) かと思ったら SwiftUI アプリ」だった。macOS 専用の NSEvent 処理や LazyVGrid が登場し、汎用 TUI パターンの適用ができないと気づくまでに調査コストが発生した。
- Phase Complete マーカー付き plan ファイルを「完成済み」と判定したが、ユーザー実機で warning と「2列にならない」問題が発覚。マーカーは執筆者の意図を示すのみ。

### Orient: ViewModel 引き上げ戦略
- View 層（SwiftUI）は XCTest でのインスタンス化が困難なため、列数制御ロジックを SearchViewModel に引き上げた。
- これにより SearchViewModelGridTests として 16 ケースのユニットテストが成立し、View 層テスト不能性の問題を回避できた。

### Decide: 設定 Optional 化 + 不正値フォールバック
- `bookmarkListColumns: Int?` として未指定時は縦1列にフォールバックする設計を採用。
- 設定値が 1 以下や過大な場合も正規化して扱うことで、Codable パターンの再利用性を高めた。

### Act: TDD Red→Green→Refactor の実践結果
- process-10/11/12 (テスト追加) が先行し、process-04/05/06 (実装) でテストを通す順序で進めた。
- 10 と 12 は同一ファイル (AppSettingsTests.swift) を編集するため直列化が必要だった。並列化の前提として「ファイル競合チェック」が重要と再確認。

## Lessons Learned

### L1: 「Phase Complete マーカー」は実動作を保証しない
事前調査で全 process が Phase Complete マーカー付きと判定したが、ユーザー実機で warning と「2 列にならない」問題が発覚。マーカーは「執筆者の意図」を表すものであり、ビルド警告や設定ミスは別途検証が必要。

### L2: アクセス修飾子の冗長指定は warning を生む
Swift では `internal` がデフォルトのため、`internal(set) var` は冗長。`private(set)` から外す際は修飾子削除も同時に行う必要がある（Why コメントも同期更新）。

### L3: 設定ファイルのデフォルト挙動はドキュメント・サンプルで明示すべき
`bookmarkListColumns` 未指定 = 縦1列 という設計は、ユーザーから見ると「機能が動かない」と誤解される。bookmarks.example.yml の追加 (process-200) で再発防止できる。

### L4: micro-exec MUST#1 (10 エージェント) の機械的適用は逆効果
今回の残作業は 4 件で、ダミータスク 6 件を強制挿入すると逆にコンテキスト浪費。AskUserQuestion で部分適用モード (micro_exec_partial=true) を選択するのが妥当だった。

### L5: Agent tool の isolation: "worktree" は internal error の原因になり得る
Wave 1 で worktree 並列起動に失敗。worktree 不使用で sequential 実行に切り替えると安定動作。原因は未調査だが、リトライ前に直接実行を試す価値あり。

### L6: SwiftUI 画面のテスト容易性は ViewModel の責務分離で決まる（process-300 教訓候補より）
View 層は XCTest でのインスタンス化が困難。UI ロジックを ViewModel に集約することで、ユニットテストのカバレッジを最大化できる。

### L7: `LazyVStack` → `LazyVGrid` 切替は View 層の最小差分で列数対応が可能（process-300 教訓候補より）
GridItem の配列を列数に応じて切替えるだけで対応できる。View 側の変更量を最小化しつつ機能追加が可能なパターンとして再利用性が高い。

## Lessons JSONL（doctrine-learning 記録用）

```jsonl
{"date":"2026-04-22","project":"focusbm","pattern":"phase-complete-marker-is-not-verification","summary":"Phase Complete マーカーはビルド警告や実動作を保証しない。自動テスト Pass と人間検証 Pass を分離して記録すること。","tags":["process-management","verification"],"applicability":"all projects using plan files with Phase Complete markers"}
{"date":"2026-04-22","project":"focusbm","pattern":"swift-internal-access-redundancy","summary":"Swift の internal はデフォルト修飾子のため、internal(set) は警告の原因になる。アクセス修飾子変更時は冗長指定を同時に除去する。","tags":["swift","access-control","warning"],"applicability":"Swift projects"}
{"date":"2026-04-22","project":"focusbm","pattern":"config-default-must-be-documented","summary":"設定キー未指定時の挙動はドキュメントと example ファイルに必ず明示する。暗黙のデフォルトはユーザーに「機能が動かない」と誤解させる。","tags":["config","documentation","ux"],"applicability":"any project with optional config keys"}
{"date":"2026-04-22","project":"focusbm","pattern":"swiftui-vm-liftup","summary":"SwiftUI View 層はテスト困難。列数制御等の UI ロジックを ViewModel に引き上げることで XCTest カバレッジを最大化できる。","tags":["swiftui","viewmodel","testability","tdd"],"applicability":"similar UI toggle tasks in SwiftUI projects"}
{"date":"2026-04-22","project":"focusbm","pattern":"lazyvgrid-minimal-diff","summary":"LazyVStack から LazyVGrid への切替は GridItem 配列の切替のみで実現できる。View 側変更を最小化しつつ列数対応が可能。","tags":["swiftui","lazyvgrid","minimal-change"],"applicability":"SwiftUI list/grid toggle features"}
```

## Improvement Suggestions

1. 事前調査の Explore agent には「ビルド警告チェック」「実機動作仮検証」も含める
2. Plan ファイルの Phase Complete マーカーは「自動テスト Pass」と「人間検証 Pass」を分離する
3. 設定キー追加時は `*.example.yml` の更新を Affected Files に必ず含める
4. micro-exec MUST 違反時の AskUserQuestion を初動で実施するルールを徹底
5. 並列 executor 起動前にファイル競合チェックを必須化し、競合ファイルを共有する executor は直列化する

## Final Status
- swift build: warning 0
- swift test: 280 / 280 pass
- 新規ファイル: docs/manual-test-checklist.md, bookmarks.example.yml, stigmergy/mission-2026-04-22-process-50-300.md
- 更新ファイル: README.md, Sources/FocusBMApp/SearchViewModel.swift
- コミット: bed5bfa, 0113023, ab6912f, (本コミット)

## Phase Complete
