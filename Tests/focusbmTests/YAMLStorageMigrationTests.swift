import Testing
import Yams
@testable import FocusBMLib

// Tests for bookmarkListColumns validation (process-02)
// Valid values: nil, 1, 2. Invalid values must be normalized to nil.

// Helper: minimal YAML with settings section including required hotkey field
private func yamlWithColumns(_ value: Int) -> String {
    """
    settings:
      hotkey:
        togglePanel: "cmd+ctrl+b"
      bookmarkListColumns: \(value)
    bookmarks: []
    """
}

@Test func test_bookmarkListColumns_validValue1_decoded() throws {
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yamlWithColumns(1))
    #expect(store.settings?.bookmarkListColumns == 1)
}

@Test func test_bookmarkListColumns_validValue2_decoded() throws {
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yamlWithColumns(2))
    #expect(store.settings?.bookmarkListColumns == 2)
}

@Test func test_bookmarkListColumns_absent_isNil() throws {
    let yaml = """
    bookmarks: []
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.bookmarkListColumns == nil)
}

@Test func test_bookmarkListColumns_zero_normalizedToNil() throws {
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yamlWithColumns(0))
    // 0 is invalid; must be normalized to nil
    #expect(store.settings?.bookmarkListColumns == nil)
}

@Test func test_bookmarkListColumns_three_normalizedToNil() throws {
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yamlWithColumns(3))
    // 3 is invalid; must be normalized to nil
    #expect(store.settings?.bookmarkListColumns == nil)
}

@Test func test_bookmarkListColumns_negative_normalizedToNil() throws {
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yamlWithColumns(-1))
    // negative is invalid; must be normalized to nil
    #expect(store.settings?.bookmarkListColumns == nil)
}
