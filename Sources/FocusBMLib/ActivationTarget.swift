import AppKit

/// panel.close() 後に実行するアプリアクティベーション情報。
/// osascript プロセス起動を避け、NSRunningApplication.activate を使用する。
public enum ActivationTarget {
    /// NSRunningApplication で直接 activate
    case runningApp(NSRunningApplication)
    /// bundleId でアプリを検索して activate
    case bundleId(String, appName: String)
    /// PID でアプリを activate
    case pid(pid_t)
    /// アクティベーション不要
    case none

    public func activate() {
        switch self {
        case .runningApp(let app):
            app.activate(options: .activateIgnoringOtherApps)
        case .bundleId(let bid, let appName):
            if let app = AppleScriptBridge.findRunningApp(bundleIdPattern: bid, appName: appName) {
                app.activate(options: .activateIgnoringOtherApps)
            }
        case .pid(let pid):
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        case .none:
            break
        }
    }
}
