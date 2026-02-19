import Testing
import Yams
@testable import FocusBMLib

// MARK: - AppSettings / HotkeySettings モデルテスト

@Test func test_hotkeySettings_defaultValues() {
    let settings = HotkeySettings()
    #expect(settings.togglePanel == "cmd+ctrl+b")
}

@Test func test_appSettings_defaultValues() {
    let settings = AppSettings()
    #expect(settings.hotkey.togglePanel == "cmd+ctrl+b")
}

@Test func test_bookmarkStore_settingsIsOptional() throws {
    // 既存YAML（settingsなし）が読めることを確認
    let yaml = """
    bookmarks:
    - id: test
      appName: Test
      bundleIdPattern: com.test
      context: default
      state:
        type: app
        windowTitle: Test
      createdAt: "2024-01-01T00:00:00Z"
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings == nil)
    #expect(store.bookmarks.count == 1)
}

@Test func test_bookmarkStore_withSettings() throws {
    let yaml = """
    settings:
      hotkey:
        togglePanel: "cmd+shift+space"
    bookmarks:
    - id: test
      appName: Test
      bundleIdPattern: com.test
      context: default
      state:
        type: app
        windowTitle: Test
      createdAt: "2024-01-01T00:00:00Z"
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.hotkey.togglePanel == "cmd+shift+space")
    #expect(store.bookmarks.count == 1)
}

@Test func test_appSettings_yamlRoundTrip() throws {
    var store = BookmarkStore()
    store.settings = AppSettings()
    store.settings?.hotkey.togglePanel = "opt+space"

    let text = try YAMLEncoder().encode(store)
    let decoded = try YAMLDecoder().decode(BookmarkStore.self, from: text)
    #expect(decoded.settings?.hotkey.togglePanel == "opt+space")
}

// MARK: - displayNumber

@Test func test_appSettings_displayNumber_default() {
    let settings = AppSettings()
    #expect(settings.displayNumber == nil)
}

@Test func test_appSettings_displayNumber_fromYAML() throws {
    let yaml = """
    settings:
      hotkey:
        togglePanel: "cmd+ctrl+b"
      displayNumber: 2
    bookmarks: []
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.displayNumber == 2)
}

@Test func test_appSettings_displayNumber_omitted() throws {
    let yaml = """
    settings:
      hotkey:
        togglePanel: "cmd+ctrl+b"
    bookmarks: []
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.displayNumber == nil)
}

@Test func test_appSettings_displayNumber_roundTrip() throws {
    var store = BookmarkStore()
    store.settings = AppSettings()
    store.settings?.displayNumber = 1

    let text = try YAMLEncoder().encode(store)
    let decoded = try YAMLDecoder().decode(BookmarkStore.self, from: text)
    #expect(decoded.settings?.displayNumber == 1)
}

// MARK: - listFontSize

@Test func test_appSettings_listFontSize_default() {
    let settings = AppSettings()
    #expect(settings.listFontSize == nil)
}

@Test func test_appSettings_listFontSize_fromYAML() throws {
    let yaml = """
    settings:
      hotkey:
        togglePanel: "cmd+ctrl+b"
      listFontSize: 15.0
    bookmarks: []
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.listFontSize == 15.0)
}

@Test func test_appSettings_listFontSize_omitted() throws {
    let yaml = """
    settings:
      hotkey:
        togglePanel: "cmd+ctrl+b"
    bookmarks: []
    """
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: yaml)
    #expect(store.settings?.listFontSize == nil)
}

@Test func test_appSettings_listFontSize_roundTrip() throws {
    var store = BookmarkStore()
    store.settings = AppSettings()
    store.settings?.listFontSize = 16.0

    let text = try YAMLEncoder().encode(store)
    let decoded = try YAMLDecoder().decode(BookmarkStore.self, from: text)
    #expect(decoded.settings?.listFontSize == 16.0)
}
