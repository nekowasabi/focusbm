import Foundation
import Combine
import FocusBMLib

class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { filterBookmarks() }
    }
    @Published var bookmarks: [Bookmark] = []
    @Published var filtered: [Bookmark] = []
    @Published var selectedIndex: Int = 0
    @Published var isActive: Bool = false
    @Published var listFontSize: Double? = nil

    func load() {
        let store = BookmarkStore.loadYAML()
        bookmarks = store.bookmarks
        listFontSize = store.settings?.listFontSize
        filterBookmarks()
    }

    func filterBookmarks() {
        filtered = BookmarkSearcher.filter(bookmarks: bookmarks, query: query)
        if selectedIndex >= filtered.count {
            selectedIndex = max(0, filtered.count - 1)
        }
    }

    func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveDown() {
        if selectedIndex < filtered.count - 1 {
            selectedIndex += 1
        }
    }

    func restoreSelected() -> Bool {
        guard selectedIndex >= 0, selectedIndex < filtered.count else { return false }
        let bookmark = filtered[selectedIndex]
        do {
            try BookmarkRestorer.restore(bookmark)
            return true
        } catch {
            return false
        }
    }
}
