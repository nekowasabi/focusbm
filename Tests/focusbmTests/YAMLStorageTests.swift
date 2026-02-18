import Testing
import Yams
@testable import FocusBMLib

private func makeStore() -> BookmarkStore {
    var store = BookmarkStore()
    store.bookmarks = [
        Bookmark(id: "work-terminal", appName: "iTerm2", bundleIdPattern: "com.googlecode.iterm2",
                 context: "work", state: .app(windowTitle: "dev"), createdAt: "2024-01-01T00:00:00Z"),
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "https://swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-02T00:00:00Z"),
    ]
    return store
}

@Test func test_yamlEncodeDecode() throws {
    let original = makeStore()
    let text = try YAMLEncoder().encode(original)
    #expect(!text.isEmpty)

    let decoded = try YAMLDecoder().decode(BookmarkStore.self, from: text)
    #expect(decoded.bookmarks.count == original.bookmarks.count)
    #expect(decoded.bookmarks[0].id == "work-terminal")
    #expect(decoded.bookmarks[1].id == "docs")

    if case .app(let windowTitle) = decoded.bookmarks[0].state {
        #expect(windowTitle == "dev")
    } else {
        Issue.record("Expected .app state")
    }

    if case .browser(let urlPattern, let title, let tabIndex) = decoded.bookmarks[1].state {
        #expect(urlPattern == "https://swift.org")
        #expect(title == "Swift")
        #expect(tabIndex == nil)
    } else {
        Issue.record("Expected .browser state")
    }
}

@Test func test_emptyStore_yamlRoundTrip() throws {
    let store = BookmarkStore()
    let text = try YAMLEncoder().encode(store)
    let decoded = try YAMLDecoder().decode(BookmarkStore.self, from: text)
    #expect(decoded.bookmarks.isEmpty)
}

// MARK: - V1 → V2 Migration Tests

@Test func test_migrateV1toV2_iterm2_to_app() throws {
    let v1yaml = """
    bookmarks:
    - id: term
      bundleId: com.googlecode.iterm2
      appName: iTerm2
      context: work
      state:
        type: iterm2
        session: dev
      createdAt: "2024-01-01T00:00:00Z"
    """
    let migrated = try BookmarkStore.migrateV1YAML(v1yaml)
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: migrated)
    #expect(store.bookmarks[0].bundleIdPattern == "com.googlecode.iterm2")
    if case .app(let title) = store.bookmarks[0].state {
        #expect(title == "dev")
    } else {
        Issue.record("Expected .app state after migration")
    }
}

@Test func test_migrateV1toV2_generic_to_app() throws {
    let v1yaml = """
    bookmarks:
    - id: finder
      bundleId: com.apple.finder
      appName: Finder
      context: default
      state:
        type: generic
        windowTitle: Documents
      createdAt: "2024-01-01T00:00:00Z"
    """
    let migrated = try BookmarkStore.migrateV1YAML(v1yaml)
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: migrated)
    #expect(store.bookmarks[0].bundleIdPattern == "com.apple.finder")
    if case .app(let title) = store.bookmarks[0].state {
        #expect(title == "Documents")
    } else {
        Issue.record("Expected .app state after migration")
    }
}

@Test func test_migrateV1toV2_browser_url_to_urlPattern() throws {
    let v1yaml = """
    bookmarks:
    - id: docs
      bundleId: com.apple.Safari
      appName: Safari
      context: work
      state:
        type: browser
        url: "https://swift.org"
        title: Swift
      createdAt: "2024-01-01T00:00:00Z"
    """
    let migrated = try BookmarkStore.migrateV1YAML(v1yaml)
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: migrated)
    #expect(store.bookmarks[0].bundleIdPattern == "com.apple.Safari")
    if case .browser(let urlPattern, let title, _) = store.bookmarks[0].state {
        #expect(urlPattern == "https://swift.org")
        #expect(title == "Swift")
    } else {
        Issue.record("Expected .browser state after migration")
    }
}

@Test func test_migrateV1toV2_alreadyV2_noChange() throws {
    let v2yaml = """
    bookmarks:
    - id: finder
      bundleIdPattern: com.apple.finder
      appName: Finder
      context: default
      state:
        type: app
        windowTitle: Documents
      createdAt: "2024-01-01T00:00:00Z"
    """
    let migrated = try BookmarkStore.migrateV1YAML(v2yaml)
    let store = try YAMLDecoder().decode(BookmarkStore.self, from: migrated)
    #expect(store.bookmarks[0].bundleIdPattern == "com.apple.finder")
}
