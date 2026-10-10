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
        index: 1,
        status: .idle
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
        index: 1,
        status: .idle
    )))
}

private func previewText(capturing screen: String) -> String? {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { _ in screen }
    viewModel.searchItems = [.tmuxPane(TmuxPane(
        paneId: "%2", sessionName: "0", windowIndex: 3, windowName: "claude",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    ))]
    viewModel.hoveredIndex = 0
    _ = viewModel.showHoveredAgentPreview()
    return viewModel.screenPreview?.captures.first?.text
}

@Test(arguments: [
    (
        "claude",
        "● done\n\n✻ Waiting\njev gate: allow 12 / ask 0 / deny 0 · stop: pass   [-]\n\n"
            + "\u{1B}[2m────────\u{1B}[0m\n❯ \n────────\n  repo\n  ⏵⏵ bypass permissions on\n",
        "● done\n\n✻ Waiting"
    ),
    (
        "grok",
        "❯ old prompt\nhi\n\n  ⠴ Waiting for response…\n\n  ╭──────╮\n  │ ❯    │\n  ╰── Grok 4.7 ─╯\n\n  Shift+Tab:mode\n",
        "❯ old prompt\nhi\n\n  ⠴ Waiting for response…"
    ),
    (
        "grok-start",
        "  ⌥ main ~/repos/x\n   ╭────╮\n   │ Grok Build │\n   ╰────╯\n\n   Tip: Use Shift+Tab to cycle modes\n\n"
            + "  ╭──────────╮\n  │ ❯ █      │\n  ╰──── Grok 4.7 (high) · always-approve ──╯\n\n                Grok Build 1.0.50 [stable]\n",
        "  ⌥ main ~/repos/x\n   ╭────╮\n   │ Grok Build │\n   ╰────╯\n\n   Tip: Use Shift+Tab to cycle modes"
    ),
    (
        "codex",
        "› reply hi\n\n• hi\n\n\n\u{1B}[1m›\u{1B}[0m \u{1B}[2mAsk Codex to do anything\u{1B}[0m\n\n  GPT · high\n  ? for shortcuts\n",
        "› reply hi\n\n• hi"
    ),
])
func agentScreenPreview_cutsAtPromptBox(agent: String, screen: String, expected: String) {
    #expect(previewText(capturing: screen) == expected, "\(agent)")
}

@Test func agentScreenPreview_keepsWholeScreenWithoutPromptBox() {
    #expect(previewText(capturing: "Allow?\n\n❯ 1. Yes\n  2. No") == "Allow?\n\n❯ 1. Yes\n  2. No")
    #expect(previewText(capturing: "output\n❯ prompt") == "output\n❯ prompt")
}

