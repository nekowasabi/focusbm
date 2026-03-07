import Foundation

public struct BookmarkRestorer {
    public static func restore(_ bookmark: Bookmark) throws {
        switch bookmark.state {
        case .browser(let urlPattern, _, let tabIndex, let urlPrefix):
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
                tabIndex: tabIndex,
                urlPrefix: urlPrefix
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

    /// restore と同じ処理を行うが、activate を実行せずに ActivationTarget を返す。
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
            // アプリが見つからない場合は起動が必要 — 従来の restore を使用
            try restore(bookmark)
            return .none
        case .floatingWindows:
            return .none
        }
    }
}
