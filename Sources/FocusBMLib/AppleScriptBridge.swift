import Foundation
import AppKit

public enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case noResult

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "AppleScript error: \(msg)"
        case .noResult: return "AppleScript returned no result"
        }
    }
}

public struct AppleScriptBridge {
    // ブラウザ判定用 bundleId リスト
    public static let browserBundleIds = [
        "com.microsoft.edgemac", "com.google.Chrome",
        "com.brave.Browser", "com.apple.Safari", "org.mozilla.firefox",
    ]

    public static func isBrowser(bundleId: String) -> Bool {
        browserBundleIds.contains(bundleId)
    }

    public static func run(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 && !errOutput.isEmpty {
            throw AppleScriptError.executionFailed(errOutput)
        }
        return output
    }

    // 現在フォーカスされているアプリ名・バンドルID・ウィンドウタイトルを一括取得
    public static func getFrontAppInfo() throws -> (appName: String, bundleId: String, windowTitle: String) {
        let script = """
        tell application "System Events"
            set frontProc to first application process whose frontmost is true
            set frontName to name of frontProc
            set frontBundle to bundle identifier of frontProc
            set winTitle to ""
            try
                tell frontProc
                    set winTitle to name of first window
                end tell
            end try
            return frontName & "|" & frontBundle & "|" & winTitle
        end tell
        """
        let result = try run(script)
        let parts = result.split(separator: "|", maxSplits: 2).map(String.init)
        let appName = parts[0]
        let bundleId = parts.count > 1 ? parts[1] : ""
        let windowTitle = parts.count > 2 ? parts[2] : ""
        return (appName, bundleId, windowTitle)
    }

    // ブラウザ: アクティブタブ情報を取得（タブ数最多のウィンドウを使用）
    public static func getBrowserState(bundleId: String) throws -> AppState {
        // window 1 はポップアップ等が占有することがあるため、
        // タブ数が最も多いウィンドウ（＝メインブラウザウィンドウ）を選択する
        let escapedBundleId = escapeForAppleScript(bundleId)
        let script = """
        tell application id "\(escapedBundleId)"
            set bestWin to missing value
            set maxTabs to 0
            repeat with w in windows
                set tc to count of tabs of w
                if tc > maxTabs then
                    set maxTabs to tc
                    set bestWin to w
                end if
            end repeat
            if bestWin is missing value then set bestWin to window 1
            tell bestWin
                set tabIdx to active tab index
                tell active tab
                    return URL & "|||" & title & "|||" & tabIdx
                end tell
            end tell
        end tell
        """
        let result = try run(script)
        let parts = result.components(separatedBy: "|||")
        let url = parts[0]
        let title = parts.count > 1 ? parts[1] : ""
        let tabIndex = parts.count > 2 ? Int(parts[2]) : nil
        return .browser(urlPattern: url, title: title, tabIndex: tabIndex)
    }

    // アプリをバンドルIDパターンでアクティブにする（正規表現対応、未起動の場合は起動）
    public static func activateApp(bundleId bundleIdPattern: String) throws {
        if let app = findRunningApp(matching: bundleIdPattern),
           let bid = app.bundleIdentifier {
            let script = "tell application id \"\(escapeForAppleScript(bid))\" to activate"
            _ = try run(script)
        } else {
            // 未起動: open -b で起動（正規表現パターンの場合は失敗する可能性あり）
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-b", bundleIdPattern]
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw AppleScriptError.executionFailed("Failed to open app with bundleId: \(bundleIdPattern)")
            }
        }
    }

    // 正規表現パターンマッチ対応のアプリ検索
    private static func findRunningApp(matching pattern: String) -> NSRunningApplication? {
        // 完全一致（高速パス）
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: pattern).first {
            return app
        }
        // 正規表現マッチ
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return NSWorkspace.shared.runningApplications.first { app in
            guard let bid = app.bundleIdentifier else { return false }
            return regex.firstMatch(in: bid, range: NSRange(bid.startIndex..., in: bid)) != nil
        }
    }

    // AppleScript 文字列リテラル用エスケープ
    static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // ブラウザ: URL でタブを検索してフォーカス（tabIndex があれば優先）
    public static func restoreBrowserTab(bundleId: String, url: String, tabIndex: Int?) throws {
        let escapedBundleId = escapeForAppleScript(bundleId)

        // tabIndex のみ指定（URL 空）: 直接タブ切り替え
        if let idx = tabIndex, url.isEmpty {
            let script = """
            tell application id "\(escapedBundleId)"
                repeat with w in windows
                    if (count of tabs of w) >= \(idx) then
                        set active tab index of w to \(idx)
                        activate
                        return "true"
                    end if
                end repeat
                return "false"
            end tell
            """
            let result = try run(script)
            if result == "true" { return }
            throw AppleScriptError.executionFailed("Tab index \(idx) not found")
        }

        // tabIndex + URL: tabIndex を優先しつつ URL で検証
        if let idx = tabIndex {
            let escapedUrl = escapeForAppleScript(url)
            let script = """
            tell application id "\(escapedBundleId)"
                repeat with w in windows
                    if (count of tabs of w) >= \(idx) then
                        if URL of tab \(idx) of w contains "\(escapedUrl)" then
                            set active tab index of w to \(idx)
                            activate
                            return "true"
                        end if
                    end if
                end repeat
                return "false"
            end tell
            """
            if let result = try? run(script), result == "true" {
                return
            }
        }

        // URL でフォールバック検索
        let escapedUrl = escapeForAppleScript(url)
        let script = """
        tell application id "\(escapedBundleId)"
            set found to false
            repeat with w in windows
                set tabList to tabs of w
                repeat with i from 1 to count of tabList
                    if URL of item i of tabList contains "\(escapedUrl)" then
                        set active tab index of w to i
                        set found to true
                        exit repeat
                    end if
                end repeat
                if found then exit repeat
            end repeat
            if found then activate
            return found as text
        end tell
        """
        let result = try run(script)
        if result != "true" {
            throw AppleScriptError.executionFailed("Tab not found for URL: \(url)")
        }
    }
}
