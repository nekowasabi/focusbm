import Foundation
import Combine
import AppKit
import SwiftUI
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
            // tmux ペインを displayName で fuzzy フィルタ
            items += tmuxPaneCache.filter {
                BookmarkSearcher.fuzzyScore(text: $0.displayName, query: query) != nil
            }.map { .tmuxPane($0) }
            // tmux外のAIプロセスを displayName で fuzzy フィルタ
            items += aiProcessCache.filter {
                let searchable = "\($0.command) \($0.workingDirectory) \($0.terminalAppName ?? "")"
                return BookmarkSearcher.fuzzyScore(text: searchable, query: query) != nil
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
        autoExecuteWorkItem?.cancel()
        autoExecuteWorkItem = nil
        isAutoExecuteHighlighted = false
        if searchItems.count == 1,
           !query.isEmpty,
           appSettings?.autoExecuteOnSingleResult == true {
            let delay = appSettings?.autoExecuteDelay ?? 0.3
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                withAnimation(.easeIn(duration: 0.15)) {
                    self.isAutoExecuteHighlighted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self, self.isAutoExecuteHighlighted else { return }
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

        return searchItems.map { item in
            // noShortcut が true → ラベルなし
            if item.noShortcut { return (item, nil) }

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
        shortcutAssignments.compactMap { pair in
            guard let label = pair.label,
                  case .bookmark(let bm) = pair.item,
                  bm.shortcut != nil else { return nil }
            return (item: pair.item, label: label)
        }
    }

    /// shortcutBarItems を除いたメインリスト用アサインメント
    var mainListAssignments: [(item: SearchItem, label: String?)] {
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
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveDown() {
        // Why: mainListAssignments を直接参照。理由: selectedIndex はメインリストのみを追跡する新契約
        if selectedIndex < mainListAssignments.count - 1 {
            selectedIndex += 1
        }
    }

    func restoreSelected() -> ActivationTarget? {
        // Why: mainListAssignments[selectedIndex].item を参照。理由: selectedIndex はメインリストのみを追跡する新契約
        guard selectedIndex >= 0, selectedIndex < mainListAssignments.count else { return nil }
        let item = mainListAssignments[selectedIndex].item
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
            // AXRaise + activate は focus() 内で完了済み。
            // ただし close 後の再 activate のため PID を返す
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

    // Why: SearchItem から直接 ActivationTarget を取得するメソッド。
    // restoreSelected() は selectedIndex 経由だが、shortcutBarItems はメインリスト外のため
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
}
