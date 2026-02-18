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
