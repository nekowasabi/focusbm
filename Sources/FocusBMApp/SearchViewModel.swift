import Foundation
import Combine
import AppKit
import FocusBMLib

class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { updateItems() }
    }
    @Published var bookmarks: [Bookmark] = []
    @Published var searchItems: [SearchItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isActive: Bool = false
    @Published var listFontSize: Double? = nil
    @Published var fontName: String? = nil

    // パネル表示時に enumerate() の結果をキャッシュ（キーストロークごとの AX IPC を回避）
    private var floatingWindowCache: [String: [FloatingWindowEntry]] = [:]
    private var tmuxPaneCache: [TmuxPane] = []
    private var aiProcessCache: [ProcessProvider.AIProcess] = []
    private(set) var showTmuxAgents: Bool = true
    private(set) var appSettings: AppSettings? = nil
    private var refreshGeneration: Int = 0
    /// 自動実行ハイライト中かどうか（実行直前の視覚フィードバック用）
    @Published var isAutoExecuteHighlighted: Bool = false
    /// 候補が1件になったとき呼ばれるコールバック（SearchPanel が設定）
    var onAutoExecute: (() -> Void)?
    /// 自動実行の遅延タイマー（キー入力ごとにキャンセル＆再スケジュール）
    private var autoExecuteWorkItem: DispatchWorkItem?

    /// YAML を読み込んで bookmarks を更新する。AX API は呼ばない（起動時にも安全）。
    func load() {
        let store = BookmarkStore.loadYAML()
        bookmarks = store.bookmarks
        appSettings = store.settings
        listFontSize = store.settings?.listFontSize
        fontName = store.settings?.fontName
        showTmuxAgents = store.settings?.showTmuxAgents ?? true
        updateItems()
    }

    /// パネル表示時に呼ぶ。AX API でキャッシュを更新してから候補リストを再構築する。
    func refreshForPanel() {
        cacheFloatingWindows()
        loadTmuxPanes()
        loadAIProcesses()
        updateItems()
    }

    /// パネル表示後にバックグラウンドでデータを更新する非同期版
    func refreshForPanelAsync() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let currentBookmarks = bookmarks
        let currentShowTmuxAgents = showTmuxAgents
        let currentSettings = appSettings

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // floatingWindows (AX API)
            var windowCache: [String: [FloatingWindowEntry]] = [:]
            for bookmark in currentBookmarks {
                if case .floatingWindows = bookmark.state {
                    windowCache[bookmark.appName] = FloatingWindowProvider.enumerate(appName: bookmark.appName)
                }
            }

            // tmux panes
            var tmuxPanes: [TmuxPane] = []
            if currentShowTmuxAgents {
                tmuxPanes = (try? TmuxProvider.listAIAgentPanes(settings: currentSettings)) ?? []
            }

            // AI processes
            var aiProcesses: [ProcessProvider.AIProcess] = []
            if currentShowTmuxAgents {
                aiProcesses = ProcessProvider.listNonTmuxAIProcesses()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // レースコンディション対策: 古い世代の結果は破棄
                guard generation == self.refreshGeneration else { return }
                self.floatingWindowCache = windowCache
                self.tmuxPaneCache = tmuxPanes
                self.aiProcessCache = aiProcesses
                self.updateItems()
            }
        }
    }

    /// バックグラウンドサービスから参照用
    var currentAppSettings: AppSettings? { appSettings }
    var currentShowTmuxAgents: Bool { showTmuxAgents }

    /// バックグラウンドサービスからキャッシュを更新（パネル非表示時のプリウォーム用）
    /// updateItems() は呼ばない — パネル表示時に load() → updateItems() で反映される
    func applyBackgroundCache(tmuxPanes: [TmuxPane], aiProcesses: [ProcessProvider.AIProcess]) {
        tmuxPaneCache = tmuxPanes
        aiProcessCache = aiProcesses
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
    private func loadTmuxPanes() {
        guard showTmuxAgents else {
            tmuxPaneCache = []
            return
        }
        tmuxPaneCache = (try? TmuxProvider.listAIAgentPanes(settings: appSettings)) ?? []
    }

    /// tmux外で実行中のAIエージェントプロセスをパネル表示時に1回だけ取得してキャッシュ
    /// settings.showTmuxAgents が false の場合はスキップ
    private func loadAIProcesses() {
        guard showTmuxAgents else {
            aiProcessCache = []
            return
        }
        aiProcessCache = ProcessProvider.listNonTmuxAIProcesses()
    }

    func updateItems() {
        var items: [SearchItem] = []

        if query.isEmpty {
            // クエリなし: YAML 順序を維持（floatingWindows と通常ブックマークを混在）
            for bookmark in bookmarks {
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
            // tmux ペインを displayName で fuzzy フィルタ
            items += tmuxPaneCache.filter {
                BookmarkSearcher.fuzzyScore(text: $0.displayName, query: query) != nil
            }.map { .tmuxPane($0) }
            // tmux外のAIプロセスを displayName で fuzzy フィルタ
            items += aiProcessCache.filter {
                let searchable = "\($0.command) \($0.workingDirectory) \($0.terminalAppName ?? "")"
                return BookmarkSearcher.fuzzyScore(text: searchable, query: query) != nil
            }.map { .aiProcess($0) }
        }

        searchItems = items
        if selectedIndex >= searchItems.count {
            selectedIndex = max(0, searchItems.count - 1)
        }

        // 候補が1件 + クエリ非空 + 設定ON → ディレイ後にハイライト → 自動実行
        autoExecuteWorkItem?.cancel()
        autoExecuteWorkItem = nil
        isAutoExecuteHighlighted = false
        if searchItems.count == 1,
           !query.isEmpty,
           appSettings?.autoExecuteOnSingleResult == true {
            let delay = appSettings?.autoExecuteDelay ?? 0.3
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isAutoExecuteHighlighted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self, self.isAutoExecuteHighlighted else { return }
                    self.onAutoExecute?()
                }
            }
            autoExecuteWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveDown() {
        if selectedIndex < searchItems.count - 1 {
            selectedIndex += 1
        }
    }

    func restoreSelected() -> Bool {
        guard selectedIndex >= 0, selectedIndex < searchItems.count else { return false }
        let item = searchItems[selectedIndex]
        switch item {
        case .bookmark(let bookmark):
            do {
                try BookmarkRestorer.restore(bookmark)
                return true
            } catch {
                return false
            }
        case .floatingWindow(let entry):
            FloatingWindowProvider.focus(entry: entry)
            return true
        case .tmuxPane(let pane):
            do {
                try TmuxProvider.focusPane(pane, settings: appSettings)
                return true
            } catch {
                return false
            }
        case .aiProcess(let proc):
            if let bundleId = proc.terminalBundleId {
                do {
                    try AppleScriptBridge.activateApp(bundleIdPattern: bundleId, appName: proc.terminalAppName ?? "Terminal")
                    return true
                } catch {
                    return false
                }
            }
            return false
        }
    }
}
