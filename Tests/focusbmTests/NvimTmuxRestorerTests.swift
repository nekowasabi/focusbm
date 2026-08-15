import Foundation
import Testing
@testable import FocusBMLib

private let workdir = "/Users/me/project"
private let exCommand = "echo hello"
private let frozenTTY = "/dev/ttys005"

private func makeEligiblePane(
    paneId: String = "%1",
    sessionName: String = "main",
    windowIndex: Int = 2,
    command: String = "nvim",
    currentPath: String = workdir,
    bundleId: String? = TmuxProvider.ITERM2_BUNDLE_ID,
    clientTTY: String? = frozenTTY
) -> TmuxPane {
    var pane = TmuxPane(
        paneId: paneId,
        sessionName: sessionName,
        windowIndex: windowIndex,
        windowName: "editor",
        command: command,
        title: "",
        currentPath: currentPath
    )
    pane.terminalBundleId = bundleId
    pane.clientTTY = clientTTY
    return pane
}

private func expectITermActivation(_ target: ActivationTarget) {
    if case .bundleId(let bid, let appName) = target {
        #expect(bid == TmuxProvider.ITERM2_BUNDLE_ID)
        #expect(appName == "iTerm2")
    } else {
        Issue.record("Expected iTerm2 activation")
    }
}

private func makeITermNvimBookmark(
    workingDirectory: String = workdir,
    command: String = exCommand
) -> Bookmark {
    Bookmark(
        id: "nvim",
        appName: "iTerm2",
        bundleIdPattern: TmuxProvider.ITERM2_BUNDLE_ID,
        context: "work",
        state: .iTermNvim(workingDirectory: workingDirectory, exCommand: command),
        createdAt: "2024-01-01T00:00:00Z"
    )
}

private final class RestoreSpy {
    var listCount = 0
    var findCount = 0
    var switchCount = 0
    var sendCount = 0
    var foundPane: TmuxPane?
    var verifiedTarget: ITermNvimPaneTarget?
    var sentTTY: String?
    var sentEx: String?
    var order: [String] = []
}

// MARK: - P04 restore behaviors

@Test func test_restoreUsesFirstEligiblePane() throws {
    let first = makeEligiblePane(paneId: "%1", clientTTY: "/dev/ttys001")
    let second = makeEligiblePane(paneId: "%2", clientTTY: "/dev/ttys009")
    let spy = RestoreSpy()

    let restorer = NvimTmuxRestorer(
        listPanes: {
            spy.listCount += 1
            spy.order.append("list")
            return [first, second]
        },
        findPane: { panes, directory in
            spy.findCount += 1
            spy.order.append("find")
            let pane = try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
            spy.foundPane = pane
            return pane
        },
        switchAndVerify: { pane in
            spy.switchCount += 1
            spy.order.append("switch")
            let target = ITermNvimPaneTarget(
                paneId: pane.paneId,
                sessionName: pane.sessionName,
                windowIndex: pane.windowIndex,
                currentPath: pane.currentPath,
                clientTTY: pane.clientTTY ?? ""
            )
            spy.verifiedTarget = target
            return target
        },
        sendEx: { tty, command in
            spy.sendCount += 1
            spy.order.append("send")
            spy.sentTTY = tty
            spy.sentEx = command
        }
    )

    let target = try BookmarkRestorer.restoreAndGetTarget(
        makeITermNvimBookmark(),
        nvimRestorer: restorer
    )

    expectITermActivation(target)
    #expect(spy.foundPane?.paneId == "%1")
    #expect(spy.verifiedTarget?.paneId == "%1")
    #expect(spy.sentTTY == "/dev/ttys001")
}

