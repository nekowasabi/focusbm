import Testing
import Foundation
@testable import FocusBMApp
@testable import FocusBMLib

// MARK: - Helpers

private func makeBookmark(
    name: String,
    appName: String,
    lowPriority: Bool = false,
    noShortcut: Bool = false,
    shortcut: String? = nil
) -> Bookmark {
    var bm = Bookmark(
        id: name,
        appName: appName,
        bundleIdPattern: nil,
        context: "",
        state: .app(windowTitle: ""),
        createdAt: "2024-01-01T00:00:00Z"
    )
    bm.lowPriority = lowPriority
    bm.noShortcut = noShortcut
    bm.shortcut = shortcut  // RED PHASE: Bookmark.shortcut は未実装 → compile error expected
    return bm
}

private func makeTmuxPane(id: String) -> TmuxPane {
    TmuxPane(
        paneId: id,
        sessionName: "test",
        windowIndex: 0,
        windowName: "win",
        command: "claude",
        title: "Claude Code",
        currentPath: "/tmp"
    )
}

private func makeAIProcess(pid: Int32) -> ProcessProvider.AIProcess {
    ProcessProvider.AIProcess(
        pid: pid,
        command: "claude",
        workingDirectory: "/tmp",
        terminalBundleId: "com.apple.Terminal",
        terminalAppName: "Terminal",
        terminalEmoji: "💻",
        title: "claude"
    )
}

// MARK: - query.isEmpty ordering tests

/// query.isEmpty 時: lowPriority ブックマークは tmuxPane より後ろに来ること
@Test func test_emptyQuery_lowPriorityBookmark_appearsAfterTmuxPane() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [])
    vm.updateItems()

    let indices = vm.searchItems.enumerated().reduce(into: [String: Int]()) { acc, pair in
        let (i, item) = pair
        switch item {
        case .bookmark(let b) where b.lowPriority == true: acc["lpBookmark"] = i
        case .tmuxPane: acc["tmux"] = i
        default: break
        }
    }

    guard let tmuxIdx = indices["tmux"], let lpIdx = indices["lpBookmark"] else {
        Issue.record("tmuxPane or lowPriority bookmark missing from searchItems")
        return
    }
    #expect(tmuxIdx < lpIdx, "tmuxPane should appear before lowPriority bookmark (tmux=\(tmuxIdx), lp=\(lpIdx))")
}

/// query.isEmpty 時: lowPriority ブックマークは aiProcess より後ろに来ること
@Test func test_emptyQuery_lowPriorityBookmark_appearsAfterAIProcess() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "slack", appName: "com.tinyspeck.slackmacgap", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [], aiProcesses: [makeAIProcess(pid: 9999)])
    vm.updateItems()

    let indices = vm.searchItems.enumerated().reduce(into: [String: Int]()) { acc, pair in
        let (i, item) = pair
        switch item {
        case .bookmark(let b) where b.lowPriority == true: acc["lpBookmark"] = i
        case .aiProcess: acc["ai"] = i
        default: break
        }
    }

    guard let aiIdx = indices["ai"], let lpIdx = indices["lpBookmark"] else {
        Issue.record("aiProcess or lowPriority bookmark missing from searchItems")
        return
    }
    #expect(aiIdx < lpIdx, "aiProcess should appear before lowPriority bookmark (ai=\(aiIdx), lp=\(lpIdx))")
}

/// query.isEmpty 時: 通常ブックマーク → AI エージェント → lowPriority ブックマーク の順序
@Test func test_emptyQuery_fullOrder_normalThenAIThenLowPriority() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%2")], aiProcesses: [])
    vm.updateItems()

    // 期待: [normal, tmux, lpBookmark]
    let labels: [String] = vm.searchItems.map { item in
        switch item {
        case .bookmark(let b): return b.lowPriority == true ? "lp" : "normal"
        case .tmuxPane: return "tmux"
        case .aiProcess: return "ai"
        case .floatingWindow: return "window"
        }
    }

    #expect(labels == ["normal", "tmux", "lp"],
            "Expected [normal, tmux, lp] but got \(labels)")
}

/// query.isEmpty 時: lowPriority ブックマークのみ（AI エージェントなし）でも末尾に来ること
@Test func test_emptyQuery_noAIAgents_lowPriorityBookmark_isLast() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.updateItems()

    guard let lastItem = vm.searchItems.last else {
        Issue.record("searchItems is empty")
        return
    }
    if case .bookmark(let b) = lastItem {
        #expect(b.lowPriority == true, "Last item should be lowPriority bookmark")
    } else {
        Issue.record("Last item is not a bookmark: \(lastItem)")
    }
}

// MARK: - query あり ordering tests

