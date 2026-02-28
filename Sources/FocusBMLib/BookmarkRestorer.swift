import Foundation

public struct BookmarkRestorer {
    public static func restore(_ bookmark: Bookmark) throws {
        switch bookmark.state {
        case .browser(let urlPattern, _, let tabIndex):
            // bundleIdPattern が nil の場合は実行中アプリの実際の bundleId を取得
            let resolvedBundleId: String
            if let pattern = bookmark.bundleIdPattern {
                resolvedBundleId = pattern
            } else {
                guard let app = AppleScriptBridge.findRunningApp(bundleIdPattern: nil, appName: bookmark.appName),
                      let bid = app.bundleIdentifier else {
                    throw AppleScriptError.executionFailed("Cannot find running browser: \(bookmark.appName)")
                }
                resolvedBundleId = bid
            }
            try AppleScriptBridge.restoreBrowserTab(
                bundleId: resolvedBundleId,
                url: urlPattern,
                tabIndex: tabIndex
            )
        case .app:
            try AppleScriptBridge.activateApp(
                bundleIdPattern: bookmark.bundleIdPattern,
                appName: bookmark.appName
            )
        case .floatingWindows:
            // floatingWindows は SearchItem.floatingWindow 経由で pid 直接 activate するため不使用
            break
        }
    }
}
