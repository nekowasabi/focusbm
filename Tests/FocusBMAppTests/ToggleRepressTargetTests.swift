import Testing
import Foundation
@testable import FocusBMApp
@testable import FocusBMLib

private func makeBookmark(id: String, executeOnToggleRepress: Bool? = nil) -> Bookmark {
    var bm = Bookmark(
        id: id,
        appName: "App",
        bundleIdPattern: nil,
        context: "",
        state: .app(windowTitle: ""),
        createdAt: "2024-01-01T00:00:00Z"
    )
    bm.executeOnToggleRepress = executeOnToggleRepress
    return bm
}

/// executeOnToggleRepress:true のブックマークが toggleRepressTarget になること
@Test func toggleRepressTarget_returnsFlaggedBookmark() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(id: "other"),
        makeBookmark(id: "focusbm-nvim", executeOnToggleRepress: true),
    ]
    vm.updateItems()

    #expect(vm.toggleRepressTarget?.id == "focusbm-nvim")
}

/// フラグ未指定時は nil を返すこと（呼び出し側で選択中アイテムへフォールバックする契約）
@Test func toggleRepressTarget_nilWhenUnconfigured() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(id: "ghostty"),
        makeBookmark(id: "chrome", executeOnToggleRepress: false),
    ]
    vm.updateItems()

    #expect(vm.toggleRepressTarget == nil)
}

/// 複数指定時は YAML 先着優先であること
@Test func toggleRepressTarget_firstWinsOnDuplicates() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(id: "first", executeOnToggleRepress: true),
        makeBookmark(id: "second", executeOnToggleRepress: true),
    ]
    vm.updateItems()

    #expect(vm.toggleRepressTarget?.id == "first")
}

/// 検索クエリで対象が絞り込み結果から消えても toggleRepressTarget は変わらないこと
/// （再押下の実行対象はクエリ・選択状態に依存しない固定指定）
@Test func toggleRepressTarget_ignoresQueryFilter() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(id: "focusbm-nvim", executeOnToggleRepress: true),
        makeBookmark(id: "ghostty"),
    ]
    vm.query = "ghostty"  // 指定ブックマークは絞り込み結果から外れる
    vm.updateItems()

    #expect(vm.toggleRepressTarget?.id == "focusbm-nvim")
}
