import Testing
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

@Test func test_terminalAppInfo_weztermUsesITermFallback() {
    let (bundleId, appName) = TmuxProvider.terminalAppInfo(termProgram: "WezTerm")
    #expect(bundleId == nil)
    #expect(appName == "iTerm2")
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
    #expect(TmuxProvider.terminalBundleIdToEmoji("com.apple.Terminal") == "🍎")
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
