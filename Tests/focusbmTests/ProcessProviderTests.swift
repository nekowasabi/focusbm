import Testing
import AppKit
@testable import FocusBMLib

// MARK: - ProcessProvider.AIProcess 初期化テスト

@Test func test_aiProcess_init() {
    let proc = ProcessProvider.AIProcess(
        pid: 12345,
        command: "claude",
        workingDirectory: "/Users/user/project",
        terminalBundleId: "com.googlecode.iterm2",
        terminalAppName: "iTerm2",
        terminalEmoji: "🍎",
        title: "claude (pid: 12345)"
    )
    #expect(proc.pid == 12345)
    #expect(proc.command == "claude")
    #expect(proc.workingDirectory == "/Users/user/project")
    #expect(proc.terminalBundleId == "com.googlecode.iterm2")
    #expect(proc.terminalAppName == "iTerm2")
    #expect(proc.terminalEmoji == "🍎")
    #expect(proc.title == "claude (pid: 12345)")
}

@Test func test_aiProcess_init_nilTerminal() {
    let proc = ProcessProvider.AIProcess(
        pid: 99,
        command: "aider",
        workingDirectory: "~",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "❓",
        title: "aider (pid: 99)"
    )
    #expect(proc.terminalBundleId == nil)
    #expect(proc.terminalAppName == nil)
    #expect(proc.terminalEmoji == "❓")
}

// MARK: - findProcessesByName テスト（存在しないコマンド）

@Test func test_findProcessesByName_unknownCommand_returnsEmpty() {
    // 存在しないコマンド名を検索 → 空配列が返るはず
    let pids = ProcessProvider.findProcessesByName("__focusbm_nonexistent_command__")
    #expect(pids.isEmpty)
}

// MARK: - getTTYForProcess テスト（存在しないPID）

@Test func test_getTTYForProcess_invalidPid_returnsNil() {
    // 存在しないPIDでは nil が返るはず
    let tty = ProcessProvider.getTTYForProcess(99999999)
    #expect(tty == nil)
}

// MARK: - getWorkingDirectory テスト（存在しないPID）

@Test func test_getWorkingDirectory_invalidPid_doesNotCrash() {
    // macOS の lsof は存在しないPIDに対して nil または "/"  を返す実装依存の挙動がある。
    // クラッシュしないこと、および返値が nil か有効なパス文字列であることを確認する。
    let cwd = ProcessProvider.getWorkingDirectory(99999999)
    if let path = cwd {
        #expect(!path.isEmpty)
    }
    // nil の場合も合格（クラッシュなし）
}

// MARK: - isProcessInTmux テスト（存在しないPID）

@Test func test_isProcessInTmux_invalidPid_returnsFalse() {
    // 存在しないPIDはtmux内とは判定されない
    let result = ProcessProvider.isProcessInTmux(99999999)
    #expect(result == false)
}

// MARK: - SearchItem.aiProcess テスト

@Test func test_searchItem_aiProcess_id() {
    let proc = ProcessProvider.AIProcess(
        pid: 42,
        command: "claude",
        workingDirectory: "/home/user",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "❓",
        title: "claude (pid: 42)"
    )
    let item = SearchItem.aiProcess(proc)
    #expect(item.id == "aiprocess-42")
}

@Test func test_searchItem_aiProcess_displayName() {
    let proc = ProcessProvider.AIProcess(
        pid: 1,
        command: "claude",
        workingDirectory: "/Users/user/myproject",
        terminalBundleId: "com.googlecode.iterm2",
        terminalAppName: "iTerm2",
        terminalEmoji: "🍎",
        title: "claude (pid: 1)"
    )
    let item = SearchItem.aiProcess(proc)
    // displayName は "🍎 claude — myproject" の形式
    #expect(item.displayName == "🍎 claude — myproject")
}

@Test func test_searchItem_aiProcess_context() {
    let proc = ProcessProvider.AIProcess(
        pid: 1,
        command: "claude",
        workingDirectory: "/tmp",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "❓",
        title: "claude (pid: 1)"
    )
    let item = SearchItem.aiProcess(proc)
    #expect(item.context == "process")
}

@Test func test_searchItem_aiProcess_urlPattern_isNil() {
    let proc = ProcessProvider.AIProcess(
        pid: 1,
        command: "claude",
        workingDirectory: "/tmp",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "❓",
        title: "claude (pid: 1)"
    )
    let item = SearchItem.aiProcess(proc)
    #expect(item.urlPattern == nil)
}

@Test func test_searchItem_aiProcess_appName_withTerminal() {
    let proc = ProcessProvider.AIProcess(
        pid: 1,
        command: "aider",
        workingDirectory: "/tmp",
        terminalBundleId: "com.mitchellh.ghostty",
        terminalAppName: "Ghostty",
        terminalEmoji: "👻",
        title: "aider (pid: 1)"
    )
    let item = SearchItem.aiProcess(proc)
    #expect(item.appName == "Ghostty")
}

@Test func test_searchItem_aiProcess_appName_fallsBackToCommand() {
    let proc = ProcessProvider.AIProcess(
        pid: 1,
        command: "gemini",
        workingDirectory: "/tmp",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "❓",
        title: "gemini (pid: 1)"
    )
    let item = SearchItem.aiProcess(proc)
    #expect(item.appName == "gemini")
}

// MARK: - aiAgentCommands 検証

@Test func test_aiAgentCommands_containsExpected() {
    let commands = ProcessProvider.aiAgentCommands
    #expect(commands.contains("claude"))
    #expect(commands.contains("aider"))
    #expect(commands.contains("gemini"))
    #expect(commands.contains("copilot"))
}
