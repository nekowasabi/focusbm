import Testing
import AppKit
@testable import FocusBMLib

// MARK: - TmuxPane.isAIAgent Tests

@Test func test_isAIAgent_claudeCommand() {
    let pane = TmuxPane(paneId: "%1", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "claude", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_codexCommandWithNonCodexTitle() {
    let pane = TmuxPane(paneId: "%codex", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "codex", title: "focusbm", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(codex)")
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

@Test func test_isAIAgent_hermesCommand() {
    let pane = TmuxPane(paneId: "%10", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "hermes", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_hermesInTitle() {
    let pane = TmuxPane(paneId: "%11", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "node", title: "Hermes Agent", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_opencodeCommand() {
    let pane = TmuxPane(paneId: "%30", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "opencode", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(opencode)")
}

@Test func test_isAIAgent_piCommand() {
    let pane = TmuxPane(paneId: "%31", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "pi", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(pi)")
}

@Test func test_isAIAgent_opencodeInTitle() {
    let pane = TmuxPane(paneId: "%32", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "nvim", title: "opencode session", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "title_match(opencode)")
}

@Test func test_isAIAgent_piInTitle() {
    let pane = TmuxPane(paneId: "%33", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "nvim", title: "pi", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
}

@Test func test_isAIAgent_opencodeExited_shellCommand() {
    let pane = TmuxPane(paneId: "%34", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "zsh", title: "opencode", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
    #expect(pane.aiAgentReason == "ghost_shell")
}

@Test func test_isAIAgent_piExited_shellCommand() {
    let pane = TmuxPane(paneId: "%35", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "zsh", title: "pi", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
    #expect(pane.aiAgentReason == "ghost_shell")
}

@Test func test_isAIAgent_grokCommand() {
    let pane = TmuxPane(paneId: "%36", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "grok", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(grok)")
}

@Test func test_isAIAgent_grokVersionedCommand() {
    let pane = TmuxPane(paneId: "%37", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "grok-1.0.4-maco", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(grok-1.0.4-maco)")
}

@Test func test_isAIAgent_grokInTitle() {
    let pane = TmuxPane(paneId: "%38", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "nvim", title: "Implement plan - grok", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "title_match(grok)")
}

@Test func test_isAIAgent_grokExited_shellCommand() {
    let pane = TmuxPane(paneId: "%39", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "zsh", title: "Implement plan - grok", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
    #expect(pane.aiAgentReason == "ghost_shell")
}

@Test func test_isAIAgent_devinCommand() {
    let pane = TmuxPane(paneId: "%58", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "devin", title: "", currentPath: "/tmp")
    #expect(pane.isAIAgent == true)
    #expect(pane.aiAgentReason == "command_match(devin)")
}

@Test func test_isAIAgent_devinExited_shellCommand() {
    let pane = TmuxPane(paneId: "%59", sessionName: "main", windowIndex: 0,
                        windowName: "editor", command: "zsh", title: "devin", currentPath: "/tmp")
    #expect(pane.isAIAgent == false)
    #expect(pane.aiAgentReason == "ghost_shell")
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

// MARK: - TmuxPane.displayNameWithoutEmoji Tests

@Test func test_displayNameWithoutEmoji_withTitle() {
    let pane = TmuxPane(paneId: "%1", sessionName: "work", windowIndex: 2,
                        windowName: "dev", command: "claude", title: "Claude Code", currentPath: "/tmp")
    #expect(pane.displayNameWithoutEmoji == "❓ Claude Code — tmp")
}

@Test func test_displayNameWithoutEmoji_withoutTitle() {
    let pane = TmuxPane(paneId: "%1", sessionName: "work", windowIndex: 0,
                        windowName: "main", command: "claude", title: "", currentPath: "/tmp")
    #expect(pane.displayNameWithoutEmoji == "❓ Claude Code — tmp")
}

@Test func test_displayNameWithoutEmoji_emptyPath() {
    let pane = TmuxPane(paneId: "%6", sessionName: "work", windowIndex: 0,
                        windowName: "main", command: "zsh", title: "", currentPath: "")
    #expect(pane.displayNameWithoutEmoji == "❓ zsh")
}

@Test func test_displayNameWithoutEmoji_noStatusEmoji() {
    let pane = TmuxPane(paneId: "%5", sessionName: "mySession", windowIndex: 3,
                        windowName: "editor", command: "aider", title: "Aider", currentPath: "/projects")
    // statusEmoji (○/●) が含まれていないことを確認
    #expect(!pane.displayNameWithoutEmoji.contains("○"))
    #expect(!pane.displayNameWithoutEmoji.contains("●"))
    // 元の displayName には statusEmoji が含まれている
    #expect(pane.displayName.contains("○"))
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

@Test func test_agentStatus_runningMarker_isRecognized_forAllRequestedAgents() {
    for command in ["claude", "codex", "copilot"] {
        let pane = TmuxPane(
            paneId: "%marker-\(command)",
            sessionName: "status",
            windowIndex: 0,
            windowName: "agent",
            command: command,
            title: "✳ \(command)",
            currentPath: "/tmp"
        )
        #expect(pane.agentStatus == .running)
    }
}

@Test func test_agentStatus_prompt_isInputWaiting_forAllRequestedAgents() {
    for command in ["claude", "codex", "copilot"] {
        var pane = TmuxPane(
            paneId: "%prompt-\(command)",
            sessionName: "status",
            windowIndex: 0,
            windowName: "agent",
            command: command,
            title: command,
            currentPath: "/tmp"
        )
        pane.statusContent = "previous response\n❯ "
        #expect(pane.agentStatus == .idle)
    }
}

@Test func test_agentStatus_running_takesPriority_overOlderPrompt_forCodex() {
    var pane = TmuxPane(
        paneId: "%codex-working",
        sessionName: "status",
        windowIndex: 0,
        windowName: "agent",
        command: "codex",
        title: "codex",
        currentPath: "/tmp"
    )
    pane.statusContent = "› Previous prompt\n• Working (6s • esc to interrupt)\n› Current task"
    #expect(pane.agentStatus == .running)
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
    #expect(map.count == 2) // main + fallback
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
}

@Test func test_parseClientMapOutput_multipleClients() {
    let output = """
    /dev/ttys005||session1||12345
    /dev/ttys008||session2||67890
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 3) // session1, session2 + fallback
    #expect(map["session1"]?.tty == "/dev/ttys005")
    #expect(map["session2"]?.tty == "/dev/ttys008")
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
}

@Test func test_parseClientMapOutput_windowKeyAndSessionFallback() {
    let output = "/dev/ttys005||main||2||editor||%10||12345"
    let map = TmuxProvider.parseClientMapOutput(output)

    #expect(map["main:2"]?.tty == "/dev/ttys005")
    #expect(map["main:2"]?.windowIndex == 2)
    #expect(map["main:2"]?.windowName == "editor")
    #expect(map["main:2"]?.paneId == "%10")
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map["main:2"]?.activity == 0)
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
    #expect(map.count == 3) // main:2, main, fallback
}

@Test func test_parseClientMapOutput_sameSessionWindowClientWinsBeforeSessionFallback() {
    let output = """
    /dev/ttys005||main||1||shell||%1||11111
    /dev/ttys008||main||2||editor||%2||22222
    """
    let map = TmuxProvider.parseClientMapOutput(output)

    #expect(map["main:1"]?.tty == "/dev/ttys005")
    #expect(map["main:2"]?.tty == "/dev/ttys008")
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map.count == 4) // main:1, main:2, main, fallback
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
}

@Test func test_parseClientMapOutput_duplicateSession_firstWins() {
    let output = """
    /dev/ttys005||main||12345
    /dev/ttys008||main||67890
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map.count == 2) // main, fallback
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
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
    #expect(map.count == 3) // main, work, fallback
    #expect(map["main"]?.tty == "/dev/ttys005")
    #expect(map["work"]?.tty == "/dev/ttys008")
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
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

@Test func test_parseClientMapOutput_activityParsedFromSevenFields() {
    let output = "/dev/ttys005||main||2||editor||%10||12345||1700000000"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map["main:2"]?.activity == 1700000000)
    #expect(map[TmuxProvider.fallbackClientKey]?.activity == 1700000000)
}

@Test func test_parseClientMapOutput_sixFields_activityDefaultsToZero() {
    let output = "/dev/ttys005||main||12345"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map["main"]?.activity == 0)
    #expect(map[TmuxProvider.fallbackClientKey]?.activity == 0)
}

@Test func test_parseClientMapOutput_invalidActivityDefaultsToZero() {
    let output = "/dev/ttys005||main||2||editor||%10||12345||not-a-number"
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map["main:2"]?.activity == 0)
    #expect(map[TmuxProvider.fallbackClientKey]?.activity == 0)
}

@Test func test_parseClientMapOutput_fallbackClientUsesLatestActivity() {
    let output = """
    /dev/ttys005||main||2||editor||%10||12345||1700000001
    /dev/ttys006||work||3||dev||%11||12346||1700001000
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys006")
    #expect(map[TmuxProvider.fallbackClientKey]?.sessionName == "work")
}

@Test func test_parseClientMapOutput_fallbackClientTieKeepsFirst() {
    let output = """
    /dev/ttys005||main||2||editor||%10||12345||1700
    /dev/ttys006||work||3||dev||%11||12346||1700
    """
    let map = TmuxProvider.parseClientMapOutput(output)
    #expect(map[TmuxProvider.fallbackClientKey]?.tty == "/dev/ttys005")
}

@Test func test_resolveClient_usesWindowThenSessionThenFallback() {
    let clientMap: [String: TmuxProvider.TmuxClientInfo] = [
        "main:1": .init(
            tty: "/dev/ttys001",
            sessionName: "main",
            windowIndex: 1,
            windowName: "editor",
            paneId: "%1",
            clientPid: 111,
            bundleId: "com.googlecode.iterm2",
            appName: "iTerm2",
            activity: 10
        ),
        "main": .init(
            tty: "/dev/ttys002",
            sessionName: "main",
            windowIndex: nil,
            windowName: nil,
            paneId: nil,
            clientPid: 112,
            bundleId: "com.apple.Terminal",
            appName: "Terminal",
            activity: 5
        ),
        TmuxProvider.fallbackClientKey: .init(
            tty: "/dev/ttys009",
            sessionName: "other",
            windowIndex: nil,
            windowName: nil,
            paneId: nil,
            clientPid: 113,
            bundleId: "com.mitchellh.ghostty",
            appName: "Ghostty",
            activity: 1
        )
    ]

    #expect(TmuxProvider.resolveClient(sessionName: "main", windowIndex: 1, clientMap: clientMap)?.tty == "/dev/ttys001")
    #expect(TmuxProvider.resolveClient(sessionName: "main", windowIndex: 9, clientMap: clientMap)?.tty == "/dev/ttys002")
    #expect(TmuxProvider.resolveClient(sessionName: "work", windowIndex: 1, clientMap: clientMap)?.tty == "/dev/ttys009")
}

@Test func test_detectTerminalApp_prefersClientMapBeforePreferredTerminal() {
    let clientMap: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: .init(
            tty: "/dev/ttys001",
            sessionName: "main",
            windowIndex: nil,
            windowName: nil,
            paneId: nil,
            clientPid: 1,
            bundleId: "com.googlecode.iterm2",
            appName: "iTerm2",
            activity: 1
        )
    ]
    let pane = TmuxPane(
        paneId: "%7", sessionName: "main", windowIndex: 3,
        windowName: "shell", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    let settings = AppSettings(preferredTerminal: "com.apple.Terminal")
    let result = TmuxProvider.detectTerminalApp(for: pane, settings: settings, clientMap: clientMap)
    #expect(result?.bundleId == "com.googlecode.iterm2")
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

@Test func test_focusPane_attached_switchClientWithClientTTYIsReachable() {
    var pane = TmuxPane(
        paneId: "%10", sessionName: "attached-session", windowIndex: 2,
        windowName: "editor", command: "claude", title: "Claude Code", currentPath: "/tmp"
    )
    pane.clientTTY = "/dev/ttys007"

    let switchArgs = TmuxProvider.focusPaneArgs(pane)
    let windowArgs = TmuxProvider.selectWindowArgs(pane)
    let paneArgs   = TmuxProvider.selectPaneArgs(pane)

    #expect(switchArgs == ["tmux", "switch-client", "-c", "/dev/ttys007", "-t", "attached-session:2"])
    #expect(windowArgs == ["tmux", "select-window", "-t", "attached-session:2"])
    #expect(paneArgs == ["tmux", "select-pane", "-t", "%10"])
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

// MARK: - TmuxProvider.selectWindowArgs 追加テスト

@Test func test_selectWindowArgs_windowIndexZero() {
    // windowIndex=0 の境界値
    let pane = TmuxPane(
        paneId: "%1", sessionName: "main", windowIndex: 0,
        windowName: "shell", command: "zsh", title: "", currentPath: "/tmp"
    )
    let args = TmuxProvider.selectWindowArgs(pane)
    #expect(args == ["tmux", "select-window", "-t", "main:0"])
}

@Test func test_selectWindowArgs_startsWithTmux() {
    // コマンドの先頭が "tmux" であることを確認
    let pane = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 1,
        windowName: "w", command: "claude", title: "", currentPath: ""
    )
    let args = TmuxProvider.selectWindowArgs(pane)
    #expect(args.first == "tmux")
    #expect(args.contains("select-window"))
}

@Test func test_selectWindowArgs_largeWindowIndex() {
    // 大きな windowIndex でも正しくフォーマットされる
    let pane = TmuxPane(
        paneId: "%99", sessionName: "longSessionName", windowIndex: 99,
        windowName: "w", command: "aider", title: "", currentPath: ""
    )
    let args = TmuxProvider.selectWindowArgs(pane)
    #expect(args == ["tmux", "select-window", "-t", "longSessionName:99"])
}

// MARK: - TmuxProvider.selectPaneArgs 追加テスト

@Test func test_selectPaneArgs_startsWithTmux() {
    // コマンドの先頭が "tmux" であることを確認
    let pane = TmuxPane(
        paneId: "%1", sessionName: "s", windowIndex: 0,
        windowName: "w", command: "claude", title: "", currentPath: ""
    )
    let args = TmuxProvider.selectPaneArgs(pane)
    #expect(args.first == "tmux")
    #expect(args.contains("select-pane"))
}

@Test func test_selectPaneArgs_paneIdStartsWithPercent() {
    // paneId は "%" で始まる tmux 形式
    let pane = TmuxPane(
        paneId: "%7", sessionName: "main", windowIndex: 0,
        windowName: "editor", command: "claude", title: "", currentPath: "/tmp"
    )
    let args = TmuxProvider.selectPaneArgs(pane)
    guard let tIdx = args.firstIndex(of: "-t"), tIdx + 1 < args.count else {
        Issue.record("-t flag not found in selectPaneArgs")
        return
    }
    #expect(args[tIdx + 1].hasPrefix("%"))
}

@Test func test_selectPaneArgs_doesNotContainSessionName() {
    // select-pane は sessionName を含まない（paneId のみ使用）
    let pane = TmuxPane(
        paneId: "%10", sessionName: "uniqueSessionXYZ", windowIndex: 4,
        windowName: "main", command: "gemini", title: "", currentPath: ""
    )
    let args = TmuxProvider.selectPaneArgs(pane)
    #expect(!args.contains("uniqueSessionXYZ"))
    #expect(!args.contains("4"))
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

// MARK: - TmuxProvider.agentCommandToEmoji Tests

@Test func test_agentCommandToEmoji_copilot() {
    #expect(TmuxProvider.agentCommandToEmoji("copilot") == "✈️")
}

@Test func test_agentCommandToEmoji_codex() {
    #expect(TmuxProvider.agentCommandToEmoji("codex") == "📖")
}

@Test func test_agentCommandToEmoji_claude() {
    #expect(TmuxProvider.agentCommandToEmoji("claude") == "🤖")
}

@Test func test_agentCommandToEmoji_aider() {
    #expect(TmuxProvider.agentCommandToEmoji("aider") == "🤖")
}

@Test func test_agentCommandToEmoji_hermes() {
    #expect(TmuxProvider.agentCommandToEmoji("hermes") == "📨")
}

@Test func test_agentCommandToEmoji_unknown() {
    #expect(TmuxProvider.agentCommandToEmoji("unknown") == "🤖")
}

// MARK: - Node.js AI Tool Detection Tests

@Test func test_isAIAgent_nodeCommand_withResolvedCodex() {
    var pane = TmuxPane(paneId: "%20", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "tmux-ai-agents-status", currentPath: "/tmp")
    pane.resolvedNodeCommand = "codex"
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_nodeCommand_withResolvedCopilot() {
    var pane = TmuxPane(paneId: "%21", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "copilot"
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_nodeCommand_withResolvedHermes() {
    var pane = TmuxPane(paneId: "%27", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "hermes"
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_nodeCommand_noResolved_noTitle_notAI() {
    var pane = TmuxPane(paneId: "%22", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "my-web-app", currentPath: "/tmp")
    pane.resolvedNodeCommand = nil
    #expect(pane.isAIAgent == false)
}

@Test func test_agentName_nodeCommand_resolvedCodex() {
    var pane = TmuxPane(paneId: "%23", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "codex"
    #expect(pane.agentName == "Codex")
}

@Test func test_agentName_nodeCommand_resolvedCopilot() {
    var pane = TmuxPane(paneId: "%24", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "copilot"
    #expect(pane.agentName == "Copilot")
}

@Test func test_agentName_hermesCommand() {
    let pane = TmuxPane(paneId: "%28", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "hermes", title: "", currentPath: "")
    #expect(pane.agentName == "Hermes")
}

@Test func test_agentName_nodeCommand_resolvedHermes() {
    var pane = TmuxPane(paneId: "%29", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "hermes"
    #expect(pane.agentName == "Hermes")
}

@Test func test_agentName_opencodeCommand() {
    let pane = TmuxPane(paneId: "%40", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "opencode", title: "", currentPath: "/tmp")
    #expect(pane.agentName == "OpenCode")
}

@Test func test_agentName_piCommand() {
    let pane = TmuxPane(paneId: "%41", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "pi", title: "", currentPath: "/tmp")
    #expect(pane.agentName == "Pi")
}

@Test func test_agentName_nodeCommand_resolvedOpencode() {
    var pane = TmuxPane(paneId: "%42", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "opencode"
    #expect(pane.agentName == "OpenCode")
}

@Test func test_agentName_nodeCommand_resolvedPi() {
    var pane = TmuxPane(paneId: "%43", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "pi"
    #expect(pane.agentName == "Pi")
}

@Test func test_agentCommandToEmoji_opencode() {
    #expect(TmuxProvider.agentCommandToEmoji("opencode") == "🤖")
}

@Test func test_agentCommandToEmoji_pi() {
    #expect(TmuxProvider.agentCommandToEmoji("pi") == "🤖")
}

@Test func test_isAIAgent_nodeCommand_withResolvedOpencode() {
    var pane = TmuxPane(paneId: "%44", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "opencode"
    #expect(pane.isAIAgent == true)
}

@Test func test_isAIAgent_nodeCommand_withResolvedPi() {
    var pane = TmuxPane(paneId: "%45", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "pi"
    #expect(pane.isAIAgent == true)
}

@Test func test_matchNodeAgentCommand_binOpencode() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "/opt/homebrew/bin/opencode --help") == "opencode")
}

@Test func test_matchNodeAgentCommand_binPi() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "/opt/homebrew/bin/pi --help") == "pi")
}

@Test func test_matchNodeAgentCommand_piCodingAgentMarker() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "node /usr/lib/node_modules/pi-coding-agent/cli.js") == "pi")
}

@Test func test_matchNodeAgentCommand_earendilMarker() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "node /usr/lib/node_modules/@earendil-works/cli.js") == "pi")
}

@Test func test_matchNodeAgentCommand_mariozechnerMarker() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "node /usr/lib/node_modules/@mariozechner/cli.js") == "pi")
}

@Test func test_matchNodeAgentCommand_slashPiAloneDoesNotResolve() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "/foo/pi args") == nil)
}

@Test func test_agentName_grokCommand() {
    let pane = TmuxPane(paneId: "%52", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "grok", title: "", currentPath: "/tmp")
    #expect(pane.agentName == "Grok Build")
}

@Test func test_agentName_grokVersionedCommand() {
    let pane = TmuxPane(paneId: "%53", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "grok-1.0.4-maco", title: "", currentPath: "/tmp")
    #expect(pane.agentName == "Grok Build")
}

@Test func test_agentName_nodeCommand_resolvedGrok() {
    var pane = TmuxPane(paneId: "%54", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "grok"
    #expect(pane.agentName == "Grok Build")
}

@Test func test_agentName_devinCommand() {
    let pane = TmuxPane(paneId: "%60", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "devin", title: "", currentPath: "/tmp")
    #expect(pane.agentName == "Devin CLI")
}

@Test func test_agentName_nodeCommand_resolvedDevin() {
    var pane = TmuxPane(paneId: "%61", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    pane.resolvedNodeCommand = "devin"
    #expect(pane.agentName == "Devin CLI")
}

@Test func test_agentCommandToEmoji_grok() {
    #expect(TmuxProvider.agentCommandToEmoji("grok") == "🔫")
}

@Test func test_agentCommandToEmoji_grokVersioned() {
    #expect(TmuxProvider.agentCommandToEmoji("grok-1.0.4-maco") == "🔫")
}

@Test func test_agentCommandToEmoji_devin() {
    #expect(TmuxProvider.agentCommandToEmoji("devin") == "☕")
}

@Test func test_isAIAgent_nodeCommand_withResolvedGrok() {
    var pane = TmuxPane(paneId: "%55", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "node",
                        title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "grok"
    #expect(pane.isAIAgent == true)
}

@Test func test_matchNodeAgentCommand_binGrok() {
    #expect(TmuxProvider.matchNodeAgentCommand(in: "/opt/homebrew/bin/grok --help") == "grok")
}

@Test func test_matchNodeAgentCommand_versionedGrokBinary() {
    #expect(TmuxProvider.matchNodeAgentCommand(
        in: "/opt/homebrew/Caskroom/grok-build/1.0.4/grok-1.0.4-macos-aarch64"
    ) == "grok")
}

@Test func test_panePid_defaultNil() {
    let pane = TmuxPane(paneId: "%25", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "zsh", title: "", currentPath: "")
    #expect(pane.panePid == nil)
}

@Test func test_resolvedNodeCommand_defaultNil() {
    let pane = TmuxPane(paneId: "%26", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "")
    #expect(pane.resolvedNodeCommand == nil)
}

// MARK: - Input-only iTerm2/nvim selection

private func makeInputNvimPane(
    paneId: String,
    sessionName: String = "main",
    windowIndex: Int = 0,
    windowName: String = "editor",
    command: String = "nvim",
    currentPath: String,
    bundleId: String? = TmuxProvider.ITERM2_BUNDLE_ID,
    clientTTY: String? = "/dev/ttys005"
) -> TmuxPane {
    var pane = TmuxPane(
        paneId: paneId,
        sessionName: sessionName,
        windowIndex: windowIndex,
        windowName: windowName,
        command: command,
        title: "nvim",
        currentPath: currentPath
    )
    pane.terminalBundleId = bundleId
    pane.clientTTY = clientTTY
    return pane
}

private func makeClientInfo(
    tty: String,
    sessionName: String,
    windowIndex: Int? = nil,
    windowName: String? = nil,
    paneId: String? = nil,
    activity: Int = 0
) -> TmuxProvider.TmuxClientInfo {
    TmuxProvider.TmuxClientInfo(
        tty: tty,
        sessionName: sessionName,
        windowIndex: windowIndex,
        windowName: windowName,
        paneId: paneId,
        clientPid: 111,
        bundleId: TmuxProvider.ITERM2_BUNDLE_ID,
        appName: "iTerm2",
        activity: activity
    )
}

@Test func test_findNvimPane_returnsFirstInTmuxEnumerationOrder() throws {
    let workdir = "/Users/me/project"
    let earlierEligible = makeInputNvimPane(
        paneId: "%1",
        sessionName: "zzz",
        windowIndex: 9,
        currentPath: workdir,
        clientTTY: "/dev/ttys001"
    )
    let laterEligible = makeInputNvimPane(
        paneId: "%2",
        sessionName: "main",
        windowIndex: 0,
        currentPath: workdir,
        clientTTY: "/dev/ttys009"
    )

    let found = try TmuxProvider.findNvimPane(
        in: [earlierEligible, laterEligible],
        workingDirectory: workdir
    )
    #expect(found.paneId == "%1")
    #expect(found.sessionName == "zzz")
    #expect(found.clientTTY == "/dev/ttys001")
}

@Test func test_findNvimPaneForFocus_prefersExactPathThenAnyITermNvim() throws {
    let workdir = "/Users/me/project"
    let ghosttyNvim = makeInputNvimPane(
        paneId: "%g",
        currentPath: workdir,
        bundleId: "com.mitchellh.ghostty"
    )
    let otherITerm = makeInputNvimPane(
        paneId: "%2",
        sessionName: "iterm",
        windowIndex: 1,
        currentPath: "/Users/me/other",
        clientTTY: "/dev/ttys002"
    )
    let exact = makeInputNvimPane(
        paneId: "%1",
        currentPath: workdir,
        clientTTY: "/dev/ttys001"
    )

    let preferred = try TmuxProvider.findNvimPaneForFocus(
        in: [ghosttyNvim, otherITerm, exact],
        workingDirectory: workdir
    )
    #expect(preferred.paneId == "%1")

    let fallback = try TmuxProvider.findNvimPaneForFocus(
        in: [ghosttyNvim, otherITerm],
        workingDirectory: workdir
    )
    #expect(fallback.paneId == "%2")

    #expect(throws: TmuxInputError.noEligiblePane) {
        try TmuxProvider.findNvimPaneForFocus(in: [ghosttyNvim], workingDirectory: workdir)
    }

    let anyITerm = try TmuxProvider.findNvimPaneForFocus(
        in: [ghosttyNvim, otherITerm],
        workingDirectory: nil
    )
    #expect(anyITerm.paneId == "%2")
}

@Test func test_findNvimPane_rejectsUnsafeCandidates() {
    let workdir = "/Users/me/project"

    let unsafe: [(String, TmuxPane)] = [
        ("vim command", makeInputNvimPane(paneId: "%v", command: "vim", currentPath: workdir)),
        ("nvim with trailing space", makeInputNvimPane(paneId: "%sp", command: "nvim ", currentPath: workdir)),
        ("non-iTerm2 bundle", makeInputNvimPane(paneId: "%g", currentPath: workdir, bundleId: "com.mitchellh.ghostty")),
        ("empty TTY", makeInputNvimPane(paneId: "%e", currentPath: workdir, clientTTY: "")),
        ("nil TTY", makeInputNvimPane(paneId: "%n", currentPath: workdir, clientTTY: nil)),
        ("trailing-slash path", makeInputNvimPane(paneId: "%sl", currentPath: workdir + "/")),
        ("relative path", makeInputNvimPane(paneId: "%rel", currentPath: "Users/me/project")),
    ]

    for (reason, pane) in unsafe {
        #expect(throws: TmuxInputError.noEligiblePane, "\(reason)") {
            try TmuxProvider.findNvimPane(in: [pane], workingDirectory: workdir)
        }
    }

    #expect(throws: TmuxInputError.noEligiblePane) {
        try TmuxProvider.findNvimPane(in: unsafe.map(\.1), workingDirectory: workdir)
    }

    #expect(throws: TmuxInputError.noEligiblePane) {
        try TmuxProvider.findNvimPane(in: [], workingDirectory: workdir)
    }
}

@Test func test_focusPaneForInput_verifiesPaneId() throws {
    let pane = makeInputNvimPane(
        paneId: "%1",
        sessionName: "main",
        windowIndex: 2,
        currentPath: "/Users/me/project",
        clientTTY: "/dev/ttys005"
    )
    let clientMap: [String: TmuxProvider.TmuxClientInfo] = [
        "main:2": makeClientInfo(
            tty: "/dev/ttys005",
            sessionName: "main",
            windowIndex: 2,
            windowName: "editor",
            paneId: "%1"
        )
    ]

    var calls: [[String]] = []
    let target = try TmuxProvider.focusPaneForInput(pane, clientMap: clientMap) { args in
        calls.append(args)
        if args.contains("switch-client") {
            return ""
        }
        return "%1\n"
    }

    #expect(calls == [
        ["tmux", "switch-client", "-c", "/dev/ttys005", "-t", "%1"],
        ["tmux", "display-message", "-p", "-c", "/dev/ttys005", "#{pane_id}"],
    ])
    #expect(target == ITermNvimPaneTarget(
        paneId: "%1",
        sessionName: "main",
        windowIndex: 2,
        currentPath: "/Users/me/project",
        clientTTY: "/dev/ttys005"
    ))
    #expect(TmuxProvider.switchClientForInputArgs(tty: "/dev/ttys005", paneId: "%1") == calls[0])
    #expect(TmuxProvider.verifyActivePaneArgs(tty: "/dev/ttys005") == calls[1])

    #expect(throws: TmuxInputError.paneVerificationFailed(expected: "%1", actual: "%99")) {
        try TmuxProvider.focusPaneForInput(pane, clientMap: clientMap) { args in
            if args.contains("switch-client") { return "" }
            return "  %99\n"
        }
    }

    var verifyCalledAfterSwitchFailure = false
    #expect(throws: TmuxInputError.executionFailed("switch failed")) {
        try TmuxProvider.focusPaneForInput(pane, clientMap: clientMap) { args in
            if args.contains("display-message") {
                verifyCalledAfterSwitchFailure = true
                return "%1"
            }
            throw TmuxInputError.executionFailed("switch failed")
        }
    }
    #expect(verifyCalledAfterSwitchFailure == false)

    let emptyTTYMap: [String: TmuxProvider.TmuxClientInfo] = [
        "main:2": makeClientInfo(tty: "", sessionName: "main", windowIndex: 2)
    ]
    #expect(throws: TmuxInputError.missingClientTTY) {
        try TmuxProvider.focusPaneForInput(pane, clientMap: emptyTTYMap) { _ in
            Issue.record("runTmux must not run without a client TTY")
            return ""
        }
    }

    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: makeClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            activity: 99
        )
    ]
    #expect(throws: TmuxInputError.noStrictClient) {
        try TmuxProvider.resolveClientForInput(
            sessionName: "main",
            windowIndex: 2,
            clientMap: fallbackOnly
        )
    }
}

@Test func test_resolveClientForInput_windowOrSessionOnly() throws {
    let windowClient = makeClientInfo(
        tty: "/dev/ttys001",
        sessionName: "main",
        windowIndex: 1,
        windowName: "editor",
        paneId: "%1",
        activity: 10
    )
    let sessionClient = makeClientInfo(
        tty: "/dev/ttys002",
        sessionName: "main",
        activity: 5
    )
    let fallbackClient = makeClientInfo(
        tty: "/dev/ttys009",
        sessionName: "other",
        activity: 1
    )

    let fullMap: [String: TmuxProvider.TmuxClientInfo] = [
        "main:1": windowClient,
        "main": sessionClient,
        TmuxProvider.fallbackClientKey: fallbackClient,
    ]
    #expect(try TmuxProvider.resolveClientForInput(
        sessionName: "main",
        windowIndex: 1,
        clientMap: fullMap
    ).tty == "/dev/ttys001")

    let sessionOnly: [String: TmuxProvider.TmuxClientInfo] = [
        "main": sessionClient,
        TmuxProvider.fallbackClientKey: fallbackClient,
    ]
    #expect(try TmuxProvider.resolveClientForInput(
        sessionName: "main",
        windowIndex: 9,
        clientMap: sessionOnly
    ).tty == "/dev/ttys002")

    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: fallbackClient,
    ]
    #expect(throws: TmuxInputError.noStrictClient) {
        try TmuxProvider.resolveClientForInput(
            sessionName: "main",
            windowIndex: 1,
            clientMap: fallbackOnly
        )
    }
}

@Test func test_focusPaneForInput_fallbackOnly_doesNotSwitch() {
    var pane = makeInputNvimPane(
        paneId: "%1",
        sessionName: "detached",
        windowIndex: 0,
        currentPath: "/Users/me/project",
        clientTTY: "/dev/ttys009"
    )
    pane.terminalBundleId = TmuxProvider.ITERM2_BUNDLE_ID

    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: makeClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            activity: 99
        )
    ]

    var switchOrVerifyCount = 0
    #expect(throws: TmuxInputError.noStrictClient) {
        try TmuxProvider.focusPaneForInput(pane, clientMap: fallbackOnly) { _ in
            switchOrVerifyCount += 1
            return ""
        }
    }
    #expect(switchOrVerifyCount == 0)
}

@Test func test_attachClientsForInput_clearsFallbackStampedTTY() {
    let workdir = "/Users/me/project"
    var stamped = makeInputNvimPane(
        paneId: "%1",
        sessionName: "detached",
        windowIndex: 0,
        currentPath: workdir,
        clientTTY: "/dev/ttys009"
    )
    stamped.terminalBundleId = TmuxProvider.ITERM2_BUNDLE_ID

    let fallbackOnly: [String: TmuxProvider.TmuxClientInfo] = [
        TmuxProvider.fallbackClientKey: makeClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            activity: 99
        )
    ]

    let attached = TmuxProvider.attachClientsForInput([stamped], clientMap: fallbackOnly)
    #expect(attached[0].clientTTY == nil)
    #expect(attached[0].terminalBundleId == nil)
    #expect(throws: TmuxInputError.noEligiblePane) {
        try TmuxProvider.findNvimPane(in: attached, workingDirectory: workdir)
    }
}

@Test func test_focusPaneForInput_usesResolvedWindowTTYNotStampedFallback() throws {
    let pane = makeInputNvimPane(
        paneId: "%1",
        sessionName: "main",
        windowIndex: 2,
        currentPath: "/Users/me/project",
        clientTTY: "/dev/ttys009"
    )
    let clientMap: [String: TmuxProvider.TmuxClientInfo] = [
        "main:2": makeClientInfo(
            tty: "/dev/ttys001",
            sessionName: "main",
            windowIndex: 2,
            paneId: "%1"
        ),
        TmuxProvider.fallbackClientKey: makeClientInfo(
            tty: "/dev/ttys009",
            sessionName: "other",
            activity: 99
        ),
    ]

    var seenTTY: String?
    _ = try TmuxProvider.focusPaneForInput(pane, clientMap: clientMap) { args in
        if args.contains("switch-client"), let cIdx = args.firstIndex(of: "-c") {
            seenTTY = args[cIdx + 1]
        }
        if args.contains("display-message") { return "%1" }
        return ""
    }
    #expect(seenTTY == "/dev/ttys001")
}