@Test func test_restoreVerifiesPaneBeforeSend() throws {
    let pane = makeEligiblePane()
    let spy = RestoreSpy()

    let restorer = NvimTmuxRestorer(
        listPanes: {
            spy.listCount += 1
            spy.order.append("list")
            return [pane]
        },
        findPane: { panes, directory in
            spy.findCount += 1
            spy.order.append("find")
            return try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
        },
        switchAndVerify: { candidate in
            spy.switchCount += 1
            spy.order.append("switch")
            #expect(spy.sendCount == 0)
            return ITermNvimPaneTarget(
                paneId: candidate.paneId,
                sessionName: candidate.sessionName,
                windowIndex: candidate.windowIndex,
                currentPath: candidate.currentPath,
                clientTTY: candidate.clientTTY ?? ""
            )
        },
        sendEx: { _, _ in
            spy.sendCount += 1
            spy.order.append("send")
        }
    )

    _ = try BookmarkRestorer.restoreAndGetTarget(makeITermNvimBookmark(), nvimRestorer: restorer)
    #expect(spy.order == ["list", "find", "switch", "send"])
    #expect(spy.switchCount == 1)
    #expect(spy.sendCount == 1)
}

@Test func test_restoreSendsOnce() throws {
    let pane = makeEligiblePane()
    let spy = RestoreSpy()

    let restorer = NvimTmuxRestorer(
        listPanes: {
            spy.listCount += 1
            spy.order.append("list")
            return [pane]
        },
        findPane: { panes, directory in
            spy.findCount += 1
            spy.order.append("find")
            return try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
        },
        switchAndVerify: { candidate in
            spy.switchCount += 1
            spy.order.append("switch")
            return ITermNvimPaneTarget(
                paneId: candidate.paneId,
                sessionName: candidate.sessionName,
                windowIndex: candidate.windowIndex,
                currentPath: candidate.currentPath,
                clientTTY: frozenTTY
            )
        },
        sendEx: { tty, command in
            spy.sendCount += 1
            spy.order.append("send")
            spy.sentTTY = tty
            spy.sentEx = command
        }
    )

    let target = try BookmarkRestorer.restoreAndGetTarget(
        makeITermNvimBookmark(),
        nvimRestorer: restorer
    )

    expectITermActivation(target)
    #expect(spy.listCount == 1)
    #expect(spy.findCount == 1)
    #expect(spy.switchCount == 1)
    #expect(spy.sendCount == 1)
    #expect(spy.sentTTY == frozenTTY)
    #expect(spy.sentEx == exCommand)
    #expect(spy.order == ["list", "find", "switch", "send"])
}

@Test func test_restoreFailsClosed() throws {
    let pane = makeEligiblePane()
    let secret = "secret-ex-should-not-leak"

    func expectFailClosed(
        _ restorer: NvimTmuxRestorer,
        expected: NvimTmuxRestoreError
    ) {
        var thrown: Error?
        do {
            _ = try BookmarkRestorer.restoreAndGetTarget(
                makeITermNvimBookmark(command: secret),
                nvimRestorer: restorer
            )
        } catch {
            thrown = error
        }
        #expect(thrown as? NvimTmuxRestoreError == expected)
        if let thrown {
            #expect(!String(describing: thrown).contains(secret))
            #expect(!(thrown.localizedDescription).contains(secret))
        }
    }

    var sendCount = 0
    let recordingSend: (String, String) throws -> Void = { _, _ in
        sendCount += 1
    }

    expectFailClosed(
        NvimTmuxRestorer(
            listPanes: { [] },
            findPane: { panes, directory in
                try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
            },
            switchAndVerify: { _ in
                Issue.record("switch must not run without a candidate")
                throw NvimTmuxRestoreError.verifyFailed
            },
            sendEx: recordingSend
        ),
        expected: .noEligiblePane
    )

    expectFailClosed(
        NvimTmuxRestorer(
            listPanes: { [makeEligiblePane(bundleId: "com.mitchellh.ghostty")] },
            findPane: { panes, _ in panes[0] },
            switchAndVerify: { _ in
                Issue.record("switch must not run for non-iTerm2")
                throw NvimTmuxRestoreError.verifyFailed
            },
            sendEx: recordingSend
        ),
        expected: .nonITerm2
    )

    expectFailClosed(
        NvimTmuxRestorer(
            listPanes: { [pane] },
            findPane: { panes, _ in panes[0] },
            switchAndVerify: { _ in
                throw TmuxInputError.paneVerificationFailed(expected: "%1", actual: "%99")
            },
            sendEx: recordingSend
        ),
        expected: .verifyFailed
    )

    let sendTimeoutRestorer = NvimTmuxRestorer(
        listPanes: { [pane] },
        findPane: { panes, _ in panes[0] },
        switchAndVerify: { candidate in
            ITermNvimPaneTarget(
                paneId: candidate.paneId,
                sessionName: candidate.sessionName,
                windowIndex: candidate.windowIndex,
                currentPath: candidate.currentPath,
                clientTTY: frozenTTY
            )
        },
        sendEx: { _, _ in
            throw AppleScriptError.timedOut
        }
    )
    let focused = try BookmarkRestorer.restoreAndGetTarget(
        makeITermNvimBookmark(command: secret),
        nvimRestorer: sendTimeoutRestorer
    )
    expectITermActivation(focused)

    #expect(sendCount == 0)
}

