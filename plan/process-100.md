# Process 100: 全体回帰テストと Swift build/test 実行

## Overview
Process 1-12 完了後に `swift build` と `swift test` を全件実行し、既存機能（低優先度順序・設定 round-trip 等）への回帰がないことを確認する。

## Affected Files
- 実行のみ（変更なし）

## Implementation Notes
- コマンド:
  ```bash
  cd /Users/ttakeda/repos/focusbm
  swift build 2>&1 | tee /tmp/focusbm-build.log
  swift test 2>&1 | tee /tmp/focusbm-test.log
  ```
- 期待: 警告ゼロ or 既存水準維持、テスト全 Green
- 既存テスト要注意:
  - `AppSettingsTests.swift` — round-trip が崩れていないこと
  - `SearchViewModelOrderingTests.swift` — 優先度順序が破壊されていないこと
  - `focusbmTests` 全体 — YAML I/O が安定
- 失敗時の切り分け:
  - Models.swift の Codable 互換（Process 1-2 の影響）
  - ViewModel の副作用（Process 3 の影響）
  - KeyMonitor の NSEvent 処理（Process 5 の影響、ただし単体テスト対象外）

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] （新規テストは Process 10/11/12 で作成済み）
- [ ] 実装前状態で `swift test` を実行し Red 数をベースラインとして記録

Phase Complete

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `swift build` が通る
- [ ] `swift test` が全件 Green
- [ ] 警告数がベースライン以下
- [ ] ベースラインからの新規 fail ゼロを確認

Phase Complete

---

## Refactor Phase: 品質改善

- [ ] テスト実行時間をログに記録
- [ ] `swift test --parallel` の適用可否確認
- [ ] テストが継続して成功することを確認

Phase Complete

---

## Dependencies
- Requires: 10, 11, 12
- Blocks: 50, 200, 300
