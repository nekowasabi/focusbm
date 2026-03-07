import Testing
import AppKit
@testable import FocusBMLib

// MARK: - TmuxPane.isAIAgent Tests

@Test func test_isAIAgent_claudeCommand() {
    let pane = TmuxPane(paneId: "%1", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "claude", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_claudeCodeInTitle() {
    let pane = TmuxPane(paneId: "%2", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "node", title: "Claude Code", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_claudeCodeInTitlePartial() {
    let pane = TmuxPane(paneId: "%3", sessionName: "main", windowIndex: 1,
                        windowName: "code", command: "node", title: "Claude Code - my-project", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_aiderCommand() {
    let pane = TmuxPane(paneId: "%4", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "aider", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_aiderInTitle() {
    let pane = TmuxPane(paneId: "%5", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "python", title: "Aider Session", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_geminiCommand() {
    let pane = TmuxPane(paneId: "%6", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "gemini", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_geminiInTitle() {
    let pane = TmuxPane(paneId: "%7", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "node", title: "Gemini CLI", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_nonAICommand() {
    let pane = TmuxPane(paneId: "%8", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "vim", title: "README.md", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_bashCommand() {
    let pane = TmuxPane(paneId: "%9", sessionName: "main", windowIndex: 0,
                        windowName: "shell", command: "zsh", title: "", currentPath: "/home/user")
    #expect(pane.isAIAgent == false)
}

// MARK: - TmuxPane.displayName Tests

@Test func test_displayName_withTitle() {
    let pane = TmuxPane(paneId: "%1", sessionName: "work", windowIndex: 2,
                        windowName: "dev", command: "claude", title: "Claude Code", currentPath: "/tmp")
    #expect(pane.displayName == "❓ ○ Claude Code — tmp")
}

@Test func test_displayName_withoutTitle() {
    let pane = TmuxPane(paneId: "%1", sessionName: "work", windowIndex: 0,
                        windowName: "main", command: "claude", title: "", currentPath: "/tmp")
    #expect(pane.displayName == "❓ ○ Claude Code — tmp")
}

@Test func test_displayName_format() {
    let pane = TmuxPane(paneId: "%5", sessionName: "mySession", windowIndex: 3,
                        windowName: "editor", command: "aider", title: "Aider", currentPath: "/projects")
    #expect(pane.displayName == "❓ ○ Aider — projects")
}

@Test func test_displayName_emptyPath() {
    let pane = TmuxPane(paneId: "%6", sessionName: "work", windowIndex: 0,
                        windowName: "main", command: "zsh", title: "", currentPath: "")
    #expect(pane.displayName == "❓ ○ zsh")
}

// MARK: - TmuxProvider.parseOutput Tests

@Test func test_parseOutput_singlePane() throws {
    let output = "%1||main||0||editor||claude||Claude Code||/home/user/project"
    let panes = try TmuxProvider.parseOutput(output)
    #expect(panes.count == 1)
    let pane = panes[0]
    #expect(pane.paneId == "%1")
    #expect(pane.sessionName == "main")
    #expect(pane.windowIndex == 0)
    #expect(pane.windowName == "editor")
    #expect(pane.command == "claude")
    #expect(pane.title == "Claude Code")
    #expect(pane.currentPath == "/home/user/project")
}

@Test func test_parseOutput_multiplePanes() throws {
    let output = """
    %1||session1||0||window1||claude||Claude Code||/tmp
    %2||session1||1||window2||vim||README.md||/home/user
    %3||session2||0||main||zsh||||/home/user
    """
    let panes = try TmuxProvider.parseOutput(output)
    #expect(panes.count == 3)
    #expect(panes[0].paneId == "%1")
    #expect(panes[1].command == "vim")
    #expect(panes[2].sessionName == "session2")
}

@Test func test_parseOutput_emptyTitle() throws {
    let output = "%10||main||0||shell||zsh||||/home/user"
    let panes = try TmuxProvider.parseOutput(output)
    #expect(panes.count == 1)
    #expect(panes[0].title == "")
}

@Test func test_parseOutput_emptyString() throws {
    let panes = try TmuxProvider.parseOutput("")
    #expect(panes.count == 0)
}

@Test func test_parseOutput_windowIndexParsed() throws {
    let output = "%1||main||5||mywindow||bash||title||/path"
    let panes = try TmuxProvider.parseOutput(output)
    #expect(panes[0].windowIndex == 5)
}

@Test func test_parseOutput_invalidLineThrwsError() {
    let output = "incomplete||data"
    #expect(throws: TmuxError.self) {
        try TmuxProvider.parseOutput(output)
    }
}

@Test func test_parseOutput_aiAgentFilterable() throws {
    let output = """
    %1||main||0||editor||claude||Claude Code||/tmp
    %2||main||1||shell||zsh||||/tmp
    %3||main||2||ai||aider||Aider||/tmp
    """
    let panes = try TmuxProvider.parseOutput(output)
    let aiPanes = panes.filter { $0.isAIAgent }
    #expect(aiPanes.count == 2)
    #expect(aiPanes[0].command == "claude")
    #expect(aiPanes[1].command == "aider")
}

// MARK: - TmuxProvider.terminalAppInfo Tests

@Test func test_terminalAppInfo_iTerm() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "iTerm.app")
    #expect(bundleId == "com.googlecode.iterm2")
    #expect(appName == "iTerm2")
}

@Test func test_terminalAppInfo_appleTerminal() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "Apple_Terminal")
    #expect(bundleId == "com.apple.Terminal")
    #expect(appName == "Terminal")
}

@Test func test_terminalAppInfo_unknownUsesITermFallback() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "kitty")
    #expect(bundleId == nil)
    #expect(appName == "iTerm2")
}

@Test func test_terminalAppInfo_emptyUsesITermFallback() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "")
    #expect(bundleId == nil)
    #expect(appName == "iTerm2")
}

@Test func test_terminalAppInfo_wezterm() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "WezTerm")
    #expect(bundleId == "com.github.wez.wezterm")
    #expect(appName == "WezTerm")
}

// MARK: - TmuxPane.agentStatus Tests

@Test func test_agentStatus_brailleFirst_running() {
    // U+2800 (⠀) は Braille 範囲の先頭
    let pane = TmuxPane(paneId: "%1", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "\u{2800}loading", currentPath: "")
    #expect(pane.agentStatus == .running)
    #expect(pane.statusEmoji == "●")
}

@Test func test_agentStatus_brailleEnd_running() {
    // U+28FF は Braille 範囲の末尾
    let pane = TmuxPane(paneId: "%2", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "\u{28FF}done", currentPath: "")
    #expect(pane.agentStatus == .running)
}

@Test func test_agentStatus_planMode() {
    let pane = TmuxPane(paneId: "%3", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "⏸ waiting for approval", currentPath: "")
    #expect(pane.agentStatus == .planMode)
    #expect(pane.statusEmoji == "⏸")
}

@Test func test_agentStatus_acceptEdits() {
    let pane = TmuxPane(paneId: "%4", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "⏵ reviewing edits", currentPath: "")
    #expect(pane.agentStatus == .acceptEdits)
    #expect(pane.statusEmoji == "⏵")
}

@Test func test_agentStatus_idle_regularTitle() {
    let pane = TmuxPane(paneId: "%5", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "Claude Code", currentPath: "")
    #expect(pane.agentStatus == .idle)
    #expect(pane.statusEmoji == "○")
}

@Test func test_agentStatus_idle_emptyTitle() {
    let pane = TmuxPane(paneId: "%6", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "zsh", title: "", currentPath: "")
    #expect(pane.agentStatus == .idle)
}

// MARK: - TmuxPane.agentName Tests

@Test func test_agentName_claude() {
    let pane = TmuxPane(paneId: "%1", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "claude", title: "", currentPath: "")
    #expect(pane.agentName == "Claude Code")
}

@Test func test_agentName_aider() {
    let pane = TmuxPane(paneId: "%2", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "aider", title: "", currentPath: "")
    #expect(pane.agentName == "Aider")
}

@Test func test_agentName_gemini() {
    let pane = TmuxPane(paneId: "%3", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "gemini", title: "", currentPath: "")
    #expect(pane.agentName == "Gemini")
}

@Test func test_agentName_unknown_returnsCommand() {
    let pane = TmuxPane(paneId: "%4", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "zsh", title: "", currentPath: "")
    #expect(pane.agentName == "zsh")
}

// MARK: - TmuxProvider.terminalBundleIdToEmoji Tests

@Test func test_terminalBundleIdToEmoji_ghostty() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.mitchellh.ghostty") == "👻")
}

@Test func test_terminalBundleIdToEmoji_iterm2() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.googlecode.iterm2") == "🍎")
}

@Test func test_terminalBundleIdToEmoji_appleTerminal() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.apple.Terminal") == "🖥️")
}

@Test func test_terminalBundleIdToEmoji_wezterm() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.github.wez.wezterm") == "⚡")
}

@Test func test_terminalBundleIdToEmoji_alacritty() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("org.alacritty") == "🔲")
}