// MARK: - P10 call-order / regression

@Test func test_restoreSuccess_listSwitchVerifySendOnceToFrozenTTY() throws {
    let first = makeEligiblePane(paneId: "%1", clientTTY: frozenTTY)
    let later = makeEligiblePane(paneId: "%9", clientTTY: "/dev/ttys099")
    let spy = RestoreSpy()

    let restorer = NvimTmuxRestorer(
        listPanes: {
            spy.listCount += 1
            spy.order.append("list")
            return [first, later]
        },
        findPane: { panes, directory in
            spy.findCount += 1
            spy.order.append("find")
            return try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
        },
        switchAndVerify: { pane in
            spy.switchCount += 1
            spy.order.append("switch")
            #expect(pane.paneId == "%1")
            #expect(pane.clientTTY == frozenTTY)
            return ITermNvimPaneTarget(
                paneId: pane.paneId,
                sessionName: pane.sessionName,
                windowIndex: pane.windowIndex,
                currentPath: pane.currentPath,
                clientTTY: pane.clientTTY ?? ""
            )
        },
        sendEx: { tty, command in
            spy.sendCount += 1
            spy.order.append("send")
            spy.sentTTY = tty
            spy.sentEx = command
        }
    )

    let result = try BookmarkRestorer.restoreAndGetTarget(
        makeITermNvimBookmark(),
        nvimRestorer: restorer
    )
    expectITermActivation(result)
    #expect(spy.listCount == 1)
    #expect(spy.switchCount == 1)
    #expect(spy.sendCount == 1)
    #expect(spy.sentTTY == frozenTTY)
    #expect(spy.order == ["list", "find", "switch", "send"])
}

@Test func test_restoreFailures_neverSend() throws {
    var sendCount = 0
    let send: (String, String) throws -> Void = { _, _ in sendCount += 1 }

    let cases: [(NvimTmuxRestorer, NvimTmuxRestoreError)] = [
        (
            NvimTmuxRestorer(
                listPanes: { [] },
                findPane: { panes, directory in
                    try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
                },
                switchAndVerify: { _ in throw NvimTmuxRestoreError.verifyFailed },
                sendEx: send
            ),
            .noEligiblePane
        ),
        (
            NvimTmuxRestorer(
                listPanes: { [makeEligiblePane(bundleId: "com.apple.Terminal")] },
                findPane: { panes, _ in panes[0] },
                switchAndVerify: { _ in throw NvimTmuxRestoreError.verifyFailed },
                sendEx: send
            ),
            .nonITerm2
        ),
        (
            NvimTmuxRestorer(
                listPanes: { [makeEligiblePane()] },
                findPane: { panes, _ in panes[0] },
                switchAndVerify: { _ in
                    throw TmuxInputError.paneVerificationFailed(expected: "%1", actual: "%99")
                },
                sendEx: send
            ),
            .verifyFailed
        ),
    ]

    for (restorer, expected) in cases {
        sendCount = 0
        #expect(throws: expected) {
            _ = try BookmarkRestorer.restoreAndGetTarget(
                makeITermNvimBookmark(),
                nvimRestorer: restorer
            )
        }
        #expect(sendCount == 0)
    }
}