@Test func agentScreenPreview_dropsJevGateLinesEvenWithoutPrompt() {
    #expect(previewText(capturing: "output\n[-] jev gate: allow 1\njev gate: allow 2 · stop: pass  [-]") == "output")
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

@Test func agentScreenPreview_capturesCarryAgentStatusAndFollowRefresh() async throws {
    let viewModel = SearchViewModel()
    let working = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "a",
        command: "claude", title: "✻ Working", currentPath: "/tmp"
    )
    let planning = TmuxPane(
        paneId: "%2", sessionName: "s", windowIndex: 1, windowName: "b",
        command: "claude", title: "⏸ plan", currentPath: "/tmp"
    )
    let probe = ScreenPreviewCaptureProbe(texts: ["%1": "a", "%2": "b"])
    viewModel.paneScreenCaptureProvider = { probe.capture($0) }
    viewModel.searchItems = [.tmuxPane(working), .tmuxPane(planning)]

    #expect(viewModel.showAllAgentPreviews())
    #expect(viewModel.screenPreview?.captures.map(\.status) == [.running, .planMode])

    let finished = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "a",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    viewModel.searchItems = [.tmuxPane(finished), .tmuxPane(planning)]
    var refreshed = false
    for _ in 0..<40 {
        if viewModel.screenPreview?.captures.first?.status == .idle {
            refreshed = true
            break
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(refreshed)
    #expect(viewModel.screenPreview?.captures.map(\.status) == [.idle, .planMode])
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

private final class PromptSendProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [(paneID: String, text: String)] = []

    func send(_ paneID: String, _ text: String) {
        lock.lock()
        defer { lock.unlock() }
        sent.append((paneID, text))
    }

    var calls: [(paneID: String, text: String)] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }
}

private func tiledPromptViewModel() -> SearchViewModel {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { "pane \($0)" }
    viewModel.searchItems = [
        .tmuxPane(TmuxPane(paneId: "%1", sessionName: "s", windowIndex: 0, windowName: "a",
                           command: "claude", title: "Claude Code", currentPath: "/tmp")),
        .tmuxPane(TmuxPane(paneId: "%2", sessionName: "s", windowIndex: 1, windowName: "b",
                           command: "codex", title: "codex", currentPath: "/tmp")),
    ]
    return viewModel
}

@Test func agentPrompt_sendsTargetPaneAndBody() async throws {
    let viewModel = SearchViewModel()
    viewModel.paneScreenCaptureProvider = { _ in "screen" }
    viewModel.searchItems = [.tmuxPane(TmuxPane(
        paneId: "%52", sessionName: "0", windowIndex: 1, windowName: "claude",
        command: "claude", title: "Claude Code", currentPath: "/tmp"
    ))]
    viewModel.hoveredIndex = 0
    let probe = PromptSendProbe()
    viewModel.promptSender = { probe.send($0, $1) }
    #expect(viewModel.showHoveredAgentPreview())
    #expect(viewModel.isPromptFieldFocused)

    viewModel.promptDraft = "日本語で修正して; 2行目"
    viewModel.sendPromptToPreview()
    for _ in 0..<40 where probe.calls.isEmpty {
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    #expect(probe.calls.map(\.paneID) == ["%52"])
    #expect(probe.calls.map(\.text) == ["日本語で修正して; 2行目"])
}

@Test func agentPrompt_clearsDraftAfterSend() async throws {
    let viewModel = tiledPromptViewModel()
    let probe = PromptSendProbe()
    viewModel.promptSender = { probe.send($0, $1) }
    #expect(viewModel.showAllAgentPreviews())
    #expect(viewModel.setPromptTarget(2, flags: .command))

    viewModel.promptDraft = "run tests"
    viewModel.sendPromptToPreview()
    for _ in 0..<40 where !viewModel.promptDraft.isEmpty {
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    #expect(viewModel.promptDraft == "")
    #expect(probe.calls.map(\.paneID) == ["%2"])
    #expect(viewModel.promptTargetIndex == 2)
    #expect(viewModel.isPromptFieldFocused)
}

@Test func agentPrompt_cmdDigitRetargetsTiledPromptKeepingDraft() {
    let viewModel = tiledPromptViewModel()
    #expect(viewModel.showAllAgentPreviews())
    #expect(viewModel.promptTargetID == nil)

    #expect(viewModel.setPromptTarget(1, flags: .command))
    viewModel.promptDraft = "half typed"
    #expect(viewModel.promptTargetID == "%1")

    #expect(viewModel.setPromptTarget(2, flags: .command))
    #expect(viewModel.promptTargetID == "%2")
    #expect(viewModel.promptDraft == "half typed")
    #expect(viewModel.isPromptFieldFocused)
    #expect(!viewModel.setPromptTarget(3, flags: .command))
    #expect(viewModel.promptTargetID == "%2")
}

@Test func agentPrompt_ctrlModifierSettingRetargetsWithCtrlOnly() {
    let viewModel = tiledPromptViewModel()
    viewModel.appSettings = AppSettings(previewTargetModifier: .ctrl)
    #expect(viewModel.showAllAgentPreviews())
    #expect(viewModel.setPromptTarget(1, flags: .control))
    #expect(viewModel.promptTargetID == "%1")

    #expect(!viewModel.setPromptTarget(2, flags: .command))
    #expect(viewModel.promptTargetID == "%1")
    #expect(viewModel.setPromptTarget(2, flags: .control))
    #expect(viewModel.promptTargetID == "%2")
}
