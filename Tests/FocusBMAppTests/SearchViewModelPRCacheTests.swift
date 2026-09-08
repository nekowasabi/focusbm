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

/// Verifies the named PR behavior without network access.
@Test func refreshPullRequestCache_resolvesExpiredAndUncachedDirectories() {
    let viewModel = SearchViewModel()
    var calls: [String] = []
    viewModel.pullRequestURLProvider = { directory, _ in
        calls.append(directory)
        return "https://github.com/acme/focusbm/pull/77"
    }
    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!,
        Date(timeIntervalSinceNow: -SearchViewModel.PR_CACHE_TTL_SEC)
    )

    let resolved = viewModel.refreshPullRequestCache(
        tmuxPanes: [],
        aiProcesses: [prCacheProcess()]
    )
    viewModel.applyBackgroundCache(
        tmuxPanes: [],
        aiProcesses: [prCacheProcess()],
        prURLs: resolved.urls,
        failedPRCwds: resolved.failures
    )

    #expect(calls == [prCacheWorkingDirectory])
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == "#77")
}

/// Verifies the named PR behavior without network access.
@Test func refreshPullRequestCache_skipsFreshSuccessfulCache() {
    let viewModel = SearchViewModel()
    var calls = 0
    viewModel.pullRequestURLProvider = { _, _ in
        calls += 1
        return "https://github.com/acme/focusbm/pull/1"
    }
    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!, Date()
    )

    _ = viewModel.refreshPullRequestCache(
        tmuxPanes: [],
        aiProcesses: [prCacheProcess()]
    )
    #expect(calls == 0)
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == "#123")
}

/// Verifies the named PR behavior without network access.
@Test func isPRCacheFresh_failureExpiresSoonerThanSuccess() {
    let viewModel = SearchViewModel()
    viewModel.prFailureCache[prCacheWorkingDirectory] = Date()
    #expect(viewModel.isPRCacheFresh(for: prCacheWorkingDirectory))

    viewModel.prFailureCache[prCacheWorkingDirectory] = Date(
        timeIntervalSinceNow: -SearchViewModel.PR_FAILURE_CACHE_TTL_SEC
    )
    #expect(!viewModel.isPRCacheFresh(for: prCacheWorkingDirectory))

    viewModel.prURLCache[prCacheWorkingDirectory] = (
        URL(string: "https://github.com/acme/focusbm/pull/123")!,
        Date(timeIntervalSinceNow: -SearchViewModel.PR_FAILURE_CACHE_TTL_SEC)
    )
    viewModel.prFailureCache.removeAll()
    #expect(viewModel.isPRCacheFresh(for: prCacheWorkingDirectory))
}

/// Verifies the named PR behavior without network access.
@Test func refreshPullRequestCache_retriesAfterFailureTTL() {
    let viewModel = SearchViewModel()
    var calls = 0
    viewModel.pullRequestURLProvider = { _, _ in
        calls += 1
        return "https://github.com/acme/focusbm/pull/88"
    }
    viewModel.prFailureCache[prCacheWorkingDirectory] = Date(
        timeIntervalSinceNow: -SearchViewModel.PR_FAILURE_CACHE_TTL_SEC
    )

    let resolved = viewModel.refreshPullRequestCache(
        tmuxPanes: [],
        aiProcesses: [prCacheProcess()]
    )
    viewModel.applyBackgroundCache(
        tmuxPanes: [],
        aiProcesses: [prCacheProcess()],
        prURLs: resolved.urls,
        failedPRCwds: resolved.failures
    )
    #expect(calls == 1)
    #expect(viewModel.prLabel(for: .aiProcess(prCacheProcess())) == "#88")
}
