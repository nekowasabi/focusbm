import Foundation
import Combine
import AppKit
import SwiftUI
import FocusBMLib

class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            autoExecuteGeneration += 1
            updateItems()
        }
    }
    @Published var bookmarks: [Bookmark] = []
    @Published var searchItems: [SearchItem] = []
    @Published var selectedIndex: Int = 0
    @Published var hoveredIndex: Int? = nil
    @Published var screenPreview: AgentScreenPreviewState? = nil
    @Published var promptDraft: String = ""
    /// 1-based capture index that receives the prompt. Single preview is 1; tiled stays nil until Cmd+N.
    @Published var promptTargetIndex: Int? = nil
    @Published var isPromptFieldFocused: Bool = false
    @Published var promptError: String? = nil
    /// Sends (paneId, text) to the agent. Tests replace this to avoid calling tmux.
    var promptSender: (String, String) throws -> Void = { try TmuxProvider.sendPrompt(paneId: $0, text: $1) }
    // Why: Serial queue because every send shares one tmux buffer name; overlapping sends would swap bodies.
    private let promptSendQueue = DispatchQueue(label: "focusbm.prompt-send", qos: .userInitiated)
    @Published var isActive: Bool = false
    /// Live tmux visible-pane capture. Tests replace this to avoid calling tmux.
    var paneScreenCaptureProvider: (String) -> String? = { TmuxProvider.capturePaneContent(paneId: $0, historyLines: nil, withEscapes: true) }

    private static let AGENT_STATUS_REFRESH_INTERVAL_SEC: TimeInterval = 3
    private var agentStatusTimer: DispatchSourceTimer?
    private var agentStatusRefreshGeneration = 0
    private static let SCREEN_PREVIEW_REFRESH_INTERVAL_SEC: TimeInterval = 0.5
    private var screenPreviewTimer: DispatchSourceTimer?
    private var screenPreviewRefreshGeneration = 0
    private var screenPreviewCaptureInFlight = false
    @Published var listFontSize: Double? = nil
    @Published var fontName: String? = nil
    @Published var previewWidth: Double? = nil
    @Published var previewHeight: Double? = nil
    @Published var previewFontSize: Double? = nil
    @Published var previewFontName: String? = nil

    // パネル表示時に enumerate() の結果をキャッシュ（キーストロークごとの AX IPC を回避）
    private var floatingWindowCache: [String: [FloatingWindowEntry]] = [:]
    private var tmuxPaneCache: [TmuxPane] = []
    private var aiProcessCache: [ProcessProvider.AIProcess] = []
    var prURLCache: [String: (url: URL, fetchedAt: Date)] = [:]
    var prFailureCache: [String: Date] = [:]
    static let PR_CACHE_TTL_SEC: TimeInterval = 300
    // Why: Instead of reusing the success TTL for failures, adopted a short failure TTL.
    // Reason: a gh timeout right after wake must not pin missing labels for 300 seconds.
    static let PR_FAILURE_CACHE_TTL_SEC: TimeInterval = 15
    var pullRequestURLProvider: (String, TimeInterval) -> String? = {
        GitHubPullRequestCLI.resolveURLString(workingDirectory: $0, timeout: $1)
    }
    // Why: 取得系の DI。refreshForPanelAsync の表示/PR 分離を決定的に検証するため、
    //      BackgroundRefreshService と同じクロージャ注入パターンを採用。
    var tmuxPaneProvider: (AppSettings?, ProcessSnapshot) -> [TmuxPane] = {
        (try? TmuxProvider.listAIAgentPanes(settings: $0, snapshot: $1)) ?? []
    }
    var aiProcessProvider: (ProcessSnapshot) -> [ProcessProvider.AIProcess] = {
        ProcessProvider.listNonTmuxAIProcesses(snapshot: $0)
    }
    private(set) var showTmuxAgents: Bool = true
    // Why: private(set) ではなく var を採用。理由: テストから appSettings を注入するため（同モジュール内の書き込みを許容）。
    // 外部からの書き込みは load() 経由が正規経路だが、テスト専用注入を許容する。internal がデフォルトのため明示修飾子は付けない。
    var appSettings: AppSettings? = nil
    var sessionPullRequestResolver = SessionPullRequestResolver()
    private var refreshGeneration: Int = 0
    /// 自動実行ハイライト中かどうか（実行直前の視覚フィードバック用）
    @Published var isAutoExecuteHighlighted: Bool = false
    /// 候補が1件になったとき呼ばれるコールバック（SearchPanel が設定）
    var onAutoExecute: (() -> Void)?
    /// 自動実行の遅延タイマー（キー入力ごとにキャンセル＆再スケジュール）
    private var autoExecuteWorkItem: DispatchWorkItem?
    private var autoExecuteGeneration = 0

    /// YAML を読み込んで bookmarks を更新する。AX API は呼ばない（起動時にも安全）。
    func load() {
        let store = BookmarkStore.loadYAML()
        bookmarks = store.bookmarks.filter(\.isEnabled)
        appSettings = store.settings
        listFontSize = store.settings?.listFontSize
        fontName = store.settings?.fontName
        previewWidth = store.settings?.previewWidth
        previewHeight = store.settings?.previewHeight
        previewFontSize = store.settings?.previewFontSize
        previewFontName = store.settings?.previewFontName
        showTmuxAgents = store.settings?.showTmuxAgents ?? true
        updateItems()
    }

    /// パネル表示時に呼ぶ。AX API でキャッシュを更新してから候補リストを再構築する。
    func refreshForPanel() {
        let snapshot = ProcessSnapshot.capture()
        cacheFloatingWindows()
        loadTmuxPanes(snapshot: snapshot)
        loadAIProcesses(snapshot: snapshot)
        updateItems()
    }

    func startAgentStatusMonitoring() {
        guard agentStatusTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(
            deadline: .now() + Self.AGENT_STATUS_REFRESH_INTERVAL_SEC,
            repeating: Self.AGENT_STATUS_REFRESH_INTERVAL_SEC
        )
        timer.setEventHandler { [weak self] in
            self?.refreshAgentStatusesAsync()
        }
        timer.resume()
        agentStatusTimer = timer
    }

    func stopAgentStatusMonitoring() {
        agentStatusRefreshGeneration += 1
        agentStatusTimer?.cancel()
        agentStatusTimer = nil
    }

    private func startScreenPreviewRefresh() {
        stopScreenPreviewRefresh()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(
            deadline: .now() + Self.SCREEN_PREVIEW_REFRESH_INTERVAL_SEC,
            repeating: Self.SCREEN_PREVIEW_REFRESH_INTERVAL_SEC
        )
        timer.setEventHandler { [weak self] in
            self?.refreshScreenPreviewAsync()
        }
        timer.resume()
        screenPreviewTimer = timer
    }

    private func stopScreenPreviewRefresh() {
        screenPreviewRefreshGeneration += 1
        screenPreviewTimer?.cancel()
        screenPreviewTimer = nil
        screenPreviewCaptureInFlight = false
    }

    private func refreshScreenPreviewAsync() {
        DispatchQueue.main.async { [weak self] in
            // Why: Instead of invalidating each tick, skip overlapping captures so slow results can still be applied.
            guard let self,
                  let preview = self.screenPreview,
                  !self.screenPreviewCaptureInFlight else { return }
            // Why: Use displayed capture IDs instead of searchItems, which can change while a preview stays visible.
            let paneIDs = preview.captures.map(\.id).filter { !$0.hasPrefix("aiprocess-") }
            guard !paneIDs.isEmpty else { return }

            let generation = self.screenPreviewRefreshGeneration
            // Why: Snapshot the injectable provider on the main queue so background reads cannot race with test replacement.
            let provider = self.paneScreenCaptureProvider
            self.screenPreviewCaptureInFlight = true

            DispatchQueue.global(qos: .utility).async { [weak self] in
                final class CaptureBox: @unchecked Sendable { var value: String? }
                let boxes = paneIDs.map { _ in CaptureBox() }
                DispatchQueue.concurrentPerform(iterations: paneIDs.count) { index in
                    boxes[index].value = provider(paneIDs[index])
                }
                var capturedTexts: [String: String] = [:]
                for (paneID, box) in zip(paneIDs, boxes) {
                    if let text = box.value { capturedTexts[paneID] = text }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.screenPreviewRefreshGeneration == generation else { return }
                    self.screenPreviewCaptureInFlight = false
                    guard let currentPreview = self.screenPreview else { return }

                    // Why: searchItems is refreshed by the agent status monitor, so re-read status here to keep the pill from going stale.
                    var statuses: [String: TmuxAgentStatus] = [:]
                    for case .tmuxPane(let pane) in self.searchItems { statuses[pane.paneId] = pane.agentStatus }
                    var didChange = false
                    let captures = currentPreview.captures.map { capture in
                        let text = capturedTexts[capture.id].map(self.normalizedCaptureText) ?? capture.text
                        let status = capture.id.hasPrefix("aiprocess-") ? capture.status : statuses[capture.id]
                        guard text != capture.text || status != capture.status else { return capture }
                        didChange = true
                        return AgentScreenCapture(
                            id: capture.id, title: capture.title, text: text, index: capture.index, status: status
                        )
                    }
                    guard didChange else { return }
                    switch currentPreview {
                    case .single:
                        self.screenPreview = .single(captures[0])
                    case .tiled:
                        self.screenPreview = .tiled(captures)
                    }
                }
            }
        }
    }

    private func refreshAgentStatusesAsync() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive else { return }

            self.agentStatusRefreshGeneration += 1
            let generation = self.agentStatusRefreshGeneration
            let settings = self.appSettings

            guard self.showTmuxAgents else {
                self.tmuxPaneCache = []
                self.updateItems(allowAutoExecute: false)
                return
            }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                let panes = (try? TmuxProvider.listAIAgentPanes(settings: settings)) ?? []
                DispatchQueue.main.async {
                    guard let self,
                          self.isActive,
                          self.agentStatusRefreshGeneration == generation else {
                        return
                    }
                    self.tmuxPaneCache = panes
                    self.updateItems(allowAutoExecute: false)
                }
            }
        }
    }

    /// パネル表示後にバックグラウンドでデータを更新する非同期版
    // Why: 3系統の取得（AX/tmux/プロセス）を並列化し、ps スナップショットを共有する。
    //      PR 解決（gh CLI、最大5秒×N）は行表示をブロックしない — 行を先に適用し、
    //      PR キャッシュは別の非同期ホップで後からマージする。
    func refreshForPanelAsync() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let currentBookmarks = bookmarks
        let currentShowTmuxAgents = showTmuxAgents
        let currentSettings = appSettings
        let currentTmuxPaneProvider = tmuxPaneProvider
        let currentAIProcessProvider = aiProcessProvider

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            final class FetchResults: @unchecked Sendable {
                var windowCache: [String: [FloatingWindowEntry]] = [:]
                var tmuxPanes: [TmuxPane] = []
                var aiProcesses: [ProcessProvider.AIProcess] = []
            }
            let results = FetchResults()
            let snapshot = ProcessSnapshot.capture()

            let fetchGroup = DispatchGroup()

            // floatingWindows (AX API)
            fetchGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                var cache: [String: [FloatingWindowEntry]] = [:]
                for bookmark in currentBookmarks {
                    if case .floatingWindows = bookmark.state {
                        cache[bookmark.appName] = FloatingWindowProvider.enumerate(appName: bookmark.appName)
                    }
                }
                results.windowCache = cache
                fetchGroup.leave()
            }

            if currentShowTmuxAgents {
                // tmux panes
                fetchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    results.tmuxPanes = currentTmuxPaneProvider(currentSettings, snapshot)
                    fetchGroup.leave()
                }

                // AI processes
                fetchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    results.aiProcesses = currentAIProcessProvider(snapshot)
                    fetchGroup.leave()
                }
            }

            fetchGroup.wait()
            let tmuxPanes = results.tmuxPanes
            let aiProcesses = results.aiProcesses

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // レースコンディション対策: 古い世代の結果は破棄
                guard generation == self.refreshGeneration else { return }
                self.floatingWindowCache = results.windowCache
                self.tmuxPaneCache = tmuxPanes
                self.aiProcessCache = aiProcesses
                // Why: 非同期更新はユーザー入力そのものではないため、
                //      autoExecuteOnSingleResult の副作用（外部アプリ activate）を発火させない。
                self.updateItems(allowAutoExecute: false)

                // Why: gh CLI の PR 解決は表示後の別ホップで行う。
                //      行表示が gh 完了（最大 timeout 秒）にブロックされていたため。
                let staleDirectories = Set(
                    tmuxPanes.map(\.currentPath) + aiProcesses.map(\.workingDirectory)
                ).filter { !self.isPRCacheFresh(for: $0) }
                guard !staleDirectories.isEmpty else { return }
                let provider = self.pullRequestURLProvider
                let existingURLs = self.prURLCache
                let existingFailures = self.prFailureCache
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    let resolved = BackgroundRefreshService.resolvePullRequests(
                        workingDirectories: Array(staleDirectories),
                        existingURLs: existingURLs,
                        existingFailures: existingFailures,
                        pullRequestURLProvider: provider
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        guard generation == self.refreshGeneration else { return }
                        self.prURLCache = resolved.urls
                        self.prFailureCache = resolved.failures
                        self.updateItems(allowAutoExecute: false)
                    }
                }
            }
        }
    }

    /// バックグラウンドサービスから参照用
    var currentAppSettings: AppSettings? { appSettings }
    var currentShowTmuxAgents: Bool { showTmuxAgents }

    /// バックグラウンドサービスからキャッシュを更新（パネル非表示時はプリウォーム、表示中は即時反映）
    func applyBackgroundCache(
        tmuxPanes: [TmuxPane],
        aiProcesses: [ProcessProvider.AIProcess],
        prURLs: [String: (url: URL, fetchedAt: Date)]? = nil,
        failedPRCwds: [String: Date]? = nil
    ) {
        tmuxPaneCache = tmuxPanes
        aiProcessCache = aiProcesses
        if let prURLs {
            prURLCache = prURLs
        }
        if let failedPRCwds {
            prFailureCache = failedPRCwds
        }

        if isActive {
            // Why: タイマー/復帰通知由来のバックグラウンド更新で候補が1件になっても、
            //      ユーザー操作なしに外部アプリへフォーカス移動させない。
            updateItems(allowAutoExecute: false)
        }
    }

    func prLabel(for item: SearchItem, now: Date = Date()) -> String? {
        let workingDirectory: String
        switch item {
        case .aiProcess(let process):
            workingDirectory = process.workingDirectory
        case .tmuxPane(let pane):
            workingDirectory = pane.currentPath
        case .bookmark, .floatingWindow:
            return nil
        }

        guard let entry = prURLCache[workingDirectory],
              now.timeIntervalSince(entry.fetchedAt) < Self.PR_CACHE_TTL_SEC else {
            return nil
        }
        return entry.url.lastPathComponent.isEmpty ? nil : "#\(entry.url.lastPathComponent)"
    }

    func isPRCacheFresh(for workingDirectory: String, now: Date = Date()) -> Bool {
        if let entry = prURLCache[workingDirectory],
           now.timeIntervalSince(entry.fetchedAt) < Self.PR_CACHE_TTL_SEC {
            return true
        }
        if let fetchedAt = prFailureCache[workingDirectory],
           now.timeIntervalSince(fetchedAt) < Self.PR_FAILURE_CACHE_TTL_SEC {
            return true
        }
        return false
    }

    /// Resolves stale/uncached PR URLs for the given panel candidates.
    /// Mutates nothing; the caller applies the returned caches on the main queue.
    @discardableResult
    func refreshPullRequestCache(
        tmuxPanes: [TmuxPane],
        aiProcesses: [ProcessProvider.AIProcess]
    ) -> (
        urls: [String: (url: URL, fetchedAt: Date)],
        failures: [String: Date]
    ) {
        let workingDirectories = Set(
            tmuxPanes.map(\.currentPath) + aiProcesses.map(\.workingDirectory)
        ).filter { !isPRCacheFresh(for: $0) }
        return BackgroundRefreshService.resolvePullRequests(
            workingDirectories: Array(workingDirectories),
            existingURLs: prURLCache,
            existingFailures: prFailureCache,
            pullRequestURLProvider: pullRequestURLProvider
        )
    }

    /// パネル非アクティブ化時の状態リセット。
    /// Why: isActive が true のまま残ると、バックグラウンド更新が表示中扱いになり
    ///      updateItems 経由の自動実行予約が残留/再発火し得るため。
    func deactivatePanel() {
        isActive = false
        hoveredIndex = nil
        _ = dismissScreenPreview()
        stopAgentStatusMonitoring()
        cancelPendingAutoExecute()
    }

    /// ユーザー操作による再読込など、保留中の自動実行を明示的に取り消す。
    func cancelPendingAutoExecute() {
        autoExecuteWorkItem?.cancel()
        autoExecuteWorkItem = nil
        isAutoExecuteHighlighted = false
    }

    /// floatingWindows 型ブックマークの enumerate() をパネル表示時に1回だけ実行してキャッシュ
    private func cacheFloatingWindows() {
        floatingWindowCache = [:]
        for bookmark in bookmarks {
            if case .floatingWindows = bookmark.state {
                floatingWindowCache[bookmark.appName] = FloatingWindowProvider.enumerate(appName: bookmark.appName)
            }
        }
    }

    /// tmux AIエージェントペインをパネル表示時に1回だけ取得してキャッシュ
    /// settings.showTmuxAgents が false の場合はスキップ
    private func loadTmuxPanes(snapshot: ProcessSnapshot? = nil) {
        guard showTmuxAgents else {
            tmuxPaneCache = []
            return
        }
        tmuxPaneCache = (try? TmuxProvider.listAIAgentPanes(settings: appSettings, snapshot: snapshot)) ?? []
    }

    /// tmux外で実行中のAIエージェントプロセスをパネル表示時に1回だけ取得してキャッシュ
    /// settings.showTmuxAgents が false の場合はスキップ
    private func loadAIProcesses(snapshot: ProcessSnapshot? = nil) {
        guard showTmuxAgents else {
            aiProcessCache = []
            return
        }
        aiProcessCache = ProcessProvider.listNonTmuxAIProcesses(snapshot: snapshot)
    }

    func updateItems(allowAutoExecute: Bool = true) {
        var items: [SearchItem] = []

        if query.isEmpty {
            // クエリなし: lowPriority を末尾に送りつつ YAML 順序を維持
            let orderedBookmarks = bookmarks.sorted { !($0.lowPriority ?? false) && ($1.lowPriority ?? false) }
            for bookmark in orderedBookmarks {
                if case .floatingWindows = bookmark.state {
                    let entries = floatingWindowCache[bookmark.appName] ?? []
                    items += entries.map { .floatingWindow($0) }
                } else {
                    items.append(.bookmark(bookmark))
                }
            }
            // tmux AIエージェントペインをリストの末尾に追加
            items += tmuxPaneCache.map { .tmuxPane($0) }
            // tmux外のAIエージェントプロセスを追加
            items += aiProcessCache.map { .aiProcess($0) }
            // query.isEmpty: lowPriority ブックマークを AI エージェントの後ろへ移動
            items = items.filter { !$0.lowPriority } + items.filter { $0.lowPriority }
        } else {
            // クエリあり: fuzzy フィルタ（floatingWindows は名前マッチ、通常はスコア順）
            for bookmark in bookmarks {
                if case .floatingWindows = bookmark.state {
                    let entries = (floatingWindowCache[bookmark.appName] ?? []).filter {
                        BookmarkSearcher.fuzzyScore(text: $0.displayName, query: query) != nil
                    }
                    items += entries.map { .floatingWindow($0) }
                }
            }
            let regular = bookmarks.filter {
                if case .floatingWindows = $0.state { return false }
                return true
            }
            items += BookmarkSearcher.filter(bookmarks: regular, query: query).map { .bookmark($0) }
            // tmux ペインを displayName・端末名・状態・行テキストで fuzzy フィルタ
            items += tmuxPaneCache.filter { pane in
                let item = SearchItem.tmuxPane(pane)
                let texts = [pane.displayName, pane.terminalAppName ?? "", item.statusText, item.rowText(prLabel: prLabel(for: item))]
                return BookmarkSearcher.score(texts: texts, query: query) != nil
            }.map { .tmuxPane($0) }
            // tmux外のAIプロセスを "command cwd terminal"・端末名・行テキストで fuzzy フィルタ
            items += aiProcessCache.filter { process in
                let item = SearchItem.aiProcess(process)
                let searchable = "\(process.command) \(process.workingDirectory) \(process.terminalAppName ?? "")"
                let texts = [searchable, process.terminalAppName ?? "", item.rowText(prLabel: prLabel(for: item))]
                return BookmarkSearcher.score(texts: texts, query: query) != nil
            }.map { .aiProcess($0) }
            // クエリあり: lowPriority を末尾に移動（ショートカット番号の連続性維持）
            items = items.filter { !$0.lowPriority } + items.filter { $0.lowPriority }
        }

        #if DEBUG
        let itemDebugLog = items.enumerated().map { (i, item) in
            "[\(i)] \(item.debugLabel) lowPriority=\(item.lowPriority)"
        }.joined(separator: "\n")
        NSLog("[FocusBM][updateItems] query='\(query)' count=\(items.count)\n\(itemDebugLog)")
        #endif

        searchItems = items
        // Why: mainListAssignments.count で clamp。理由: selectedIndex はメインリストのみを追跡する新契約
        if selectedIndex >= mainListAssignments.count {
            selectedIndex = max(0, mainListAssignments.count - 1)
        }

        // 候補が1件 + クエリ非空 + 設定ON → ディレイ後にハイライト → 自動実行
        if allowAutoExecute || searchItems.count != 1 {
            cancelPendingAutoExecute()
        }
        if allowAutoExecute,
           searchItems.count == 1,
           !query.isEmpty,
           appSettings?.autoExecuteOnSingleResult == true {
            let delay = appSettings?.autoExecuteDelay ?? 0.3
            let generation = autoExecuteGeneration
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard generation == self.autoExecuteGeneration else { return }
                withAnimation(.easeIn(duration: 0.15)) {
                    self.isAutoExecuteHighlighted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self,
                          generation == self.autoExecuteGeneration,
                          self.isAutoExecuteHighlighted else { return }
                    self.onAutoExecute?()
                }
            }
            autoExecuteWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    /// ショートカット数字の割り当て: noShortcut=true のアイテムを除いて 1-9 を順に割り当て
    /// ショートカットラベルの割り当て:
    /// - noShortcut=true → nil
    /// - YAML shortcut 指定あり → そのラベル（重複は先着優先で nil）
    /// - shortcut 未指定 → "1"〜"9" を自動割り当て（YAML 予約済みラベルはスキップ）
    var shortcutAssignments: [(item: SearchItem, label: String?)] {
        // YAML 指定ラベルのセット（自動割り当て時にスキップするため事前収集）
        var reservedLabels: Set<String> = []
        for item in searchItems {
            if case .bookmark(let bm) = item,
               !(bm.noShortcut ?? false),
               let s = bm.shortcut {
                reservedLabels.insert(s)
            }
        }

        var usedYAMLLabels: Set<String> = []  // 重複 YAML shortcut の先着優先制御
        var autoNumber = 1
        // Why: appSettings?.showAIAgentShortcut == false（明示 false）時のみスキップ。
        // nil は「未指定＝従来挙動（AI 行にも番号付与）」として true 相当に扱う。
        let skipAIAgentShortcut = appSettings?.showAIAgentShortcut == false

        return searchItems.map { item in
            // noShortcut が true → ラベルなし
            if item.noShortcut { return (item, nil) }

            // Why: The toggle-repress item goes to the shortcut bar (empty query), so it must not consume an auto number.
            if query.isEmpty && item.id == toggleRepressTarget?.id && !isYAMLShortcutBookmark(item) {
                return (item, nil)
            }

            // AI エージェント行のショートカット抑止（autoNumber を消費しない）
            if skipAIAgentShortcut && item.isAIAgent {
                return (item, nil)
            }

            // YAML 指定ショートカット
            if case .bookmark(let bm) = item, let s = bm.shortcut {
                if usedYAMLLabels.contains(s) {
                    return (item, nil)  // 重複: 後続は nil
                }
                usedYAMLLabels.insert(s)
                return (item, s)
            }

            // 自動割り当て "1"〜"9"（YAML 予約済みラベルをスキップ）
            while autoNumber <= 9 && reservedLabels.contains(String(autoNumber)) {
                autoNumber += 1
            }
            guard autoNumber <= 9 else { return (item, nil) }
            let label = String(autoNumber)
            autoNumber += 1
            return (item, label)
        }
    }

    // Why: shortcutAssignments を分解せず filter で分離。理由: 既存ロジックの変更最小化
    /// YAML shortcut 指定があるアイテムのみ（ショートカットバー表示用）
    var shortcutBarItems: [(item: SearchItem, label: String)] {
        var result = shortcutAssignments.compactMap { pair -> (item: SearchItem, label: String)? in
            guard let label = pair.label,
                  case .bookmark(let bm) = pair.item,
                  bm.shortcut != nil else { return nil }
            return (item: pair.item, label: label)
        }
        // The toggle-repress bookmark is shown as a chip labeled with the togglePanel hotkey.
        if let target = toggleRepressTarget,
           !isYAMLShortcutBookmark(target),
           searchItems.contains(where: { $0.id == target.id }) {
            result.append((item: target, label: Self.hotkeyDisplayString(appSettings?.hotkey.togglePanel ?? "cmd+ctrl+b")))
        }
        return result
    }

    private func isYAMLShortcutBookmark(_ item: SearchItem) -> Bool {
        if case .bookmark(let bm) = item, bm.shortcut != nil { return true }
        return false
    }

    /// "ctrl+," -> "⌃," (modifier order follows the macOS convention ⌃⌥⇧⌘)
    static func hotkeyDisplayString(_ hotkey: String) -> String {
        let parsed = HotkeyParser.parse(hotkey)
        var out = ""
        if parsed.modifiers.contains(.control) { out += "⌃" }
        if parsed.modifiers.contains(.option) { out += "⌥" }
        if parsed.modifiers.contains(.shift) { out += "⇧" }
        if parsed.modifiers.contains(.command) { out += "⌘" }
        return out + parsed.key.uppercased()
    }

    /// shortcutBarItems を除いたメインリスト用アサインメント
    var mainListAssignments: [(item: SearchItem, label: String?)] {
        // Why: Instead of keeping bar items out of the list while filtering, adopted listing every match.
        // Reason: the bar is hidden when query is non-empty, so excluded YAML-shortcut matches were unreachable.
        if !query.isEmpty {
            guard let labels = BookmarkSearcher.filteredNumberLabels(query: query, count: searchItems.count) else {
                return shortcutAssignments
            }
            return zip(searchItems, labels).map { (item: $0, label: $1) }
        }
        let barItemIds = Set(shortcutBarItems.map { $0.item.id })
        return shortcutAssignments.filter { !barItemIds.contains($0.item.id) }
    }

    /// 数字キー → searchItems 配列インデックスの逆引きマップ
    /// 数字キー → searchItems 配列インデックスの逆引きマップ（SearchPanel 後方互換; labelToIndex から派生）
    var digitToIndex: [Int: Int] {
        var result: [Int: Int] = [:]
        for (label, index) in labelToIndex {
            if let d = Int(label) { result[d] = index }
        }
        return result
    }

    /// ラベル文字列 → searchItems 配列インデックスの逆引きマップ
    var labelToIndex: [String: Int] {
        // Why: shortcutAssignments.enumerated() ではなく mainListAssignments.enumerated()。
        // 理由: selectedIndex が mainListAssignments ベースに変更されたため、
        // labelToIndex もメインリストのインデックスを返す必要がある。
        var result: [String: Int] = [:]
        for (arrayIndex, pair) in mainListAssignments.enumerated() {
            if let l = pair.label { result[l] = arrayIndex }
        }
        return result
    }

    func moveUp() {
        selectedIndex = clampIndex(selectedIndex - 1)
    }

    func moveDown() {
        selectedIndex = clampIndex(selectedIndex + 1)
    }

    /// 数字キーに対応する selectedIndex を設定する。成功時 true を返す
    func selectByDigit(_ number: Int) -> Bool {
        guard let index = digitToIndex[number] else { return false }
        selectedIndex = index
        return true
    }

    // MARK: - Private helpers

    /// selectedIndex を mainListAssignments の範囲 [0, count-1] にクランプする
    private func clampIndex(_ index: Int) -> Int {
        let count = mainListAssignments.count
        guard count > 0 else { return 0 }
        return max(0, min(index, count - 1))
    }

    /// 選択中の SearchItem を返す（メインスレッドでのスナップショット取得用）。
    /// Why: restore はバックグラウンドで実行するため、VM 状態への参照は
    ///      パネル close 前にメインスレッドで確定させる必要がある。
    func selectedItem() -> SearchItem? {
        guard selectedIndex >= 0, selectedIndex < mainListAssignments.count else { return nil }
        return mainListAssignments[selectedIndex].item
    }

    /// togglePanel ホットキー再押下で実行する指定ブックマーク（executeOnToggleRepress: true の先頭1件）。
    /// Why: searchItems ではなく bookmarks を直接引く。理由: 検索クエリや shortcutBar への
    ///      振り分けに左右されず、再押下の実行対象を常に一意に固定するため。
    var toggleRepressTarget: SearchItem? {
        guard let bm = bookmarks.first(where: { $0.executeOnToggleRepress == true }) else { return nil }
        return .bookmark(bm)
    }

    var openSessionPullRequestHotkey: String {
        appSettings?.hotkey.openSessionPullRequest ?? DEFAULT_OPEN_PR_HOTKEY
    }

    var previewHoveredAgentHotkey: String {
        appSettings?.hotkey.previewHoveredAgent ?? DEFAULT_PREVIEW_HOVERED_HOTKEY
    }

    var previewAllAgentsHotkey: String {
        appSettings?.hotkey.previewAllAgents ?? DEFAULT_PREVIEW_ALL_HOTKEY
    }

    func previewItem(forDigit number: Int) -> SearchItem? {
        guard let preview = screenPreview else { return nil }
        let captures = preview.captures
        guard number >= 1, number <= captures.count else { return nil }
        let id = captures[number - 1].id
        return searchItems.first { $0.id == id }
    }

    func previewTargetItem() -> SearchItem? {
        if let hovered = hoveredIndex,
           hovered >= 0,
           hovered < mainListAssignments.count {
            let item = mainListAssignments[hovered].item
            if item.isAIAgent { return item }
        }
        if let item = selectedItem(), item.isAIAgent { return item }
        return nil
    }

    @discardableResult
    func dismissScreenPreview() -> Bool {
        stopScreenPreviewRefresh()
        guard screenPreview != nil else { return false }
        screenPreview = nil
        promptTargetIndex = nil
        isPromptFieldFocused = false
        return true
    }

    @discardableResult
    func showHoveredAgentPreview() -> Bool {
        guard let item = previewTargetItem(), let capture = captureScreen(for: item) else { return false }
        screenPreview = .single(AgentScreenCapture(
            id: capture.id, title: capture.title, text: capture.text, index: 1, status: capture.status))
        promptTargetIndex = 1
        promptError = nil
        isPromptFieldFocused = true
        startScreenPreviewRefresh()
        return true
    }

    var promptTargetID: String? {
        guard let captures = screenPreview?.captures,
              let index = promptTargetIndex,
              index >= 1, index <= captures.count else { return nil }
        return captures[index - 1].id
    }

    /// Modifier that picks a tiled prompt target (settings.previewTargetModifier, default cmd).
    var promptTargetFlags: NSEvent.ModifierFlags {
        appSettings?.previewTargetModifier == .ctrl ? .control : .command
    }

    /// Modifier+N on a tiled preview: retarget the prompt to tile N and focus the field, keeping the draft.
    @discardableResult
    func setPromptTarget(_ number: Int, flags: NSEvent.ModifierFlags) -> Bool {
        guard flags == promptTargetFlags,
              let preview = screenPreview, preview.isTiled,
              number >= 1, number <= preview.captures.count else { return false }
        promptTargetIndex = number
        isPromptFieldFocused = true
        return true
    }

    /// Esc while typing in a tiled preview returns to tile navigation instead of closing it.
    func blurTiledPromptField() -> Bool {
        guard isPromptFieldFocused, screenPreview?.isTiled == true else { return false }
        isPromptFieldFocused = false
        return true
    }

    func sendPromptToPreview() {
        let text = promptDraft
        guard let paneID = promptTargetID,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let sender = promptSender
        promptSendQueue.async { [weak self] in
            let result = Result { try sender(paneID, text) }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.promptError = nil
                    // Why: Clear only the sent body so text typed while tmux was running is not lost.
                    if self.promptDraft == text { self.promptDraft = "" }
                case .failure(let error):
                    self.promptError = error.localizedDescription
                }
            }
        }
    }

    @discardableResult
    func showAllAgentPreviews() -> Bool {
        let captures = searchItems.compactMap { item -> AgentScreenCapture? in
            guard item.isAIAgent else { return nil }
            return captureScreen(for: item)
        }
        .enumerated()
        .map { offset, capture in
            AgentScreenCapture(
                id: capture.id, title: capture.title, text: capture.text, index: offset + 1, status: capture.status
            )
        }
        guard !captures.isEmpty else { return false }
        screenPreview = captures.count == 1 ? .single(captures[0]) : .tiled(captures)
        promptTargetIndex = captures.count == 1 ? 1 : nil
        promptError = nil
        startScreenPreviewRefresh()
        return true
    }

    private func captureScreen(for item: SearchItem) -> AgentScreenCapture? {
        switch item {
        case .tmuxPane(let pane):
            let text = paneScreenCaptureProvider(pane.paneId)
                ?? pane.statusContent
                ?? ""
            return AgentScreenCapture(
                id: pane.paneId,
                title: pane.displayNameWithoutEmoji,
                text: normalizedCaptureText(text),
                status: pane.agentStatus
            )
        case .aiProcess(let process):
            return AgentScreenCapture(
                id: "aiprocess-\(process.pid)",
                title: process.title,
                text: "tmux ペインがないため画面キャプチャできません"
            )
        default:
            return nil
        }
    }

    // Why: tmux capture-pane pads the pane with blank rows below the prompt.
    private func trimTrailingBlankLines(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while let last = lines.last, ANSIText.stripped(last).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private func normalizedCaptureText(_ text: String) -> String {
        let trimmed = trimTrailingBlankLines(text)
        let body = ANSIText.stripped(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? "キャプチャできませんでした" : trimmed
    }

    func canResolveSessionPullRequest(for item: SearchItem) -> Bool {
        switch item {
        case .aiProcess(let process):
            return sessionPullRequestResolver.supports(command: process.command)
        case .tmuxPane(let pane):
            let command = pane.resolvedNodeCommand ?? pane.command
            return sessionPullRequestResolver.supports(command: command)
        default:
            return false
        }
    }

    func sessionPullRequestURL(for item: SearchItem) -> URL? {
        switch item {
        case .aiProcess(let process):
            return sessionPullRequestResolver.resolveURL(for: process)
        case .tmuxPane(let pane):
            let command = pane.resolvedNodeCommand ?? pane.command
            return sessionPullRequestResolver.resolveURL(
                for: command,
                workingDirectory: pane.currentPath
            )
        default:
            return nil
        }
    }

    // Why: SearchItem から直接 ActivationTarget を取得するメソッド。
    // selectedItem() は selectedIndex 経由だが、shortcutBarItems はメインリスト外のため
    // selectedIndex を使えない。ShortcutBarView と P6 のアルファベットキーハンドラが使用する。
    func activationTarget(for item: SearchItem) -> ActivationTarget? {
        switch item {
        case .bookmark(let bookmark):
            do {
                let target = try BookmarkRestorer.restoreAndGetTarget(bookmark)
                return target
            } catch {
                print("Restore failed: \(error)")
                return nil
            }
        case .floatingWindow(let entry):
            FloatingWindowProvider.focus(entry: entry)
            return .pid(entry.pid)
        case .tmuxPane(let pane):
            do {
                let target = try TmuxProvider.focusPane(pane, settings: appSettings)
                return target
            } catch {
                print("TmuxProvider.focusPane failed: \(error)")
                return nil
            }
        case .aiProcess(let proc):
            guard let bundleId = proc.terminalBundleId else { return nil }
            return .bundleId(bundleId, appName: proc.terminalAppName ?? "Terminal")
        }
    }

    deinit {
        screenPreviewTimer?.cancel()
        agentStatusTimer?.cancel()
    }
}
