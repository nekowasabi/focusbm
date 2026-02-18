import Testing
@testable import FocusBMLib

@Test func test_parseHotkey_cmdCtrlB() {
    let result = HotkeyParser.parse("cmd+ctrl+b")
    #expect(result.modifiers.contains(.command))
    #expect(result.modifiers.contains(.control))
    #expect(result.key == "b")
}

@Test func test_parseHotkey_optShiftSpace() {
    let result = HotkeyParser.parse("opt+shift+space")
    #expect(result.modifiers.contains(.option))
    #expect(result.modifiers.contains(.shift))
    #expect(result.key == "space")
}

@Test func test_parseHotkey_singleKey() {
    let result = HotkeyParser.parse("f12")
    #expect(result.modifiers.isEmpty)
    #expect(result.key == "f12")
}

@Test func test_parseHotkey_cmdSpace() {
    let result = HotkeyParser.parse("cmd+space")
    #expect(result.modifiers.contains(.command))
    #expect(result.key == "space")
}

@Test func test_parseHotkey_caseInsensitive() {
    let result = HotkeyParser.parse("CMD+CTRL+B")
    #expect(result.modifiers.contains(.command))
    #expect(result.modifiers.contains(.control))
    #expect(result.key == "b")
}
