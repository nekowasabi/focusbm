import Foundation
import Testing
@testable import FocusBMLib

// MARK: - AppleScript Escape Tests

@Test func test_escapeForAppleScript_quotes() {
    let input = #"He said "hello""#
    let result = AppleScriptBridge.escapeForAppleScript(input)
    #expect(result == #"He said \"hello\""#)
}

@Test func test_escapeForAppleScript_backslash() {
    let input = #"path\to\file"#
    let result = AppleScriptBridge.escapeForAppleScript(input)
    #expect(result == #"path\\to\\file"#)
}

@Test func test_escapeForAppleScript_mixed() {
    let input = #"say \"hi\""#
    let result = AppleScriptBridge.escapeForAppleScript(input)
    #expect(result == #"say \\\"hi\\\""#)
}

@Test func test_escapeForAppleScript_noSpecialChars() {
    let input = "https://github.com/pulls"
    let result = AppleScriptBridge.escapeForAppleScript(input)
    #expect(result == "https://github.com/pulls")
}

// MARK: - Tab URL Parsing Tests

@Test func test_parseTabURLOutput_singleWindow() {
    let output = "https://a.example/\thttps://b.example/"
    let result = AppleScriptBridge.parseTabURLOutput(output)
    #expect(result == [["https://a.example/", "https://b.example/"]])
}

@Test func test_parseTabURLOutput_multiWindow_keepsTrailingTab() {
    // 中間行は末尾タブ付き（最終行のみ run() の trim で末尾タブが落ちる）
    let output = "https://a.example/\thttps://b.example/\t\nhttps://c.example/"
    let result = AppleScriptBridge.parseTabURLOutput(output)
    #expect(result == [["https://a.example/", "https://b.example/"], ["https://c.example/"]])
}

@Test func test_parseTabURLOutput_emptyWindowKeepsIndexAlignment() {
    let output = "\nhttps://c.example/"
    let result = AppleScriptBridge.parseTabURLOutput(output)
    #expect(result == [[], ["https://c.example/"]])
}

@Test func test_parseTabURLOutput_empty() {
    #expect(AppleScriptBridge.parseTabURLOutput("") == [])
}

@Test func test_findTab_prefixMatchReturnsOneBasedIndices() {
    let tabs = [
        ["https://x.example/", "https://app.slack.com/client/T035/C08"],
        ["https://app.slack.com/client/T0APA/inbox"],
    ]
    let loc = AppleScriptBridge.findTab(in: tabs) { $0.hasPrefix("https://app.slack.com/client/T0APA") }
    #expect(loc?.window == 2)
    #expect(loc?.tab == 1)
}

@Test func test_findTab_noMatch() {
    let loc = AppleScriptBridge.findTab(in: [["https://a.example/"]]) { $0.hasPrefix("https://z.example") }
    #expect(loc == nil)
}

// MARK: - Timeout Tests

@Test func test_run_timesOutAndKillsProcess() {
    let start = Date()
    #expect(throws: AppleScriptError.self) {
        _ = try AppleScriptBridge.run("delay 30", timeout: 1.0)
    }
    // タイムアウト（1s）+ SIGTERM 猶予（最大1s）内で返ること
    #expect(Date().timeIntervalSince(start) < 5.0)
}

// MARK: - iTerm2 Neovim Send Script Tests

@Test func test_iTermNvimScriptTargetsExactTTY() throws {
    let script = try AppleScriptBridge.makeITermNvimSendScript(tty: "/dev/ttys005", exCommand: "echo 'hi'")
    #expect(script.contains("com.googlecode.iterm2"))
    #expect(script.contains("/dev/ttys005"))
    #expect(script.contains("ASCII character 27"))
    #expect(script.contains("without newline"))
    #expect(script.contains(#"write text ":" & "echo 'hi'""#))

    let windowSelect = script.range(of: "select targetWindow")
    let tabSelect = script.range(of: "select targetTab")
    let sessionSelect = script.range(of: "select targetSession")
    #expect(windowSelect != nil)
    #expect(tabSelect != nil)
    #expect(sessionSelect != nil)
    if let windowSelect, let tabSelect, let sessionSelect {
        #expect(windowSelect.lowerBound < tabSelect.lowerBound)
        #expect(tabSelect.lowerBound < sessionSelect.lowerBound)
    }
}

@Test func test_iTermNvimScriptRejectsAmbiguousTTY() throws {
    #expect(throws: ITermNvimScriptError.emptyTTY) {
        _ = try AppleScriptBridge.makeITermNvimSendScript(tty: "", exCommand: "echo 'hi'")
    }

    let script = try AppleScriptBridge.makeITermNvimSendScript(tty: "/dev/ttys005", exCommand: "echo 'hi'")
    let uniquenessGuard = script.range(of: "matchCount is not 1")
    let firstWrite = script.range(of: "write text")
    #expect(uniquenessGuard != nil)
    #expect(firstWrite != nil)
    if let uniquenessGuard, let firstWrite {
        #expect(uniquenessGuard.lowerBound < firstWrite.lowerBound)
    }
}

@Test func test_iTermNvimScriptEscapesExCommand() throws {
    let exCommand = #"echo "hi\there""#
    let script = try AppleScriptBridge.makeITermNvimSendScript(tty: "/dev/ttys005", exCommand: exCommand)
    let escaped = AppleScriptBridge.escapeForAppleScript(exCommand)
    #expect(script.contains(escaped))
    #expect(script.contains(#"write text ":" & "\#(escaped)""#))

    var executeCount = 0
    var seenTimeout: TimeInterval?
    try AppleScriptBridge.sendExCommandToITerm2(
        tty: "/dev/ttys005",
        exCommand: exCommand,
        execute: { _, timeout in
            executeCount += 1
            seenTimeout = timeout
            return ""
        }
    )
    #expect(executeCount == 1)
    #expect(seenTimeout == 5.0)

    executeCount = 0
    #expect(throws: ITermNvimScriptError.emptyTTY) {
        try AppleScriptBridge.sendExCommandToITerm2(tty: "", exCommand: "echo 'hi'") { _, _ in
            executeCount += 1
            return ""
        }
    }
    #expect(executeCount == 0)
}
