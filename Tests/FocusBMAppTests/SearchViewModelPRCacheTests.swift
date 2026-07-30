import Foundation
import Testing
@testable import FocusBMApp
@testable import FocusBMLib

private let prCacheWorkingDirectory = "/tmp/focusbm-pr-cache"

private func prCacheProcess() -> ProcessProvider.AIProcess {
    ProcessProvider.AIProcess(
        pid: 1,
        command: "codex",
        workingDirectory: prCacheWorkingDirectory,
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "🤖",
        title: "Codex"
    )
}

/// Verifies the named PR behavior without network access.
@Test func prLabel_returnsNilWhenNotCached() {
    #expect(SearchViewModel().prLabel(for: .aiProcess(prCacheProcess())) == nil)
}

/// Verifies the named PR behavior without network access.
@Test func prLabel_returnsNumberForFreshCachedURL() {
    let viewModel = SearchViewModel()
    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!, Date()
    )
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == "#123")
}

/// Verifies the named PR behavior without network access.
@Test func prLabel_returnsNilForExpiredOrNonDirectoryItem() {
    let viewModel = SearchViewModel()
    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!,
        Date(timeIntervalSinceNow: -SearchViewModel.PR_CACHE_TTL_SEC)
    )
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == nil)

    let bookmark = Bookmark(
        id: "bookmark",
        appName: "Finder",
        bundleIdPattern: nil,
        context: "test",
        state: .app(windowTitle: ""),
        createdAt: "2026-01-01T00:00:00Z"
    )
    #expect(viewModel.prLabel(for: .bookmark(bookmark)) == nil)
}

/// Verifies the named PR behavior without network access.
@Test func applyBackgroundCache_keepsPRCacheWhenURLsAreOmitted() {
    let viewModel = SearchViewModel()
    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!, Date()
    )
    viewModel.applyBackgroundCache(tmuxPanes: [], aiProcesses: [])
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == "#123")
}
