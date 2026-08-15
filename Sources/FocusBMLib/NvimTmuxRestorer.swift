import Foundation

public enum NvimTmuxRestoreError: Error, LocalizedError, Equatable {
    case noEligiblePane
    case nonITerm2
    case missingTTY
    case verifyFailed
    case listFailed
    case sendFailed

    public var errorDescription: String? {
        switch self {
        case .noEligiblePane:
            return "No eligible iTerm2 tmux nvim pane"
        case .nonITerm2:
            return "Candidate pane is not iTerm2"
        case .missingTTY:
            return "Candidate pane has no client TTY"
        case .verifyFailed:
            return "tmux pane verification failed"
        case .listFailed:
            return "Failed to list tmux panes"
        case .sendFailed:
            return "Failed to send Ex command to iTerm2"
        }
    }
}

/// Focus orchestrator: list → pick iTerm2 nvim → tmux focus → activate iTerm2.
/// Ex send is optional and never required for a successful focus.
public struct NvimTmuxRestorer {
    public var listPanes: () throws -> [TmuxPane]
    public var findPane: ([TmuxPane], String?) throws -> TmuxPane
    public var switchAndVerify: (TmuxPane) throws -> ITermNvimPaneTarget
    public var sendEx: (String, String) throws -> Void

    private static let sendLock = NSLock()

    public init(
        listPanes: @escaping () throws -> [TmuxPane] = { try TmuxProvider.listAllPanes() },
        findPane: @escaping ([TmuxPane], String?) throws -> TmuxPane = {
            try TmuxProvider.findNvimPaneForFocus(in: $0, workingDirectory: $1)
        },
        switchAndVerify: @escaping (TmuxPane) throws -> ITermNvimPaneTarget = { pane in
            _ = try TmuxProvider.focusPane(pane)
            return ITermNvimPaneTarget(
                paneId: pane.paneId,
                sessionName: pane.sessionName,
                windowIndex: pane.windowIndex,
                currentPath: pane.currentPath,
                clientTTY: pane.clientTTY ?? ""
            )
        },
        sendEx: @escaping (String, String) throws -> Void = { _, _ in }
    ) {
        self.listPanes = listPanes
        self.findPane = findPane
        self.switchAndVerify = switchAndVerify
        self.sendEx = sendEx
    }

    public static let live = NvimTmuxRestorer()

    @discardableResult
    public static func restore(workingDirectory: String?, exCommand: String) throws -> ActivationTarget {
        try live.restore(workingDirectory: workingDirectory, exCommand: exCommand)
    }

    @discardableResult
    public func restore(workingDirectory: String?, exCommand: String) throws -> ActivationTarget {
        Self.sendLock.lock()
        defer { Self.sendLock.unlock() }

        let panes: [TmuxPane]
        do {
            panes = try listPanes()
        } catch let error as NvimTmuxRestoreError {
            throw error
        } catch {
            throw NvimTmuxRestoreError.listFailed
        }

        let pane: TmuxPane
        do {
            pane = try findPane(panes, workingDirectory)
        } catch let error as NvimTmuxRestoreError {
            throw error
        } catch is TmuxInputError {
            throw NvimTmuxRestoreError.noEligiblePane
        } catch {
            throw NvimTmuxRestoreError.noEligiblePane
        }

        guard pane.command == TmuxProvider.NVIM_PANE_COMMAND,
              pane.terminalBundleId == TmuxProvider.ITERM2_BUNDLE_ID else {
            throw NvimTmuxRestoreError.nonITerm2
        }

        do {
            _ = try switchAndVerify(pane)
        } catch let error as NvimTmuxRestoreError {
            throw error
        } catch {
            throw NvimTmuxRestoreError.verifyFailed
        }

        // Focus is the success path. Ex send is best-effort and must not undo focus.
        if !exCommand.isEmpty, let tty = pane.clientTTY, !tty.isEmpty {
            try? sendEx(tty, exCommand)
        }

        return .bundleId(TmuxProvider.ITERM2_BUNDLE_ID, appName: "iTerm2")
    }
}
