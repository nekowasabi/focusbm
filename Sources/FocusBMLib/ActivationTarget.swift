import AppKit
import CInputSource

/// panel.close() 後に実行するアプリアクティベーション情報。
/// osascript プロセス起動を避け、NSRunningApplication.activate を使用する。
public enum ActivationTarget {
    /// bundleId でアプリを検索して activate
    case bundleId(String, appName: String)
    /// PID でアプリを activate
    case pid(pid_t)
    /// アクティベーション不要
    case none

    public func activate(switchToASCII: Bool = false) {
        switch self {
        case .bundleId(let bid, let appName):
            if let app = AppleScriptBridge.findRunningApp(bundleIdPattern: bid, appName: appName) {
                app.activate(options: .activateIgnoringOtherApps)
            }
        case .pid(let pid):
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        case .none:
            return
        }
        // Why: macOS restores the per-app input source after activation, so switch once that has settled.
        if switchToASCII {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { CInputSource_switchToASCII() }
        }
    }
}
