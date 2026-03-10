import Testing
import Foundation
@testable import FocusBMApp
@testable import FocusBMLib

// MARK: - Helpers

private func makeBookmark(
    name: String,
    appName: String,
    lowPriority: Bool = false
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
