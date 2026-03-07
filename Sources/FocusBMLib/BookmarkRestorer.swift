import Foundation

public struct BookmarkRestorer {
    /// activate を実行せずに ActivationTarget を返す。
    /// browser パスは AppleScript 内で activate が行われるため .bundleId を返す。
    public static func restoreAndGetTarget(_ bookmark: Bookmark) throws -> ActivationTarget {
        switch bookmark.state {
        case .browser(let urlPattern, _, let tabIndex, let urlPrefix):
            // browser: AppleScript がタブ切替+activate を一括実行（分離不可）
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
                bundleId: resolvedBundleId, url: urlPattern,
                tabIndex: tabIndex, urlPrefix: urlPrefix
            )
            // browser は AppleScript 内で activate 済みだが、close 後に再 activate が必要
            return .bundleId(resolvedBundleId, appName: bookmark.appName)
        case .app:
            // app: activate を実行せず、ターゲット情報のみ返す
            if let bid = bookmark.bundleIdPattern {
                return .bundleId(bid, appName: bookmark.appName)
            } else if let app = AppleScriptBridge.findRunningApp(bundleIdPattern: nil, appName: bookmark.appName),
                      let bid = app.bundleIdentifier {
                return .bundleId(bid, appName: bookmark.appName)
            }
            // アプリが見つからない場合は AppleScript で起動して activate
            try AppleScriptBridge.activateApp(
                bundleIdPattern: bookmark.bundleIdPattern,
                appName: bookmark.appName
            )
            return .none
        case .floatingWindows:
            return .none
        }
    }
}
