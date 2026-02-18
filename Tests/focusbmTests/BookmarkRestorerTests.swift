import Testing
@testable import FocusBMLib

@Test func test_isBrowser_knownBrowsers() {
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.microsoft.edgemac") == true)
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.google.Chrome") == true)
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.brave.Browser") == true)
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.apple.Safari") == true)
    #expect(AppleScriptBridge.isBrowser(bundleId: "org.mozilla.firefox") == true)
}

@Test func test_isBrowser_nonBrowser() {
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.googlecode.iterm2") == false)
    #expect(AppleScriptBridge.isBrowser(bundleId: "com.apple.finder") == false)
}

@Test func test_searchFilter_emptyQuery() {
    let bookmarks = [
        Bookmark(id: "work", appName: "iTerm2", bundleIdPattern: "com.googlecode.iterm2",
                 context: "dev", state: .app(windowTitle: ""), createdAt: "2024-01-01T00:00:00Z"),
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-01T00:00:00Z"),
    ]
    let result = BookmarkSearcher.filter(bookmarks: bookmarks, query: "")
    #expect(result.count == 2)
}

@Test func test_searchFilter_byId() {
    let bookmarks = [
        Bookmark(id: "work-term", appName: "iTerm2", bundleIdPattern: "com.googlecode.iterm2",
                 context: "dev", state: .app(windowTitle: ""), createdAt: "2024-01-01T00:00:00Z"),
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-01T00:00:00Z"),
    ]
    let result = BookmarkSearcher.filter(bookmarks: bookmarks, query: "doc")
    #expect(result.count == 1)
    #expect(result[0].id == "docs")
}

@Test func test_searchFilter_byAppName() {
    let bookmarks = [
        Bookmark(id: "work", appName: "iTerm2", bundleIdPattern: "com.googlecode.iterm2",
                 context: "dev", state: .app(windowTitle: ""), createdAt: "2024-01-01T00:00:00Z"),
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-01T00:00:00Z"),
    ]
    let result = BookmarkSearcher.filter(bookmarks: bookmarks, query: "safari")
    #expect(result.count == 1)
    #expect(result[0].id == "docs")
}

@Test func test_searchFilter_byContext() {
    let bookmarks = [
        Bookmark(id: "work", appName: "iTerm2", bundleIdPattern: "com.googlecode.iterm2",
                 context: "dev", state: .app(windowTitle: ""), createdAt: "2024-01-01T00:00:00Z"),
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-01T00:00:00Z"),
    ]
    let result = BookmarkSearcher.filter(bookmarks: bookmarks, query: "dev")
    #expect(result.count == 1)
    #expect(result[0].id == "work")
}

@Test func test_searchFilter_caseInsensitive() {
    let bookmarks = [
        Bookmark(id: "docs", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                 context: "work", state: .browser(urlPattern: "swift.org", title: "Swift", tabIndex: nil),
                 createdAt: "2024-01-01T00:00:00Z"),
    ]
    let result = BookmarkSearcher.filter(bookmarks: bookmarks, query: "SAFARI")
    #expect(result.count == 1)
}
