import Foundation
import AppKit
import FocusBMLib

/// tmux/process 情報を定期的にバックグラウンド更新するサービス
/// AX API（floating windows）は負荷が高いため対象外
class BackgroundRefreshService {
    static let GH_TIMEOUT_SEC: TimeInterval = GitHubPullRequestCLI.timeoutSeconds
    static let PR_RESOLVE_MAX_CONCURRENT = 4
    static let BACKGROUND_REFRESH_INTERVAL_SEC: TimeInterval = 15

    private var timer: DispatchSourceTimer?
    private weak var viewModel: SearchViewModel?
    // Why: Keep this internal instead of private so @testable tests can prove that
    // PR resolution remains skipped across the existing sleep boundary.
    var isSleeping = false
    private var powerObservers: [NSObjectProtocol] = []
    private let interval: TimeInterval
    private let pullRequestURLProvider: (String, TimeInterval) -> String?
    private let tmuxPaneProvider: (AppSettings?) -> [TmuxPane]
    private let aiProcessProvider: () -> [ProcessProvider.AIProcess]

    init(
        viewModel: SearchViewModel,
        interval: TimeInterval = BACKGROUND_REFRESH_INTERVAL_SEC,
        startTimer: Bool = true,
        pullRequestURLProvider: @escaping (String, TimeInterval) -> String? = {
            GitHubPullRequestCLI.resolveURLString(workingDirectory: $0, timeout: $1)
        },
        tmuxPaneProvider: @escaping (AppSettings?) -> [TmuxPane] = {
            (try? TmuxProvider.listAIAgentPanes(settings: $0)) ?? []
        },
        aiProcessProvider: @escaping () -> [ProcessProvider.AIProcess] = {
            ProcessProvider.listNonTmuxAIProcesses()
        }
    ) {
        self.viewModel = viewModel
        self.interval = interval
        self.pullRequestURLProvider = pullRequestURLProvider
        self.tmuxPaneProvider = tmuxPaneProvider
        self.aiProcessProvider = aiProcessProvider
        observePowerState()
        if startTimer {
            start()
        }
    }

    deinit {
        stop()
        powerObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            self?.refresh()
        }
        t.resume()
        self.timer = t
        // Why: Instead of waiting for the first repeating tick, kick one refresh now.
        // Reason: after reboot the in-memory PR cache is empty until the first refresh.
        refreshAsync()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func refreshForTesting() {
        refresh()
    }

    private func refresh() {
        guard !isSleeping else { return }
        guard let viewModel = viewModel else { return }

        let settings = viewModel.currentAppSettings
        let showTmux = viewModel.currentShowTmuxAgents
        guard showTmux else { return }

        let tmuxPanes = tmuxPaneProvider(settings)
        let aiProcesses = aiProcessProvider()
        let workingDirectories = Set(
            tmuxPanes.map(\.currentPath) + aiProcesses.map(\.workingDirectory)
        ).filter { !viewModel.isPRCacheFresh(for: $0) }

        let resolved = Self.resolvePullRequests(
            workingDirectories: Array(workingDirectories),
            existingURLs: viewModel.prURLCache,
            existingFailures: viewModel.prFailureCache,
            pullRequestURLProvider: pullRequestURLProvider
        )

        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.applyBackgroundCache(
                tmuxPanes: tmuxPanes,
                aiProcesses: aiProcesses,
                prURLs: resolved.urls,
                failedPRCwds: resolved.failures
            )
        }
    }

    // Why: Use a semaphore instead of unrestricted concurrent work items so one refresh
    // cannot exhaust process slots when many working directories have no pull request.
    static func resolvePullRequests(
        workingDirectories: [String],
        existingURLs: [String: (url: URL, fetchedAt: Date)],
        existingFailures: [String: Date],
        pullRequestURLProvider: @escaping (String, TimeInterval) -> String?
    ) -> (
        urls: [String: (url: URL, fetchedAt: Date)],
        failures: [String: Date]
    ) {
        var urls = existingURLs
        var failures = existingFailures
        let lock = NSLock()
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: Self.PR_RESOLVE_MAX_CONCURRENT)

        for workingDirectory in workingDirectories {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                semaphore.wait()
                defer {
                    semaphore.signal()
                    group.leave()
                }

                let fetchedAt = Date()
                let value = pullRequestURLProvider(
                    workingDirectory,
                    GH_TIMEOUT_SEC
                )
                lock.lock()
                defer { lock.unlock() }

                if let value,
                   let url = SessionPullRequestResolver.validatedPullRequestURL(value) {
                    urls[workingDirectory] = (url, fetchedAt)
                    failures.removeValue(forKey: workingDirectory)
                } else {
                    failures[workingDirectory] = fetchedAt
                }
            }
        }
        group.wait()
        return (urls, failures)
    }

    private func refreshAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.refresh()
        }
    }

    private func refreshAsyncAfterWakeDelay() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.refresh()
        }
    }

    private func observePowerState() {
        let sleepNotifications: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification
        ]
        let wakeNotifications: [Notification.Name] = [
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.didWakeNotification
        ]

        for notification in sleepNotifications {
            let observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isSleeping = true
            }
            powerObservers.append(observer)
        }

        for notification in wakeNotifications {
            let observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isSleeping = false
                // Why: Instead of refreshing immediately on wake, adopted a short delay.
                // Reason: NSWorkspace.runningApplications can still be incomplete right after wake.
                self?.refreshAsyncAfterWakeDelay()
            }
            powerObservers.append(observer)
        }
    }
}
