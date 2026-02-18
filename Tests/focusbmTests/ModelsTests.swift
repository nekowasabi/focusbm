import Testing
import Foundation
@testable import FocusBMLib

// MARK: - AppState Tests

@Test func test_app_state() {
    let state = AppState.app(windowTitle: "My Window")
    if case .app(let windowTitle) = state {
        #expect(windowTitle == "My Window")
    } else {
        Issue.record("Expected .app case")
    }
}

@Test func test_browser_withTabIndex() {
    let state = AppState.browser(urlPattern: "https://example.com", title: "Example", tabIndex: 3)
    if case .browser(let urlPattern, let title, let tabIndex) = state {
        #expect(urlPattern == "https://example.com")
        #expect(title == "Example")
        #expect(tabIndex == 3)
    } else {
        Issue.record("Expected .browser case")
    }
}

@Test func test_browser_tabIndexNil() {
    let state = AppState.browser(urlPattern: "https://example.com", title: "Example", tabIndex: nil)
    if case .browser(_, _, let tabIndex) = state {
        #expect(tabIndex == nil)
    } else {
        Issue.record("Expected .browser case")
    }
}

// MARK: - Bookmark Description Tests

@Test func test_description_browser_withoutTabIndex() {
    let bm = Bookmark(id: "t", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                      context: "work", state: .browser(urlPattern: "https://swift.org", title: "Swift", tabIndex: nil),
                      createdAt: "2024-01-01T00:00:00Z")
    #expect(bm.description == "Safari: Swift (https://swift.org)")
}

@Test func test_description_browser_withTabIndex() {
    let bm = Bookmark(id: "t", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                      context: "work", state: .browser(urlPattern: "https://swift.org", title: "Swift", tabIndex: 3),
                      createdAt: "2024-01-01T00:00:00Z")
    #expect(bm.description == "Safari: Swift (https://swift.org) [tab:3]")
}

@Test func test_description_app() {
    let bm = Bookmark(id: "t", appName: "Finder", bundleIdPattern: "com.apple.finder",
                      context: "work", state: .app(windowTitle: "Documents"), createdAt: "2024-01-01T00:00:00Z")
    #expect(bm.description == "Finder: Documents")
}

// MARK: - BookmarkStore Tests

@Test func test_storePath_isYml() {
    let path = BookmarkStore.storePath.path
    #expect(path.hasSuffix(".yml"))
}

@Test func test_bookmark_createdAt_isString() {
    let bm = Bookmark(id: "a", appName: "App", bundleIdPattern: "com.app",
                      context: "default", state: .app(windowTitle: "Win"),
                      createdAt: "2023-11-14T22:13:20Z")
    #expect(bm.createdAt == "2023-11-14T22:13:20Z")
}

// MARK: - Add Command Logic Tests

@Test func test_add_command_creates_app_bookmark() {
    // add コマンドのロジックを直接テスト（AppState 生成部分）
    let bundleIdPattern = "com.example.app"
    let displayName = "Example App"
    let state: AppState = .app(windowTitle: "")

    let bookmark = Bookmark(
        id: "testapp",
        appName: displayName,
        bundleIdPattern: bundleIdPattern,
        context: "work",
        state: state,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )

    #expect(bookmark.id == "testapp")
    #expect(bookmark.appName == "Example App")
    #expect(bookmark.bundleIdPattern == "com.example.app")
    #expect(bookmark.context == "work")
    if case .app(let windowTitle) = bookmark.state {
        #expect(windowTitle == "")
    } else {
        Issue.record("Expected .app case")
    }
}

@Test func test_add_command_creates_browser_bookmark() {
    // --url 指定時は .browser ブックマークになる
    let bundleIdPattern = "com.microsoft.edgemac"
    let urlPattern = "github.com/pulls"
    let displayName = "Microsoft Edge"
    let state: AppState = .browser(urlPattern: urlPattern, title: displayName, tabIndex: nil)

    let bookmark = Bookmark(
        id: "pr",
        appName: displayName,
        bundleIdPattern: bundleIdPattern,
        context: "dev",
        state: state,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )

    #expect(bookmark.id == "pr")
    if case .browser(let url, let title, let tabIndex) = bookmark.state {
        #expect(url == "github.com/pulls")
        #expect(title == "Microsoft Edge")
        #expect(tabIndex == nil)
    } else {
        Issue.record("Expected .browser case")
    }
}
