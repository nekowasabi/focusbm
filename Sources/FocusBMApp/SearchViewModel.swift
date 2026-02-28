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

    // パネル表示時に enumerate() の結果をキャッシュ（キーストロークごとの AX IPC を回避）
    private var floatingWindowCache: [String: [FloatingWindowEntry]] = [:]

    /// YAML を読み込んで bookmarks を更新する。AX API は呼ばない（起動時にも安全）。
    func load() {
        let store = BookmarkStore.loadYAML()
        bookmarks = store.bookmarks
        listFontSize = store.settings?.listFontSize
        updateItems()
    }

    /// パネル表示時に呼ぶ。AX API でキャッシュを更新してから候補リストを再構築する。
    func refreshForPanel() {
        cacheFloatingWindows()
        updateItems()
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
        }

        searchItems = items
        if selectedIndex >= searchItems.count {
            selectedIndex = max(0, searchItems.count - 1)
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
        }
    }
}
