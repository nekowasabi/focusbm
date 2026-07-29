import AppKit
import Testing
@testable import FocusBMApp
@testable import FocusBMLib

@Test func sessionPullRequestShortcut_matchesConfiguredModifiers() {
    let keyCode = UInt16(AppDelegate.keyCodeForCharacter("p"))

    #expect(SearchPanel.matchesSessionPullRequestHotkey(
        keyCode: keyCode,
        flags: [.command],
        hotkey: "cmd+p"
    ))
    #expect(SearchPanel.matchesSessionPullRequestHotkey(
        keyCode: keyCode,
        flags: [.command, .shift],
        hotkey: "cmd+shift+p"
    ))
    #expect(!SearchPanel.matchesSessionPullRequestHotkey(
        keyCode: keyCode,
        flags: [.shift],
        hotkey: "cmd+shift+p"
    ))
    #expect(!SearchPanel.matchesSessionPullRequestHotkey(
        keyCode: keyCode,
        flags: [.command, .control],
        hotkey: "cmd+p"
    ))
}

@Test func sessionPullRequestShortcut_doesNotMatchDifferentKey() {
    let keyCode = UInt16(AppDelegate.keyCodeForCharacter("q"))
    #expect(!SearchPanel.matchesSessionPullRequestHotkey(
        keyCode: keyCode,
        flags: [.command],
        hotkey: "cmd+p"
    ))
}

@Test func sessionPullRequestAction_closesAndOpensOnce() {
    var closeCount = 0
    var openedURLs: [URL] = []
    let url = URL(string: "https://github.com/acme/focusbm/pull/42")!

    SearchPanel.performSessionPullRequestAction(
        url: url,
        close: { closeCount += 1 },
        openURL: { openedURLs.append($0); return true }
    )

    #expect(closeCount == 1)
    #expect(openedURLs == [url])
}

    
@Test func sessionPullRequestShortcut_resolvesTmuxClaudeFromWorkingDirectory() {
    var requestedDirectory: String?
    let resolver = ClaudeSessionPullRequestResolver(
        homeDirectory: FileManager.default.temporaryDirectory,
        fileManager: .default,
        pullRequestURLProvider: { directory in
            requestedDirectory = directory
            return "https://github.com/acme/focusbm/pull/953"
        }
    )
    let viewModel = SearchViewModel()
    viewModel.sessionPullRequestResolver = SessionPullRequestResolver(resolvers: [resolver])
    let pane = TmuxPane(
        paneId: "%25",
        sessionName: "invase-app",
        windowIndex: 3,
        windowName: "tmp",
        command: "claude",
        title: "Claude Code",
        currentPath: "/tmp"
    )

    let item = SearchItem.tmuxPane(pane)
    #expect(viewModel.canResolveSessionPullRequest(for: item))
    #expect(viewModel.sessionPullRequestURL(for: item)?.absoluteString == "https://github.com/acme/focusbm/pull/953")
    #expect(requestedDirectory == "/tmp")
}
