import Foundation
import AppKit
import FocusBMLib

/// tmux/process 情報を定期的にバックグラウンド更新するサービス
/// AX API（floating windows）は負荷が高いため対象外
class BackgroundRefreshService {
    private var timer: DispatchSourceTimer?
    private weak var viewModel: SearchViewModel?
    private var isSleeping = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private let interval: TimeInterval

    init(viewModel: SearchViewModel, interval: TimeInterval = 15) {
        self.viewModel = viewModel
        self.interval = interval
        observeScreenSleep()
        start()
    }

    deinit {
        stop()
        if let obs = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
        if let obs = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
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

    private func observeScreenSleep() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.isSleeping = true
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.isSleeping = false
        }
    }
}
