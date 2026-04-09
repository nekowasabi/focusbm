# Process 1: SearchPanel フォーカス復元機構追加

## Overview
SearchPanel の close() でフォーカスが失われる問題を修正する。makeKeyAndOrderFront() で直前のアクティブアプリをキャプチャし、close() で復元する。変更は SearchPanel.swift のみ（~10行）。

## 調査結果サマリー（実装コンテキスト）

### 根本原因
`toggleSearchPanel()` (FocusBMApp.swift:266) で `NSApp.activate(ignoringOtherApps: true)` によりFocusBMがフォーカスを奪取するが、`close()` override (SearchPanel.swift:64-67) にフォーカス返却処理がない。

### Close Path 分析（8経路）

**バグのあるパス（3件）— 修正対象:**

| ID | トリガー | 場所 | 現在の動作 |
|----|---------|------|-----------|
| P1 | Escape キー (keyCode 53) | SearchPanel.swift:141-142 | `self.close()` のみ — activate() なし |
| P2 | cancelOperation(_:) | SearchPanel.swift:54-55 | `close()` のみ — activate() なし |
| P3 | ホットキートグル (Cmd+Ctrl+B) | FocusBMApp.swift:255-257 | `panel.close()` のみ — activate() なし |

**正常なパス（5件）— 変更不要:**

| ID | トリガー | 場所 | 現在の動作 |
|----|---------|------|-----------|
| P4 | Enter/onSubmit | SearchView.swift:22-25 | `panel?.close()` → `DispatchQueue.main.async { target.activate() }` |
| P5 | 行タップ | SearchView.swift:68-71 | 同上 |
| P6 | ショートカットバー | SearchView.swift:113-116 | 同上 |
| P7 | 数字/アルファベットキー | SearchPanel.swift:90-93 (activateItem) | `self.close()` → `DispatchQueue.main.async { target.activate() }` |
| P8 | auto-execute | SearchPanel.swift:44-48 (onAutoExecute → activateItem) | P7 経由 |

### 二重 activate の安全性（確認済み）
close() 内の `previousApp.activate()` は**同期実行**（現在の run-loop ターン）。
OK paths (P4-P8) の `target.activate()` は `DispatchQueue.main.async` で**次の run-loop ターン**で実行。
macOS の `NSRunningApplication.activate()` は「後勝ち」セマンティクスのため、target が最終的にアクティブになる。

**動作順序（P4 onSubmit のケース）:**
1. `panel?.close()` 呼び出し（同期）
2. close() 内: `previousApp.activate()` 実行（同期、現在の run-loop）
3. close() 内: `super.close()` 実行（同期）
4. close() から return
5. `DispatchQueue.main.async` ブロック実行（非同期、次の run-loop）
6. `target.activate()` 実行 → **target が最終的なアクティブアプリになる**

### キャプチャタイミング
`NSWorkspace.shared.frontmostApplication` は `NSApp.activate()` (FocusBMApp.swift:266) の**前**に取得する必要がある。
activate() 後は focusbm 自身が `frontmostApplication` として返される。

**最適なキャプチャポイント**: `makeKeyAndOrderFront()` override 内の `super` 呼び出し前 (SearchPanel.swift:58)。
- 理由: toggleSearchPanel() 以外のパネル表示パスが将来追加されても自動的にキャプチャされる
- 現在 toggleSearchPanel() が唯一のパネル表示経路だが、一元化により将来の拡張に対応

### パネル表示フロー（完全トレース）
```
CGEventTap callback (background thread, FocusBMApp.swift:108-111)
  → handleCGEvent()
  → L153: DispatchQueue.main.async { self?.toggleSearchPanel() }
        ↓ (dispatched to main thread)
toggleSearchPanel() — FocusBMApp.swift:254-272
  L255: guard let panel = searchPanel
  L256: if panel.isVisible → panel.close()   ← P3 バグパス
  else:
    L259: viewModel.load()
    L262: viewModel.isActive = false
    L265: panel.makeKeyAndOrderFront(nil)     ← ここでキャプチャすべき
    L266: NSApp.activate(ignoringOtherApps: true)  ← ここでフォーカス奪取
    L269: DispatchQueue.main.async { viewModel.isActive = true }
```

### 重要な発見事項
- **windowDidResignKey / windowDidBecomeKey**: 未実装（NSWindowDelegate 不在）
- **viewModel.isActive**: close() で false にリセットされない（ただし benign — 次の open の L262 で自動リセット）
- **NotificationCenter observers**: ゼロ（super.close() の willCloseNotification/didCloseNotification は発火するが、誰も監視していない）
- **stopLocalKeyMonitor()**: べき等（nil ガード付き、SearchPanel.swift:150-155）
- **他のパネル表示経路**: なし — toggleSearchPanel() が唯一の makeKeyAndOrderFront() 呼び出し元

## Affected Files
- `Sources/FocusBMApp/SearchPanel.swift`:
  - プロパティ追加: `private var previousApp: NSRunningApplication?`（クラス定義内）
  - L58-62: `makeKeyAndOrderFront()` にキャプチャ処理追加（super 呼び出し前）
  - L64-67: `close()` にフォーカス復元処理追加（super.close() の後）

## Implementation Notes

### 現在のコード（SearchPanel.swift）

