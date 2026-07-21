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