@Test func test_restoreFailsClosed_fallbackOnlyClientNeverSends() {
    let workdir = "/Users/me/project"
    let stamped = makeEligiblePane(
        paneId: "%1",
        sessionName: "detached",
        windowIndex: 0,
        currentPath: workdir,
        bundleId: TmuxProvider.ITERM2_BUNDLE_ID,
        clientTTY: "/dev/ttys009"
    )
    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: TmuxProvider.TmuxClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            windowIndex: nil,
            windowName: nil,
            paneId: nil,
            clientPid: 111,
            bundleId: TmuxProvider.ITERM2_BUNDLE_ID,
            appName: "iTerm2",
            activity: 99
        )
    ]

    var switchCount = 0
    var sendCount = 0
    let restorer = NvimTmuxRestorer(
        listPanes: { TmuxProvider.attachClientsForInput([stamped], clientMap: fallbackOnly) },
        findPane: { panes, directory in
            try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
        },
        switchAndVerify: { pane in
            switchCount += 1
            return try TmuxProvider.focusPaneForInput(pane, clientMap: fallbackOnly) { _ in
                Issue.record("tmux switch must not run for fallback-only client")
                return ""
            }
        },
        sendEx: { _, _ in sendCount += 1 }
    )

    #expect(throws: NvimTmuxRestoreError.noEligiblePane) {
        _ = try BookmarkRestorer.restoreAndGetTarget(
            makeITermNvimBookmark(workingDirectory: workdir),
            nvimRestorer: restorer
        )
    }
    #expect(switchCount == 0)
    #expect(sendCount == 0)
}

@Test func test_restoreFailsClosed_focusRejectsFallbackEvenIfListStampedTTY() {
    let stamped = makeEligiblePane(
        paneId: "%1",
        sessionName: "detached",
        windowIndex: 0,
        clientTTY: "/dev/ttys009"
    )
    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: TmuxProvider.TmuxClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            windowIndex: nil,
            windowName: nil,
            paneId: nil,
            clientPid: 111,
            bundleId: TmuxProvider.ITERM2_BUNDLE_ID,
            appName: "iTerm2",
            activity: 99
        )
    ]

    var tmuxInputCount = 0
    var sendCount = 0
    let restorer = NvimTmuxRestorer(
        listPanes: { [stamped] },
        findPane: { panes, directory in
            try TmuxProvider.findNvimPane(in: panes, workingDirectory: directory ?? "")
        },
        switchAndVerify: { pane in
            try TmuxProvider.focusPaneForInput(pane, clientMap: fallbackOnly) { _ in
                tmuxInputCount += 1
                return ""
            }
        },
        sendEx: { _, _ in sendCount += 1 }
    )

    #expect(throws: NvimTmuxRestoreError.verifyFailed) {
        _ = try BookmarkRestorer.restoreAndGetTarget(
            makeITermNvimBookmark(),
            nvimRestorer: restorer
        )
    }
    #expect(tmuxInputCount == 0)
    #expect(sendCount == 0)
}

@Test func test_existingRestorePathsUnchanged() throws {
    let app = Bookmark(
        id: "finder",
        appName: "Finder",
        bundleIdPattern: "com.apple.finder",
        context: "work",
        state: .app(windowTitle: "Documents"),
        createdAt: "2024-01-01T00:00:00Z"
    )
    let floating = Bookmark(
        id: "alter",
        appName: "Alter",
        bundleIdPattern: "",
        context: "tools",
        state: .floatingWindows,
        createdAt: "2024-01-01T00:00:00Z"
    )

    let appTarget = try BookmarkRestorer.restoreAndGetTarget(app)
    if case .bundleId(let bid, let appName) = appTarget {
        #expect(bid == "com.apple.finder")
        #expect(appName == "Finder")
    } else {
        Issue.record("Expected .bundleId for app restore")
    }

    let floatingTarget = try BookmarkRestorer.restoreAndGetTarget(floating)
    if case .none = floatingTarget {} else { Issue.record("Expected .none for floatingWindows") }
}