```swift
// L58-62: makeKeyAndOrderFront — 現在の実装
override func makeKeyAndOrderFront(_ sender: Any?) {
    switchToASCIIInput()
    super.makeKeyAndOrderFront(sender)
    startLocalKeyMonitor()
}

// L64-67: close — 現在の実装
override func close() {
    stopLocalKeyMonitor()
    super.close()
}
```

### 修正後のコード

```swift
// プロパティ追加（クラス定義内、他のプロパティの近くに配置）
// Why: close()一点で全close pathのフォーカス復元をカバーするため、
//      パネル表示時の前アプリ参照を保持する。各close pathに個別にactivate()を
//      追加する方式(Strategy D)ではなく一元管理を選択した理由:
//      将来のclose path追加でも自動的にフォーカス復元が保証されるため
private var previousApp: NSRunningApplication?

// makeKeyAndOrderFront — キャプチャ追加
override func makeKeyAndOrderFront(_ sender: Any?) {
    // Why: toggleSearchPanel()内ではなくここでキャプチャする理由:
    //      将来のパネル表示経路追加でも自動的にキャプチャされるため。
    //      NSApp.activate()の前に取得必須 — activate()後はfocusbm自身が返される
    previousApp = NSWorkspace.shared.frontmostApplication
    switchToASCIIInput()
    super.makeKeyAndOrderFront(sender)
    startLocalKeyMonitor()
}

// close — フォーカス復元追加
override func close() {
    let appToRestore = previousApp
    previousApp = nil  // 先にnilクリア（再入防止）
    stopLocalKeyMonitor()
    super.close()
    // Why: super.close()の後にactivate()する理由:
    //      パネルが完全に閉じてからフォーカスを移動させるため。
    //      OK paths (P4-P8)ではこの後にDispatchQueue.main.asyncで
    //      target.activate()が実行され、このactivateを上書きする（後勝ち）
    appToRestore?.activate()
}
```

### エッジケース対応（追加実装は不要 — 既存の仕組みで対処済み）
1. **前アプリが終了済み**: `NSRunningApplication.activate()` は静かに false を返す（クラッシュなし）。ActivationTarget.swift:17-18 にも isTerminated ガードなし — 既存パターンと一致
2. **Desktop がアクティブだった場合**: `frontmostApplication` は Finder (com.apple.finder) を返す — Finder にフォーカスが戻り正常動作
3. **focusbm 自身がアクティブだった場合**: 自身への activate() は no-op — benign
4. **rapid open/close**: previousApp は makeKeyAndOrderFront() で毎回上書きされるため stale にならない。ただしパネル表示→即閉じ（viewModel.isActive = true の async が未発火）の場合、isActive が true のまま残るが次の open で自動リセット（L262）
5. **macOS 14+ deprecated API**: `activate(options: .activateIgnoringOtherApps)` は deprecated だが、引数なしの `activate()` は deprecated ではない。引数なし版を使用する
6. **Cmd+Tab during panel display**: ユーザーがパネル表示中に Cmd+Tab でアプリを切り替えた場合、previousApp は最初のキャプチャ値のまま。close() でそのアプリに戻るが、ユーザーが意図的に切り替えた後なので不自然になる可能性がある。MVP では許容。改善する場合は NSWorkspace の activeApplication 変更通知を監視して previousApp を更新する

### 修正の評価（4戦略比較 — Strategy A改 を採用）

| 戦略 | 評価 | 理由 |
|------|------|------|
| **A（改）: close() + makeKeyAndOrderFront()** | **★★★★★** | 全パスカバー、変更局所化、1ファイルのみ |
| B: toggleSearchPanel() でキャプチャ | ★★☆☆☆ | レイヤー分離悪化、A と同等カバレッジで劣位 |
| C: NSWindowDelegate + windowWillClose | ★★☆☆☆ | キャプチャタイミング問題は A と同じ、配線コスト増 |
| D: バグパス個別修正 | ★☆☆☆☆ | 単独では成立しない — activate 対象の情報がない |

---

## Red Phase: テスト作成と失敗確認

- [ ] ブリーフィング確認
- [ ] テストケースを作成（実装前に失敗確認）
  - close() 後に previousApp が nil になること
  - makeKeyAndOrderFront() 後に previousApp が non-nil になること
  - close() が呼ばれた時点で previousApp.activate() が呼ばれること（モック使用）
- [ ] テストを実行して失敗することを確認

✅ **Phase Complete**

---

## Green Phase: 最小実装と成功確認

- [ ] ブリーフィング確認
- [ ] `private var previousApp: NSRunningApplication?` プロパティを SearchPanel クラスに追加
- [ ] `makeKeyAndOrderFront()` override の先頭に `previousApp = NSWorkspace.shared.frontmostApplication` を追加
- [ ] `close()` override に `let appToRestore = previousApp; previousApp = nil` + `appToRestore?.activate()` を追加
- [ ] ビルドが通ることを確認 (`swift build`)
- [ ] テストを実行して成功することを確認

✅ **Phase Complete**

---

## Refactor Phase: 品質改善

- [ ] Why コメントが適切に記載されていることを確認
- [ ] 不要な変数・中間処理がないことを確認
- [ ] テストが継続して成功することを確認

✅ **Phase Complete**

---

## Dependencies
- Requires: -
- Blocks: Process 10
