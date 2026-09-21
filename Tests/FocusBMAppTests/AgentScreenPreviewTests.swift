import Testing
@testable import FocusBMApp
@testable import FocusBMLib

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
