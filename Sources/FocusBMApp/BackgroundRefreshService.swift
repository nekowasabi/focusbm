import Foundation
import AppKit
import FocusBMLib

/// tmux/process 情報を定期的にバックグラウンド更新するサービス
/// AX API（floating windows）は負荷が高いため対象外
class BackgroundRefreshService {
    private var timer: DispatchSourceTimer?
    private weak var viewModel: SearchViewModel?
    private var isSleeping = false
    private var powerObservers: [NSObjectProtocol] = []
    private let interval: TimeInterval

    init(viewModel: SearchViewModel, interval: TimeInterval = 15) {
        self.viewModel = viewModel
        self.interval = interval
        observePowerState()
        start()
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
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func refresh() {
        guard !isSleeping else { return }
        guard let viewModel = viewModel else { return }

        let settings = viewModel.currentAppSettings
        let showTmux = viewModel.currentShowTmuxAgents

        guard showTmux else { return }

        let tmuxPanes = (try? TmuxProvider.listAIAgentPanes(settings: settings)) ?? []
        let aiProcesses = ProcessProvider.listNonTmuxAIProcesses()

        DispatchQueue.main.async { [weak viewModel] in
            viewModel?.applyBackgroundCache(tmuxPanes: tmuxPanes, aiProcesses: aiProcesses)
        }
    }

    private func refreshAsync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
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
