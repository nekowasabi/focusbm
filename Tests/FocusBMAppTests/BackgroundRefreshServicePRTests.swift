import Foundation
import Testing
@testable import FocusBMApp
@testable import FocusBMLib

private let refreshTestWait: TimeInterval = 0.1
private let refreshTestURL = "https://github.com/acme/focusbm/pull/42"
private let concurrentResolutionWait: TimeInterval = 0.05

private func refreshTestProcess(_ workingDirectory: String) -> ProcessProvider.AIProcess {
    ProcessProvider.AIProcess(
        pid: 1,
        command: "codex",
        workingDirectory: workingDirectory,
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "🤖",
        title: "Codex"
    )
}

private func waitForRefresh() {
    let completed = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        completed.signal()
    }
    _ = completed.wait(timeout: .now() + refreshTestWait)
}

/// Verifies the named PR behavior without network access.
@Test func backgroundRefresh_resolvesEachUncachedDirectoryOnce() {
    let workingDirectory = "/tmp/focusbm-refresh"
    let viewModel = SearchViewModel()
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory), refreshTestProcess(workingDirectory)] }
    )

    service.refreshForTesting()
    waitForRefresh()
    #expect(calls == 1)
    #expect(viewModel.prLabel(for: .aiProcess(refreshTestProcess(workingDirectory))) == "#42")
}

/// Verifies the named PR behavior without network access.
@Test func backgroundRefresh_negativeCachePreventsRetryWithinTTL() {
    let workingDirectory = "/tmp/focusbm-refresh-failure"
    let viewModel = SearchViewModel()
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return nil
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory)] }
    )

    service.refreshForTesting()
    waitForRefresh()
    service.refreshForTesting()
    waitForRefresh()
    #expect(calls == 1)
}

/// Verifies that an expired successful cache entry is resolved again.
@Test func backgroundRefresh_resolvesExpiredCacheEntryAgain() {
    let workingDirectory = "/tmp/focusbm-refresh-expired"
    let viewModel = SearchViewModel()
    viewModel.prURLCache[workingDirectory] = (
        URL(string: refreshTestURL)!,
        Date(timeIntervalSinceNow: -SearchViewModel.PR_CACHE_TTL_SEC)
    )
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory)] }
    )

    service.refreshForTesting()
    waitForRefresh()
    #expect(calls == 1)
}

/// Verifies that a fresh successful cache entry is not resolved again.
@Test func backgroundRefresh_skipsFreshCacheEntry() {
    let workingDirectory = "/tmp/focusbm-refresh-fresh"
    let viewModel = SearchViewModel()
    viewModel.prURLCache[workingDirectory] = (URL(string: refreshTestURL)!, Date())
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory)] }
    )

    service.refreshForTesting()
    waitForRefresh()
    #expect(calls == 0)
}

/// Verifies that a refresh does not run after the view model is released.
@Test func backgroundRefresh_doesNothingAfterViewModelDeallocation() {
    var viewModel: SearchViewModel? = SearchViewModel()
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel!,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess("/tmp/focusbm-refresh-released")] }
    )
    viewModel = nil

    service.refreshForTesting()
    #expect(calls == 0)
}

/// Verifies that the existing sleep guard also skips PR resolution.
@Test func backgroundRefresh_skipsPRResolutionDuringSleep() {
    let viewModel = SearchViewModel()
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess("/tmp/focusbm-refresh-sleep")] }
    )
    service.isSleeping = true

    service.refreshForTesting()
    #expect(calls == 0)
}

/// Verifies the named PR behavior without network access.
@Test func backgroundRefresh_limitsConcurrentPRResolutions() {
    let viewModel = SearchViewModel()
    let lock = NSLock()
    var activeCalls = 0
    var maximumActiveCalls = 0
    let workingDirectories = (0...BackgroundRefreshService.PR_RESOLVE_MAX_CONCURRENT).map {
        "/tmp/focusbm-concurrency-\($0)"
    }
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            lock.lock()
            activeCalls += 1
            maximumActiveCalls = max(maximumActiveCalls, activeCalls)
            lock.unlock()
            Thread.sleep(forTimeInterval: concurrentResolutionWait)
            lock.lock()
            activeCalls -= 1
            lock.unlock()
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { workingDirectories.map(refreshTestProcess) }
    )

    service.refreshForTesting()
    waitForRefresh()
    #expect(maximumActiveCalls <= BackgroundRefreshService.PR_RESOLVE_MAX_CONCURRENT)
}

/// Verifies that enabling the timer resolves once without waiting a full interval.
@Test func backgroundRefresh_startsImmediatelyWhenTimerEnabled() {
    let workingDirectory = "/tmp/focusbm-refresh-startup"
    let viewModel = SearchViewModel()
    var calls = 0
    let resolved = DispatchSemaphore(value: 0)
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        interval: 60,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            resolved.signal()
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory)] }
    )
    service.isSleeping = false
    service.start()

    let process = refreshTestProcess(workingDirectory)
    _ = resolved.wait(timeout: .now() + 2)
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
        if viewModel.prLabel(for: .aiProcess(process)) == "#42" { break }
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    service.stop()
    #expect(calls == 1)
    #expect(viewModel.prLabel(for: .aiProcess(process)) == "#42")
}

/// Verifies expired failure cache is resolved again before the success TTL.
@Test func backgroundRefresh_retriesAfterFailureTTL() {
    let workingDirectory = "/tmp/focusbm-refresh-failure-ttl"
    let viewModel = SearchViewModel()
    viewModel.prFailureCache[workingDirectory] = Date(
        timeIntervalSinceNow: -SearchViewModel.PR_FAILURE_CACHE_TTL_SEC
    )
    var calls = 0
    let service = BackgroundRefreshService(
        viewModel: viewModel,
        startTimer: false,
        pullRequestURLProvider: { _, _ in
            calls += 1
            return refreshTestURL
        },
        tmuxPaneProvider: { _ in [] },
        aiProcessProvider: { [refreshTestProcess(workingDirectory)] }
    )

    service.refreshForTesting()
    waitForRefresh()
    #expect(calls == 1)
}
