# Process 10: フォーカス復元テスト

## Overview
Process 1 で実装したフォーカス復元機構のテストを追加する。SearchPanel の previousApp キャプチャと close() 時の復元動作を検証する。

## 調査結果サマリー（テスト設計コンテキスト）

### テスト対象の動作仕様
1. `makeKeyAndOrderFront()` 呼び出し時に `NSWorkspace.shared.frontmostApplication` が `previousApp` にキャプチャされる
2. `close()` 呼び出し時に `previousApp?.activate()` が実行される
3. `close()` 完了後、`previousApp` は nil になる
4. OK paths (P4-P8) では close() 内の activate() 後に target.activate() が DispatchQueue.main.async で実行され上書きする

### 既存テスト構造
- `Tests/FocusBMAppTests/ShortcutBarTests.swift` — ショートカットバー専用
- `Tests/FocusBMAppTests/SearchViewModelOrderingTests.swift` — ViewModel 順序ロジック
- `Tests/focusbmTests/` — lib 層テスト
- **SearchPanel の close/focus テストは現在ゼロ**

### テストの制約
- `NSRunningApplication.activate()` はシステムレベルの操作のため、ユニットテストでの直接検証は困難
- `NSWorkspace.shared.frontmostApplication` もテスト環境では予測不能
- **推奨アプローチ**: プロパティの状態変化（previousApp の set/nil）を検証するインテグレーションテスト

## Affected Files
- `Tests/FocusBMAppTests/SearchPanelFocusTests.swift` (新規作成)

## Implementation Notes

### テストファイル構成

```swift
import XCTest
@testable import FocusBMApp

final class SearchPanelFocusTests: XCTestCase {

    // MARK: - previousApp キャプチャテスト

    /// makeKeyAndOrderFront() 後に previousApp が設定されることを検証
    /// 注意: CI 環境ではウィンドウサーバーが利用できない場合があるため、
    ///       @available チェックまたは skip を検討
    func testMakeKeyAndOrderFrontCapturesPreviousApp() throws {
        // SearchPanel を生成（テスト用の最小構成）
        // makeKeyAndOrderFront() を呼ぶ
        // previousApp が nil でないことを検証
        // 注意: previousApp は private なので、テスト用にアクセスする方法が必要
        //       - Option A: @testable import で internal に変更
        //       - Option B: テスト用のヘルパーメソッドを追加
    }

    // MARK: - close() フォーカス復元テスト

    /// close() 後に previousApp が nil にリセットされることを検証
    func testCloseResetsPreviousApp() throws {
        // SearchPanel を生成
        // makeKeyAndOrderFront() でキャプチャ
        // close() を呼ぶ
        // previousApp が nil であることを検証
    }

    /// close() を2回連続呼び出しても安全であることを検証（べき等性）
    func testDoubleCloseIsSafe() throws {
        // SearchPanel を生成
        // makeKeyAndOrderFront() でキャプチャ
        // close() を2回呼ぶ
        // クラッシュしないことを検証（previousApp は1回目で nil になるため2回目は no-op）
    }

    // MARK: - エッジケーステスト

    /// makeKeyAndOrderFront() を呼ばずに close() しても安全であることを検証
    func testCloseWithoutMakeKeyIsSafe() throws {
        // SearchPanel を生成（makeKeyAndOrderFront を呼ばない）
        // close() を呼ぶ
        // previousApp が nil のまま → activate() は呼ばれない → 安全
    }
}
```

### previousApp のアクセシビリティについて
`previousApp` は `private` で宣言する予定（Process 1）。テストからアクセスするには:
- **推奨**: `private` を `internal` に変更し、`@testable import` で参照（テスト専用）
- **代替**: テスト用の `var testPreviousApp: NSRunningApplication? { previousApp }` を `#if DEBUG` で追加

### テスト実行環境の注意
- macOS の GUI テストは CI 環境（headless）では失敗する可能性がある
- `NSPanel` の生成自体はウィンドウサーバーなしでも動作するが、`makeKeyAndOrderFront()` はウィンドウサーバーが必要
- 必要に応じて `XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)` を追加

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] `Tests/FocusBMAppTests/SearchPanelFocusTests.swift` を新規作成
- [ ] 上記4テストケースを作成（Process 1 未実装のため失敗する）
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] Process 1 が完了していることを確認
- [ ] previousApp のアクセシビリティを調整（private → internal または DEBUG ヘルパー）
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] CI 環境でのスキップ処理が適切か確認
- [ ] テストケース名が意図を明確に表現しているか確認
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: Process 1
- Blocks: -
