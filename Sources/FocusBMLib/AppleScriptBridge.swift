import Foundation
import AppKit

public enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case noResult
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "AppleScript error: \(msg)"
        case .noResult: return "AppleScript returned no result"
        case .timedOut: return "AppleScript execution timed out"
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

    /// osascript を同期実行する。timeout 秒以内に終了しない場合はプロセスを強制終了して
    /// AppleScriptError.timedOut を投げる。
    /// Why: waitUntilExit() 単独では、対象アプリ（Chrome 等）が Apple Event に応答しない場合に
    ///      無期限ブロックし、残留 osascript が Apple Event トランザクションを掴んだまま
    ///      対象アプリの終了・再起動まで阻害するため。
    public static func run(_ script: String, timeout: TimeInterval = 5.0) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }

        // Why: パイプ読み取りを終了待ちの前に開始する。一括タブ取得の出力が
        //      パイプバッファ（64KB）を超えると、読み手不在では osascript 側が書き込みでブロックするため
        var outData = Data()
        var errData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        try process.run()

        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if done.wait(timeout: .now() + 1.0) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
            }
            throw AppleScriptError.timedOut
        }
        readGroup.wait()

        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errOutput = String(data: errData, encoding: .utf8)?
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
        return .browser(urlPattern: url, title: title, tabIndex: tabIndex, urlPrefix: nil)
    }

    /// アプリをアクティブにする（bundleIdPattern が nil の場合は appName でフォールバック）
    /// 未起動の場合は open コマンドで起動を試みる
    public static func activateApp(bundleIdPattern: String?, appName: String) throws {
        if let app = findRunningApp(bundleIdPattern: bundleIdPattern, appName: appName),
           let bid = app.bundleIdentifier {
            let script = "tell application id \"\(escapeForAppleScript(bid))\" to activate"
            _ = try run(script)
        } else {
            // 未起動: open で起動を試みる
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            if let pattern = bundleIdPattern {
                process.arguments = ["-b", pattern]
            } else {
                process.arguments = ["-a", appName]
            }
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let target = bundleIdPattern ?? appName
                throw AppleScriptError.executionFailed("Failed to open app: \(target)")
            }
        }
    }

    /// restoreBrowserTab / switchToTabByShortcut 内部用: 確定した bundleId で起動
    private static func activateApp(bundleId: String) throws {
        try activateApp(bundleIdPattern: bundleId, appName: "")
    }

    /// bundleIdPattern（正規表現対応）または appName でアプリを検索する
    /// bundleIdPattern が nil の場合は localizedName の contains 検索にフォールバック
    public static func findRunningApp(bundleIdPattern: String?, appName: String) -> NSRunningApplication? {
        if let pattern = bundleIdPattern {
            // 完全一致（高速パス）
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: pattern).first {
                return app
            }
            // 正規表現マッチ
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = NSWorkspace.shared.runningApplications.filter { app in
                    guard let bid = app.bundleIdentifier else { return false }
                    return regex.firstMatch(in: bid, range: NSRange(bid.startIndex..., in: bid)) != nil
                }
                if let match = matches.first { return match }
            }
        }
        // appName フォールバック（localizedName の case-insensitive contains 検索）
        guard !appName.isEmpty else { return nil }
        let name = appName.lowercased()
        let matches = NSWorkspace.shared.runningApplications.filter { app in
            guard let localName = app.localizedName else { return false }
            return localName.lowercased().contains(name)
        }
        return matches.first
    }

    // AppleScript 文字列リテラル用エスケープ
    static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // ブラウザ: URL でタブを検索してフォーカス（tabIndex があれば優先）
    // Why: 旧実装はタブ1枚ごとに AppleScript ループ内で URL を問い合わせており、
    //      Apple Event がタブ数×ウィンドウ数だけ往復した。Chrome が1回でも応答しないと
    //      osascript ごとハングするため、「一括取得 → Swift 側で照合 → 1回でフォーカス」に変更。
    public static func restoreBrowserTab(bundleId: String, url: String, tabIndex: Int?, urlPrefix: String? = nil) throws {
        let tabURLs: [[String]]
        do {
            tabURLs = try fetchAllTabURLs(bundleId: bundleId)
        } catch {
            // Firefox 等 AppleScript tabs 非対応、または対象ブラウザ無応答（timedOut）。
            // 旧実装のフォールバック順序を踏襲: tabIndex があればショートカット切替、
            // なければ URL オープン、それも無ければアクティブ化のみ。
            if let idx = tabIndex {
                try switchToTabByShortcut(bundleId: bundleId, index: idx)
            } else if !url.isEmpty {
                try openURL(bundleId: bundleId, urlPattern: url)
            } else {
                try activateApp(bundleId: bundleId)
            }
            return
        }

        // urlPrefix が指定されていれば begins with 相当で先に照合
        if let prefix = urlPrefix, !prefix.isEmpty,
           let loc = findTab(in: tabURLs, where: { $0.hasPrefix(prefix) }) {
            try focusTab(bundleId: bundleId, windowIndex: loc.window, tabIndex: loc.tab)
            return
        }

        if let idx = tabIndex {
            if url.isEmpty {
                // tabIndex のみ指定: タブ数が足りる最初のウィンドウで直接タブ切り替え
                if let w = tabURLs.firstIndex(where: { $0.count >= idx }) {
                    try focusTab(bundleId: bundleId, windowIndex: w + 1, tabIndex: idx)
                    return
                }
            } else if let w = tabURLs.firstIndex(where: { $0.count >= idx && $0[idx - 1].contains(url) }) {
                // tabIndex + URL: tabIndex を優先しつつ URL で検証
                try focusTab(bundleId: bundleId, windowIndex: w + 1, tabIndex: idx)
                return
            }
            // 該当なし → Cmd+N ショートカットで代替（旧実装と同じ）
            try switchToTabByShortcut(bundleId: bundleId, index: idx)
            return
        }

        // URL のみでフォールバック検索
        if !url.isEmpty {
            if let loc = findTab(in: tabURLs, where: { $0.contains(url) }) {
                try focusTab(bundleId: bundleId, windowIndex: loc.window, tabIndex: loc.tab)
                return
            }
            try openURL(bundleId: bundleId, urlPattern: url)
            return
        }
        try activateApp(bundleId: bundleId)
    }

    /// 全ウィンドウのタブ URL を一括取得する。戻り値はウィンドウごとの URL 配列（前面順）。
    /// Why: `URL of tabs of every window` は少数の Apple Event 往復でまとめて返るため、
    ///      タブごとの逐次問い合わせと比べてハング確率が桁で下がる。
    static func fetchAllTabURLs(bundleId: String) throws -> [[String]] {
        let escapedBundleId = escapeForAppleScript(bundleId)
        let script = """
        tell application id "\(escapedBundleId)" to set urlLists to URL of tabs of every window
        set out to ""
        repeat with wURLs in urlLists
            set lineText to ""
            repeat with u in wURLs
                try
                    set lineText to lineText & (u as text)
                end try
                set lineText to lineText & tab
            end repeat
            set out to out & lineText & linefeed
        end repeat
        return out
        """
        return parseTabURLOutput(try run(script))
    }

    /// fetchAllTabURLs の出力（行=ウィンドウ、タブ文字区切り=URL）をパースする。
    /// run() が末尾の空白類を trim するため、最終行の末尾タブ・末尾改行は既に除去されている。
    static func parseTabURLOutput(_ output: String) -> [[String]] {
        guard !output.isEmpty else { return [] }
        var lines = output.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return lines.map { line in
            var urls = line.components(separatedBy: "\t")
            if urls.last == "" { urls.removeLast() }
            return urls
        }
    }

    /// 条件に一致する最初のタブ位置を返す（window / tab とも 1-based）
    static func findTab(in tabURLs: [[String]], where predicate: (String) -> Bool) -> (window: Int, tab: Int)? {
        for (w, urls) in tabURLs.enumerated() {
            for (t, url) in urls.enumerated() where predicate(url) {
                return (window: w + 1, tab: t + 1)
            }
        }
        return nil
    }

    /// 指定ウィンドウの指定タブをアクティブ化する（いずれも 1-based）
    private static func focusTab(bundleId: String, windowIndex: Int, tabIndex: Int) throws {
        let escapedBundleId = escapeForAppleScript(bundleId)
        let script = """
        tell application id "\(escapedBundleId)"
            set active tab index of window \(windowIndex) to \(tabIndex)
            activate
        end tell
        """
        _ = try run(script)
    }

    /// urlPattern を補完して `open location` で URL を開く（Firefox・Chrome 共通）。
    /// urlPattern が "https://" 等で始まらない場合は "https://" を補完する。
    private static func openURL(bundleId: String, urlPattern: String) throws {
        let escapedBundleId = escapeForAppleScript(bundleId)
        let fullURL: String
        if urlPattern.hasPrefix("http://") || urlPattern.hasPrefix("https://") {
            fullURL = urlPattern
        } else {
            fullURL = "https://\(urlPattern)"
        }
        let escapedURL = escapeForAppleScript(fullURL)
        let script = """
        tell application id "\(escapedBundleId)"
            open location "\(escapedURL)"
            activate
        end tell
        """
        _ = try run(script)
    }

    /// Cmd+1〜8 で番号指定タブへ、Cmd+9 で最後のタブへ移動する（Firefox 公式ショートカット）。
    /// Chrome/Safari/Brave でも同じショートカットが使えるため汎用的に動作する。
    /// System Events 経由のため Accessibility 権限が必要。
    private static func switchToTabByShortcut(bundleId: String, index: Int) throws {
        let escapedBundleId = escapeForAppleScript(bundleId)
        // Cmd+1〜8 は対応タブ番号へ、Cmd+9 は最後のタブ（Firefox / Chrome 共通仕様）
        let keyStr = index <= 8 ? "\(index)" : "9"
        let script = """
        tell application id "\(escapedBundleId)" to activate
        delay 0.3
        tell application "System Events"
            keystroke "\(keyStr)" using {command down}
        end tell
        """
        do {
            _ = try run(script)
        } catch {
            // System Events 失敗（AX 権限なし等）→ アクティブ化のみ
            try activateApp(bundleId: bundleId)
        }
    }
}
