import Foundation

public struct BookmarkRestorer {
    public static func restore(_ bookmark: Bookmark) throws {
        switch bookmark.state {
        case .browser(let urlPattern, _, let tabIndex):
            try AppleScriptBridge.restoreBrowserTab(
                bundleId: bookmark.bundleIdPattern,
                url: urlPattern,
                tabIndex: tabIndex
            )
        case .app:
            try AppleScriptBridge.activateApp(bundleId: bookmark.bundleIdPattern)
        }
    }
}
