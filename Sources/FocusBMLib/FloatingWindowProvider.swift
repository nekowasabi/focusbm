import CoreGraphics
import ApplicationServices
import AppKit

public struct FloatingWindowEntry: Identifiable {
    public let id: String           // "alter-search-the-web-hello"
    public let appName: String      // "Alter"
    public let windowTitle: String  // "Search the web - Hello"
    public let displayName: String  // "Alter - Search the web - Hello"
    public let pid: pid_t
}

public struct FloatingWindowProvider {
    /// entry で指定した特定ウィンドウにフォーカスする。
    /// pid + windowTitle で一致するウィンドウを AXRaise してからアプリを activate する。
    public static func focus(entry: FloatingWindowEntry) {
        let appElement = AXUIElementCreateApplication(entry.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else {
            // フォールバック: アプリをアクティブにするだけ
            NSRunningApplication(processIdentifier: entry.pid)?.activate(options: .activateIgnoringOtherApps)
            return
        }

        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            guard let title = titleRef as? String, title == entry.windowTitle else { continue }

            // 対象ウィンドウを前面に raise してフォーカス
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            break
        }

        // raise の後に app を activate（順序が重要）
        NSRunningApplication(processIdentifier: entry.pid)?.activate(options: .activateIgnoringOtherApps)
    }

    /// appName に一致するアプリの floating windows を CGWindowList + AXUIElement で列挙する。
    /// Accessibility 権限が必要。権限がない場合は空配列を返す。
    public static func enumerate(appName: String) -> [FloatingWindowEntry] {
        let opts = CGWindowListOption(arrayLiteral: .optionAll, .excludeDesktopElements)
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        // appName が一致する pid を収集（floating layer のみ）
        let pids: Set<pid_t> = Set(list.compactMap { window -> pid_t? in
            guard (window[kCGWindowOwnerName as String] as? String) == appName,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer > 0 && layer < 20
            else { return nil }
            return window[kCGWindowOwnerPID as String] as? Int32
        })

        // AXUIElement でウィンドウタイトルを取得
        var entries: [FloatingWindowEntry] = []
        for pid in pids {
            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement]
            else { continue }

            for window in windows {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                guard let title = titleRef as? String, !title.isEmpty else { continue }

                let safeId = "\(appName.lowercased())-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
                entries.append(FloatingWindowEntry(
                    id: safeId,
                    appName: appName,
                    windowTitle: title,
                    displayName: "\(appName) - \(title)",
                    pid: pid
                ))
            }
        }
        return entries
    }
}
