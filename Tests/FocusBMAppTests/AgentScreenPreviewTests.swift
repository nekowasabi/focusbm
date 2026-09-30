import Foundation
import Testing
@testable import FocusBMApp
@testable import FocusBMLib

private final class ScreenPreviewCaptureProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String: String]
    private var capturedPaneIDs: [String] = []

    init(texts: [String: String]) {
        self.texts = texts
    }

    func capture(_ paneID: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        capturedPaneIDs.append(paneID)
        return texts[paneID]
    }

    func update(_ text: String, for paneID: String) {
        lock.lock()
        defer { lock.unlock() }
        texts[paneID] = text
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return capturedPaneIDs.count
    }

    var paneIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return capturedPaneIDs
    }
}

@Test func agentScreenPreview_hoveredCaptureShowsScreenOnly() {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { paneId in
        #expect(paneId == "%52")
        return "❯ 1. continue\n  2. something else"
    }
    let pane = TmuxPane(
        paneId: "%52",
        sessionName: "0",
        windowIndex: 1,
        windowName: "cursor-agent",
        command: "cursor-agent",
        title: "Preview On Hover",
        currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(pane)]
    viewModel.hoveredIndex = 0

    #expect(viewModel.showHoveredAgentPreview())
    #expect(viewModel.screenPreview == .single(AgentScreenCapture(
        id: "%52",
        title: pane.displayNameWithoutEmoji,
        text: "❯ 1. continue\n  2. something else",
        index: 1
    )))
}

@Test func agentScreenPreview_dropsBlankPaddingBelowPrompt() {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { _ in "❯ prompt\n\n\n          \n" }
    let pane = TmuxPane(
        paneId: "%2",
        sessionName: "0",
        windowIndex: 3,
        windowName: "claude",
        command: "claude",
        title: "Claude Code",
        currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(pane)]
    viewModel.hoveredIndex = 0

    #expect(viewModel.showHoveredAgentPreview())
    #expect(viewModel.screenPreview == .single(AgentScreenCapture(
        id: "%2",
        title: pane.displayNameWithoutEmoji,
        text: "❯ prompt",
        index: 1
    )))
}

@Test func agentScreenPreview_escapeDismissesCaptureWithoutClearingItems() {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { _ in "screen" }
    let pane = TmuxPane(
        paneId: "%1",
        sessionName: "s",
        windowIndex: 0,
        windowName: "claude",
        command: "claude",
        title: "Claude Code",
        currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(pane)]
    viewModel.hoveredIndex = 0
    #expect(viewModel.showHoveredAgentPreview())

    #expect(viewModel.dismissScreenPreview())
    #expect(viewModel.screenPreview == nil)
    #expect(viewModel.searchItems.count == 1)
    #expect(!viewModel.dismissScreenPreview())
}

@Test func agentScreenPreview_allAgentsTilesEachCapture() {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { paneId in "pane \(paneId)" }
    let first = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "a",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let second = TmuxPane(
        paneId: "%2", sessionName: "s", windowIndex: 1, windowName: "b",
        command: "codex", title: "codex", currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(first), .tmuxPane(second)]

    #expect(viewModel.showAllAgentPreviews())
    guard case .tiled(let captures) = viewModel.screenPreview else {
        Issue.record("expected tiled preview")
        return
    }
    #expect(captures.map(\.id) == ["%1", "%2"])
    #expect(captures.map(\.text) == ["pane %1", "pane %2"])
    #expect(captures.map(\.index) == [1, 2])
    #expect(captures.map(\.numberedTitle)[0].hasPrefix("1  "))
    if case .tmuxPane(let pane) = viewModel.previewItem(forDigit: 2) {
        #expect(pane.paneId == "%2")
    } else {
        Issue.record("digit 2 should focus the second tiled agent")
    }
    #expect(viewModel.previewItem(forDigit: 3) == nil)
}

@Test func searchPanel_escapeDismissesPreviewFirst() {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { _ in "screen" }
    let pane = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "claude",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(pane)]
    viewModel.hoveredIndex = 0
    #expect(viewModel.showHoveredAgentPreview())

    let dismissed = viewModel.dismissScreenPreview()
    #expect(dismissed)
    #expect(viewModel.screenPreview == nil)
}

@Test func agentScreenPreview_refreshesShownPanesWhileVisible() async throws {
    let viewModel = SearchViewModel()
    let paneA = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "a",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let paneB = TmuxPane(
        paneId: "%2", sessionName: "s", windowIndex: 1, windowName: "b",
        command: "codex", title: "Codex", currentPath: "/tmp"
    )
    let aiProcess = ProcessProvider.AIProcess(
        pid: 123, command: "claude", workingDirectory: "/tmp",
        terminalBundleId: "com.apple.Terminal", terminalAppName: "Terminal",
        terminalEmoji: "💻", title: "Outside tmux"
    )
    let probe = ScreenPreviewCaptureProbe(texts: ["%1": "pane A v1", "%2": "pane B"])
    viewModel.paneScreenCaptureProvider = { probe.capture($0) }
    viewModel.searchItems = [.tmuxPane(paneA), .tmuxPane(paneB), .aiProcess(aiProcess)]

    #expect(viewModel.showAllAgentPreviews())
    guard case .tiled(let initialCaptures) = viewModel.screenPreview else {
        Issue.record("expected tiled preview")
        return
    }

    let updatedText = "\u{1B}[31mpane A v2\u{1B}[0m"
    probe.update("\(updatedText)\n\n", for: "%1")
    var refreshed = false
    for _ in 0..<40 {
        if case .tiled(let captures) = viewModel.screenPreview,
           captures.first?.text == updatedText {
            refreshed = true
            break
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(refreshed)

    guard case .tiled(let captures) = viewModel.screenPreview else {
        Issue.record("expected tiled preview after refresh")
        return
    }
    guard captures.count == initialCaptures.count else {
        Issue.record("expected the same number of captures after refresh")
        return
    }
    #expect(captures.map(\.id) == ["%1", "%2", "aiprocess-123"])
    #expect(captures.map(\.id) == initialCaptures.map(\.id))
    #expect(captures.map(\.title) == initialCaptures.map(\.title))
    #expect(captures.map(\.index) == initialCaptures.map(\.index))
    #expect(captures[0].text == updatedText)
    #expect(captures[1].text == initialCaptures[1].text)
    #expect(captures[2].text == "tmux ペインがないため画面キャプチャできません")
    #expect(!probe.paneIDs.contains("aiprocess-123"))
}

@Test func agentScreenPreview_stopsRefreshingAfterDeactivate() async throws {
    let viewModel = SearchViewModel()
    let pane = TmuxPane(
        paneId: "%7", sessionName: "s", windowIndex: 0, windowName: "agent",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let probe = ScreenPreviewCaptureProbe(texts: ["%7": "screen"])
    viewModel.paneScreenCaptureProvider = { probe.capture($0) }
    viewModel.searchItems = [.tmuxPane(pane)]
    viewModel.hoveredIndex = 0
    #expect(viewModel.showHoveredAgentPreview())

    let initialCallCount = probe.callCount
    var refreshed = false
    for _ in 0..<40 {
        if probe.callCount > initialCallCount {
            refreshed = true
            break
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(refreshed)

    viewModel.deactivatePanel()
    let stoppedCallCount = probe.callCount
    try await Task.sleep(nanoseconds: 1_200_000_000)

    #expect(viewModel.screenPreview == nil)
    #expect(probe.callCount == stoppedCallCount)
}