@Test func test_terminalBundleIdToEmoji_unknown() {
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.unknown.app") == "❓")
}

@Test func test_terminalBundleIdToEmoji_nil() {
    #expect(TmuxProvider.terminalBundleIdToEmoji(nil) == "❓")
}

// MARK: - Codex終了後のゴースト検出防止テスト

@Test func test_isAIAgent_codexRunning_nodeCommand() {
    let pane = TmuxPane(paneId: "%10", sessionName: "main", windowIndex: 0,
                        windowName: "codex", command: "node", title: "codex cli", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_codexExited_shellCommand_zsh() {
    let pane = TmuxPane(paneId: "%11", sessionName: "main", windowIndex: 0,
                        windowName: "codex", command: "zsh", title: "codex cli", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_codexExited_shellCommand_bash() {
    let pane = TmuxPane(paneId: "%12", sessionName: "main", windowIndex: 0,
                        windowName: "codex", command: "bash", title: "codex cli", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_codexExited_shellCommand_fish() {
    let pane = TmuxPane(paneId: "%13", sessionName: "main", windowIndex: 0,
                        windowName: "codex", command: "fish", title: "codex cli", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_claudeCodeExited_shellCommand() {
    let pane = TmuxPane(paneId: "%14", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "zsh", title: "Claude Code - project", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_aiderExited_shellCommand() {
    let pane = TmuxPane(paneId: "%15", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "bash", title: "aider session", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

// MARK: - MockRunningApp

final class MockRunningApp: RunningAppProtocol {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?
    init(pid: pid_t, bundleId: String?, name: String?) {
        self.processIdentifier = pid
        self.bundleIdentifier = bundleId
        self.localizedName = name
    }
}

// MARK: - TmuxProvider.findTerminalByAncestorProcess Tests

@Test func test_findTerminalByAncestorProcess_findsGhostty() {
    // pid 100 → 200 → 500(Ghostty)
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 500, bundleId: "com.mitchellh.ghostty", name: "Ghostty")
    ]
    let result = TmuxProvider.findTerminalByAncestorProcess(
        100, runningApps: mockApps,
        getParentPID: { pid in
            switch pid { case 100: return 200; case 200: return 500; default: return nil }
        }
    )
    #expect(result?.bundleId == "com.mitchellh.ghostty")
    #expect(result?.appName == "Ghostty")
}

@Test func test_findTerminalByAncestorProcess_findsITerm2() {
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 300, bundleId: "com.googlecode.iterm2", name: "iTerm2")
    ]
    let result = TmuxProvider.findTerminalByAncestorProcess(
        100, runningApps: mockApps,
        getParentPID: { pid in
            switch pid { case 100: return 300; default: return nil }
        }
    )
    #expect(result?.bundleId == "com.googlecode.iterm2")
}

@Test func test_findTerminalByAncestorProcess_findsWezTerm() {
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 400, bundleId: "com.github.wez.wezterm", name: "WezTerm")
    ]
    let result = TmuxProvider.findTerminalByAncestorProcess(
        100, runningApps: mockApps,
        getParentPID: { pid in
            switch pid { case 100: return 200; case 200: return 400; default: return nil }
        }
    )
    #expect(result?.bundleId == "com.github.wez.wezterm")
}

@Test func test_findTerminalByAncestorProcess_notFound() {
    // 既知ターミナルがプロセスツリーにない場合 nil
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 999, bundleId: "com.unknown.app", name: "Unknown")
    ]
    let result = TmuxProvider.findTerminalByAncestorProcess(
        100, runningApps: mockApps,
        getParentPID: { pid in
            switch pid { case 100: return 200; default: return nil }
        }
    )
    #expect(result == nil)
}

@Test func test_findTerminalByAncestorProcess_directMatch() {
    // startPid 自体がターミナルアプリの場合
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 100, bundleId: "com.apple.Terminal", name: "Terminal")
    ]
    let result = TmuxProvider.findTerminalByAncestorProcess(
        100, runningApps: mockApps,
        getParentPID: { _ in nil }
    )
    #expect(result?.bundleId == "com.apple.Terminal")
}

@Test func test_findTerminalByAncestorProcess_maxDepthExceeded() {
    // 10回以上深いプロセスツリー → 見つからない
    let mockApps: [any RunningAppProtocol] = [
        MockRunningApp(pid: 999, bundleId: "com.mitchellh.ghostty", name: "Ghostty")
    ]
    var counter = 0
    let result = TmuxProvider.findTerminalByAncestorProcess(
        1, runningApps: mockApps,
        getParentPID: { _ in counter += 1; return Int32(counter + 1) }
    )
    #expect(result == nil)
}

// MARK: - TmuxPane Terminal Info Fields Tests

@Test func test_tmuxPane_terminalBundleId_defaultNil() {
    let pane = TmuxPane(
        paneId: "%1", sessionName: "main", windowIndex: 0,
        windowName: "editor", command: "claude",
        title: "Claude Code", currentPath: "/tmp"
    )
    #expect(pane.terminalBundleId == nil)
    #expect(pane.terminalAppName == nil)
}

@Test func test_tmuxPane_terminalInfo_canBeSet() {
    var pane = TmuxPane(
        paneId: "%1", sessionName: "main", windowIndex: 0,
        windowName: "editor", command: "claude",
        title: "Claude Code", currentPath: "/tmp"
    )
    pane.terminalBundleId = "com.mitchellh.ghostty"
    pane.terminalAppName = "Ghostty"
    #expect(pane.terminalBundleId == "com.mitchellh.ghostty")
    #expect(pane.terminalAppName == "Ghostty")
}

// MARK: - TmuxPane.clientTTY Tests

@Test func test_tmuxPane_clientTTY_defaultNil() {
    let pane = TmuxPane(
        paneId: "%1", sessionName: "main", windowIndex: 0,
        windowName: "editor", command: "claude",
        title: "Claude Code", currentPath: "/tmp"
    )
    #expect(pane.clientTTY == nil)
}

@Test func test_tmuxPane_clientTTY_canBeSet() {
    var pane = TmuxPane(
        paneId: "%1", sessionName: "main", windowIndex: 0,
        windowName: "editor", command: "claude",
        title: "Claude Code", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys005"
    #expect(pane.clientTTY == "/dev/ttys005")
}

// MARK: - TmuxProvider.parseClientMapOutput Tests

@Test func test_parseClientMapOutput_singleClient() {
    let output = "/dev/ttys005||main||12345"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 1)
    #expect(map["main"]?.tty == "/dev/ttys005")
}

@Test func test_parseClientMapOutput_multipleClients() {
    let output = """
    /dev/ttys005||session1||12345
    /dev/ttys008||session2||67890
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 2)
    #expect(map["session1"]?.tty == "/dev/ttys005")
    #expect(map["session2"]?.tty == "/dev/ttys008")
}

@Test func test_parseClientMapOutput_duplicateSession_firstWins() {
    let output = """
    /dev/ttys005||main||12345
    /dev/ttys008||main||67890
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 1)
    #expect(map["main"]?.tty == "/dev/ttys005")
}

@Test func test_parseClientMapOutput_emptyOutput() {
    let map = TmuxProvider.parseClientMapOutput("")
    #expect(map.isEmpty)
}

@Test func test_parseClientMapOutput_malformedLine_skipped() {
    let output = """
    /dev/ttys005||main||12345
    incomplete
    /dev/ttys008||work||67890
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 2)
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map["work"]?.tty == "/dev/ttys008")
}

@Test func test_parseClientMapOutput_emptyTTY_skipped() {
    let output = "||main||12345"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.isEmpty)
}

@Test func test_parseClientMapOutput_emptySession_skipped() {
    let output = "/dev/ttys005||||12345"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.isEmpty)
}

// MARK: - TmuxProvider.selectWindowArgs Tests

@Test func test_selectWindowArgs_basic() {
    let pane = TmuxPane(
        paneId: "%1", sessionName: "mySession", windowIndex: 2,
        windowName: "editor", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let args = TmuxProvider.selectWindowArgs(pane)
    #expect(args == ["tmux", "select-window", "-t", "mySession:2"])
}

@Test func test_selectWindowArgs_ignoresClientTTY() {
    // select-window は -c フラグを持たない（TTY指定不要）
    var pane = TmuxPane(
        paneId: "%1", sessionName: "work", windowIndex: 3,
        windowName: "main", command: "aider", title: "", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys005"
    let args = TmuxProvider.selectWindowArgs(pane)
    #expect(args == ["tmux", "select-window", "-t", "work:3"])
    #expect(!args.contains("-c"))
}

@Test func test_selectWindowArgs_targetFormat() {
    let pane = TmuxPane(
        paneId: "%5", sessionName: "dev", windowIndex: 0,
        windowName: "ai", command: "gemini", title: "", currentPath: "/tmp"
    )
    let args = TmuxProvider.selectWindowArgs(pane)
    guard let tIdx = args.firstIndex(of: "-t"), tIdx + 1 < args.count else {
        Issue.record("-t flag not found in args")
        return
    }
    #expect(args[tIdx + 1] == "dev:0")
}

// MARK: - TmuxProvider.focusPaneArgs Tests

@Test func test_focusPaneArgs_withClientTTY() {
    // clientTTY がある場合: switch-client -c tty -t session:windowIndex
    var pane = TmuxPane(
        paneId: "%1", sessionName: "mySession", windowIndex: 2,
        windowName: "editor", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys005"
    let args = TmuxProvider.focusPaneArgs(pane)
    #expect(args == ["tmux", "switch-client", "-c", "/dev/ttys005", "-t", "mySession:2"])
}

@Test func test_focusPaneArgs_withoutClientTTY() {
    // clientTTY がない場合: switch-client -t session:windowIndex のみ
    let pane = TmuxPane(
        paneId: "%1", sessionName: "work", windowIndex: 0,
        windowName: "main", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    // clientTTY は nil（デフォルト）
    let args = TmuxProvider.focusPaneArgs(pane)
    #expect(args == ["tmux", "switch-client", "-t", "work:0"])
}

@Test func test_focusPaneArgs_targetFormat() {
    // -t の値が "sessionName:windowIndex" 形式であることを確認
    var pane = TmuxPane(
        paneId: "%5", sessionName: "dev", windowIndex: 3,
        windowName: "ai", command: "aider", title: "", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys010"
    let args = TmuxProvider.focusPaneArgs(pane)
    // -t の値を検証
    guard let tIdx = args.firstIndex(of: "-t"), tIdx + 1 < args.count else {
        Issue.record("-t flag not found in args")
        return
    }
    #expect(args[tIdx + 1] == "dev:3")
}

@Test func test_focusPaneArgs_cFlagPrecedesTarget() {
    // -c は -t より前に来る必要がある
    var pane = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0,
        windowName: "w", command: "claude", title: "", currentPath: ""
    )
    pane.clientTTY = "/dev/ttys001"
    let args = TmuxProvider.focusPaneArgs(pane)
    guard let cIdx = args.firstIndex(of: "-c"),
          let tIdx = args.firstIndex(of: "-t") else {
        Issue.record("-c or -t flag not found")
        return
    }
    #expect(cIdx < tIdx)
}

// MARK: - TmuxProvider.selectPaneArgs Tests

@Test func test_selectPaneArgs_basic() {
    let pane = TmuxPane(
        paneId: "%3", sessionName: "mySession", windowIndex: 1,
        windowName: "editor", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let args = TmuxProvider.selectPaneArgs(pane)
    #expect(args == ["tmux", "select-pane", "-t", "%3"])
}

@Test func test_selectPaneArgs_usesPaneId() {
    // select-pane は paneId を使う（sessionName や windowIndex は使わない）
    var pane = TmuxPane(
        paneId: "%42", sessionName: "work", windowIndex: 5,
        windowName: "main", command: "aider", title: "", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys005"
    let args = TmuxProvider.selectPaneArgs(pane)
    #expect(args == ["tmux", "select-pane", "-t", "%42"])
    #expect(!args.contains("work"))
    #expect(!args.contains("5"))
}

// MARK: - focusPane attached/detached 分岐テスト（args レベル）

@Test func test_focusPane_attached_doesNotUseSwitchClient() {
    // attached セッション（clientTTY あり）では focusPaneArgs（switch-client）を呼ばないことを
    // コマンド引数レベルで検証するために selectWindowArgs / selectPaneArgs の組み合わせを確認する
    var pane = TmuxPane(
        paneId: "%10", sessionName: "attached-session", windowIndex: 2,
        windowName: "editor", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys007"

    // attached の場合に使われるコマンド群
    let windowArgs = TmuxProvider.selectWindowArgs(pane)
    let paneArgs   = TmuxProvider.selectPaneArgs(pane)

    // select-window は -t session:windowIndex
    #expect(windowArgs == ["tmux", "select-window", "-t", "attached-session:2"])
    // select-pane は -t paneId
    #expect(paneArgs == ["tmux", "select-pane", "-t", "%10"])
    // switch-client を含まない
    #expect(!windowArgs.contains("switch-client"))
    #expect(!paneArgs.contains("switch-client"))
}

@Test func test_focusPane_detached_usesSwitchClient() {
    // detached セッション（clientTTY nil）では switch-client が必要
    let pane = TmuxPane(
        paneId: "%20", sessionName: "detached-session", windowIndex: 0,
        windowName: "main", command: "gemini", title: "", currentPath: "/tmp"
    )
    // clientTTY は nil（detached）

    let switchArgs = TmuxProvider.focusPaneArgs(pane)
    let windowArgs = TmuxProvider.selectWindowArgs(pane)
    let paneArgs   = TmuxProvider.selectPaneArgs(pane)

    // switch-client は clientTTY なしなので -c を含まない
    #expect(switchArgs == ["tmux", "switch-client", "-t", "detached-session:0"])
    #expect(windowArgs == ["tmux", "select-window", "-t", "detached-session:0"])
    #expect(paneArgs   == ["tmux", "select-pane",   "-t", "%20"])
}

@Test func test_focusPane_attached_clientTTY_determines_attached() {
    // clientTTY が nil でない = attached として扱う
    var pane = TmuxPane(
        paneId: "%5", sessionName: "s", windowIndex: 1,
        windowName: "w", command: "claude", title: "", currentPath: ""
    )
    #expect(pane.clientTTY == nil)  // デフォルトは detached

    pane.clientTTY = "/dev/ttys001"
    #expect(pane.clientTTY != nil)  // tty をセットすると attached
}

@Test func test_focusPane_detached_switchClientIncludesWindowIndex() {
    // detached の switch-client の -t は "session:windowIndex" 形式であること
    let pane = TmuxPane(
        paneId: "%7", sessionName: "proj", windowIndex: 3,
        windowName: "w", command: "aider", title: "", currentPath: ""
    )
    let args = TmuxProvider.focusPaneArgs(pane)
    guard let tIdx = args.firstIndex(of: "-t"), tIdx + 1 < args.count else {
        Issue.record("-t not found in switch-client args")
        return
    }
    #expect(args[tIdx + 1] == "proj:3")
}

// MARK: - iTerm2 tmux統合モード / バージョンバイナリ対応テスト

// バージョン番号バイナリ + タイトルに "Claude Code" が含まれる場合、agentName は "Claude Code" を返す
@Test func test_agentName_versionBinaryWithClaudeTitle() {
    let pane = TmuxPane(paneId: "%1", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "2.1.58",
                        title: "⚡ Claude Code — myproject", currentPath: "/tmp")
    #expect(pane.agentName == "Claude Code")
}

// isAIAgent: command="2.1.58", title に "Claude Code" が含まれる場合 → true
@Test func test_isAIAgent_versionBinaryClaudeCode() {
    let pane = TmuxPane(paneId: "%1", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "2.1.58",
                        title: "⚡ Claude Code — myproject", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

// findTerminalByAncestorProcess: iTermServer プロセス名を持つPIDを検出する
@Test func test_findTerminalByAncestorProcess_iTermServer() {
    // iTermServer はGUIアプリでないため runningApps に含まれない
    // getParentPID が iTermServer の PID を返した場合でも bundleId が解決されること
    // ここでは sysctl は呼べないため、結果が nil になることを確認する（実機テストで検証）
    let emptyApps: [any RunningAppProtocol] = []
    let result = TmuxProvider.findTerminalByAncestorProcess(
        99999,  // 存在しないPID
        runningApps: emptyApps,
        getParentPID: { _ in nil }
    )
    // 存在しないPIDなので nil が返る（実際の iTermServer PIDでは iTerm2 が返る）
    #expect(result == nil)
}
