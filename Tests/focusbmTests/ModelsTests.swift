import Testing
import Foundation
@testable import FocusBMLib
import Yams

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
    let state = AppState.browser(urlPattern: "https://example.com", title: "Example", tabIndex: 3, urlPrefix: nil)
    if case .browser(let urlPattern, let title, let tabIndex, _) = state {
        #expect(urlPattern == "https://example.com")
        #expect(title == "Example")
        #expect(tabIndex == 3)
    } else {
        Issue.record("Expected .browser case")
    }
}

@Test func test_browser_tabIndexNil() {
    let state = AppState.browser(urlPattern: "https://example.com", title: "Example", tabIndex: nil, urlPrefix: nil)
    if case .browser(_, _, let tabIndex, _) = state {
        #expect(tabIndex == nil)
    } else {
        Issue.record("Expected .browser case")
    }
}

// MARK: - Bookmark Description Tests

@Test func test_description_browser_withoutTabIndex() {
    let bm = Bookmark(id: "t", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                      context: "work", state: .browser(urlPattern: "https://swift.org", title: "Swift", tabIndex: nil, urlPrefix: nil),
                      createdAt: "2024-01-01T00:00:00Z")
    #expect(bm.description == "Safari: Swift (https://swift.org)")
}

@Test func test_description_browser_withTabIndex() {
    let bm = Bookmark(id: "t", appName: "Safari", bundleIdPattern: "com.apple.Safari",
                      context: "work", state: .browser(urlPattern: "https://swift.org", title: "Swift", tabIndex: 3, urlPrefix: nil),
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
    let state: AppState = .browser(urlPattern: urlPattern, title: displayName, tabIndex: nil, urlPrefix: nil)

    let bookmark = Bookmark(
        id: "pr",
        appName: displayName,
        bundleIdPattern: bundleIdPattern,
        context: "dev",
        state: state,
        createdAt: ISO8601DateFormatter().string(from: Date())
    )

    #expect(bookmark.id == "pr")
    if case .browser(let url, let title, let tabIndex, _) = bookmark.state {
        #expect(url == "github.com/pulls")
        #expect(title == "Microsoft Edge")
        #expect(tabIndex == nil)
    } else {
        Issue.record("Expected .browser case")
    }
}

// MARK: - AppState urlPrefix Tests

@Test func test_appState_browser_urlPrefix_encodeDecode() throws {
    // urlPrefix あり: encode → decode で値が保持される
    let state = AppState.browser(urlPattern: "https://app.slack.com/client/aaa/inbox", title: "Slack", tabIndex: nil, urlPrefix: "https://app.slack.com/client/aaa")
    let encoder = YAMLEncoder()
    let yaml = try encoder.encode(["state": state])
    let decoder = YAMLDecoder()
    let decoded = try decoder.decode([String: AppState].self, from: yaml)
    if case .browser(_, _, _, let prefix) = decoded["state"] {
        #expect(prefix == "https://app.slack.com/client/aaa")
    } else {
        Issue.record("Expected .browser case")
    }
}

@Test func test_appState_browser_urlPrefix_nilDefault() throws {
    // urlPrefix なし: decode 時に nil になる（後方互換）
    let yaml = """
    type: browser
    urlPattern: github.com/pulls
    title: Pull Requests
    """
    let decoder = YAMLDecoder()
    let state = try decoder.decode(AppState.self, from: yaml)
    if case .browser(_, _, _, let prefix) = state {
        #expect(prefix == nil)
    } else {
        Issue.record("Expected .browser case")
    }
}

@Test func test_appState_browser_urlPrefix_inBookmarkStore() throws {
    // BookmarkStore の YAML に urlPrefix が含まれる場合の decode
    let yaml = """
    bookmarks:
      - id: slack
        appName: Google Chrome
        context: work
        createdAt: "2024-01-01T00:00:00Z"
        state:
          type: browser
          urlPattern: "https://app.slack.com/client/aaa/inbox"
          title: Slack
          urlPrefix: "https://app.slack.com/client/aaa"
    """
    let decoder = YAMLDecoder()
    let store = try decoder.decode(BookmarkStore.self, from: yaml)
    #expect(store.bookmarks.count == 1)
    if case .browser(let pattern, _, _, let prefix) = store.bookmarks[0].state {
        #expect(pattern == "https://app.slack.com/client/aaa/inbox")
        #expect(prefix == "https://app.slack.com/client/aaa")
    } else {
        Issue.record("Expected .browser case with urlPrefix")
    }
}

// MARK: - SearchItem.agentEmoji Tests

@Test func test_agentEmoji_aiProcess_copilot() {
    let process = ProcessProvider.AIProcess(
        pid: 1, command: "copilot", workingDirectory: "/tmp",
        terminalBundleId: nil, terminalAppName: nil, terminalEmoji: "👻", title: ""
    )
    let item = SearchItem.aiProcess(process)
    #expect(item.agentEmoji == "✈️")
}

@Test func test_agentEmoji_aiProcess_codex() {
    let process = ProcessProvider.AIProcess(
        pid: 2, command: "codex", workingDirectory: "/tmp",
        terminalBundleId: nil, terminalAppName: nil, terminalEmoji: "👻", title: ""
    )
    let item = SearchItem.aiProcess(process)
    #expect(item.agentEmoji == "📖")
}

@Test func test_agentEmoji_aiProcess_claude() {
    let process = ProcessProvider.AIProcess(
        pid: 3, command: "claude", workingDirectory: "/tmp",
        terminalBundleId: nil, terminalAppName: nil, terminalEmoji: "👻", title: ""
    )
    let item = SearchItem.aiProcess(process)
    #expect(item.agentEmoji == "🤖")
}

@Test func test_agentEmoji_tmuxPane_copilot() {
    let pane = TmuxPane(paneId: "%20", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "copilot", title: "", currentPath: "/tmp")
    let item = SearchItem.tmuxPane(pane)
    #expect(item.agentEmoji == "✈️")
}

@Test func test_agentEmoji_tmuxPane_codex_via_resolvedNodeCommand() {
    // Why: command="node" でもresolvedNodeCommandが"codex"なら📖を返すことを保証する
    var pane = TmuxPane(paneId: "%21", sessionName: "s", windowIndex: 0,
                        windowName: "w", command: "node", title: "", currentPath: "/tmp")
    pane.resolvedNodeCommand = "codex"
    let item = SearchItem.tmuxPane(pane)
    #expect(item.agentEmoji == "📖")
}

// MARK: - SearchItem.agentDisplay Tests

@Test func test_agentDisplay_tmuxPane_running() {
    // Braille character ⠋ (U+280B) triggers .running in agentStatus detection
    let pane = TmuxPane(paneId: "%1", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "claude", title: "\u{280B} Claude Code", currentPath: "/tmp")
    let item = SearchItem.tmuxPane(pane)
    let display = item.agentDisplay
    #expect(display != nil)
    #expect(display?.emoji == "●")
    #expect(display?.isRunning == true)
}

@Test func test_agentDisplay_tmuxPane_idle() {
    let pane = TmuxPane(paneId: "%2", sessionName: "work", windowIndex: 0,
                        windowName: "dev", command: "claude", title: "Claude Code", currentPath: "/tmp")
    let item = SearchItem.tmuxPane(pane)
    let display = item.agentDisplay
    #expect(display != nil)
    #expect(display?.emoji == "○")
    #expect(display?.isRunning == false)
}

@Test func test_agentDisplay_bookmark_nil() {
    let bm = Bookmark(id: "test", appName: "Terminal", bundleIdPattern: "com.apple.Terminal",
                      context: "work", state: .app(windowTitle: "zsh"),
                      createdAt: "2024-01-01T00:00:00Z")
    let item = SearchItem.bookmark(bm)
    #expect(item.agentDisplay == nil)
}

@Test func test_agentDisplay_aiProcess_nil() {
    let process = ProcessProvider.AIProcess(
        pid: 1234, command: "/usr/local/bin/codex",
        workingDirectory: "/tmp", terminalBundleId: nil,
        terminalAppName: "Terminal", terminalEmoji: "💻",
        title: "codex"
    )
    let item = SearchItem.aiProcess(process)
    #expect(item.agentDisplay == nil)
}

@Test func test_agentDisplay_nameWithoutEmoji_containsAgentName() {
    let pane = TmuxPane(paneId: "%3", sessionName: "main", windowIndex: 0,
                        windowName: "dev", command: "claude", title: "Claude Code", currentPath: "/tmp")
    let item = SearchItem.tmuxPane(pane)
    let display = item.agentDisplay
    #expect(display?.nameWithoutEmoji.contains("Claude Code") == true)
    #expect(!(display?.nameWithoutEmoji.contains("○") ?? false))
    #expect(!(display?.nameWithoutEmoji.contains("●") ?? false))
}