/// query あり時: lowPriority アイテムは末尾に来ること
@Test func test_withQuery_lowPriorityItems_appearsAtEnd() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "chrome-pulls", appName: "com.google.Chrome", lowPriority: true),
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.query = "g"  // 両方マッチするクエリ
    vm.updateItems()

    guard let lastItem = vm.searchItems.last else {
        Issue.record("searchItems is empty")
        return
    }
    #expect(lastItem.lowPriority == true,
            "Last item should be lowPriority, but got \(lastItem.debugLabel)")
}

// MARK: - Alphabet Shortcut Tests (TDD Red Phase)
// NOTE: These tests reference Bookmark.shortcut and SearchViewModel.labelToIndex
//       which do not yet exist. Compile errors are EXPECTED until Tasks #2 and #3
//       are implemented.

/// shortcut:"g" を持つアイテムの shortcutAssignments ラベルが "g" になること
@Test func test_shortcutOverride_usesYAMLLabel() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let ghosttyPair = assignments.first(where: { $0.item.id == "ghostty" }) else {
        Issue.record("ghostty not found in shortcutAssignments")
        return
    }
    #expect(ghosttyPair.label == "g",
            "Expected label 'g' but got \(String(describing: ghosttyPair.label))")
}

/// shortcut:"g" を持つアイテムは auto-assign スロット "1" を占有しないこと
@Test func test_shortcutOverride_doesNotConflictWithAutoAssign() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let chromePair = assignments.first(where: { $0.item.id == "chrome" }) else {
        Issue.record("chrome not found in shortcutAssignments")
        return
    }
    // chrome は shortcut 未指定なので auto-assign "1" を得るはず（ghostty の "g" とは別枠）
    #expect(chromePair.label == "1",
            "Expected auto-assign label '1' but got \(String(describing: chromePair.label))")
}

/// noShortcut:true は shortcut フィールドより優先されること（ラベルなし）
@Test func test_noShortcut_withShortcutField_isIgnored() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", noShortcut: true, shortcut: "a"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let pair = assignments.first(where: { $0.item.id == "ghostty" }) else {
        Issue.record("ghostty not found in shortcutAssignments")
        return
    }
    #expect(pair.label == nil,
            "noShortcut:true should override shortcut field, but got label \(String(describing: pair.label))")
}

/// labelToIndex["g"] が ghostty アイテムの配列インデックスを返すこと
@Test func test_labelToIndex_containsOverriddenLabel() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    // RED PHASE: vm.labelToIndex は SearchViewModel に未実装 → compile error expected
    guard let index = vm.labelToIndex["g"] else {
        Issue.record("labelToIndex does not contain key 'g'")
        return
    }
    let item = vm.searchItems[index]
    #expect(item.id == "ghostty",
            "Expected ghostty at labelToIndex['g'] but got \(item.id)")
}

/// shortcut 未指定のアイテムは "1","2","3",... の自動ラベルを得ること
@Test func test_labelToIndex_autoAssignedLabels() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
        makeBookmark(name: "slack", appName: "com.tinyspeck.slackmacgap"),
    ]
    vm.updateItems()

    // RED PHASE: vm.labelToIndex は SearchViewModel に未実装 → compile error expected
    let map = vm.labelToIndex
    #expect(map["1"] != nil, "Expected label '1' in labelToIndex")
    #expect(map["2"] != nil, "Expected label '2' in labelToIndex")
    #expect(map["3"] != nil, "Expected label '3' in labelToIndex")
    if let idx1 = map["1"] { #expect(vm.searchItems[idx1].id == "ghostty") }
    if let idx2 = map["2"] { #expect(vm.searchItems[idx2].id == "chrome") }
    if let idx3 = map["3"] { #expect(vm.searchItems[idx3].id == "slack") }
}

/// 同じ shortcut:"g" を持つ2アイテムでは最初のアイテムが優先されること
@Test func test_duplicateShortcut_firstWins() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "gitkraken", appName: "com.axosoft.gitkraken", shortcut: "g"),
    ]
    vm.updateItems()

    // RED PHASE: vm.labelToIndex は SearchViewModel に未実装 → compile error expected
    guard let index = vm.labelToIndex["g"] else {
        Issue.record("labelToIndex does not contain key 'g'")
        return
    }
    let item = vm.searchItems[index]
    #expect(item.id == "ghostty",
            "First item should win on duplicate shortcut, but got \(item.id)")
}

/// shortcutAssignments の各エントリの label プロパティが String? 型であること
@Test func test_shortcutAssignments_labelIsString() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let pair = assignments.first else {
        Issue.record("shortcutAssignments is empty")
        return
    }
    // RED PHASE: pair.label は存在しない（現在は pair.digit: Int?）→ compile error expected
    let _: String? = pair.label
    #expect(pair.label == "1",
            "First auto-assigned item should get label '1' but got \(String(describing: pair.label))")
}
