import AppKit
import UniformTypeIdentifiers

/// アプリ名からアイコン画像を取得・キャッシュするプロバイダ
public final class AppIconProvider: @unchecked Sendable {

    public static let shared = AppIconProvider()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    /// アプリを検索するディレクトリ（優先順）
    private static let searchPaths: [String] = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
    ]

    public init() {}

    /// アプリ名に対応する 20×20 のアイコンを返す。
    /// 取得失敗時はシステムのデフォルトアイコンを返す（nil にはならない）。
    public func icon(forAppName appName: String) -> NSImage {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[appName] {
            return cached
        }

        let image = resolveIcon(forAppName: appName)
        cache[appName] = image
        return image
    }

    // MARK: - Private

    private func resolveIcon(forAppName appName: String) -> NSImage {
        let fm = FileManager.default
        let ws = NSWorkspace.shared

        let candidates = [appName, appName + ".app"]

        for dir in Self.searchPaths {
            for name in candidates {
                let path = (dir as NSString).appendingPathComponent(name)
                if fm.fileExists(atPath: path) {
                    let img = ws.icon(forFile: path)
                    img.size = NSSize(width: 20, height: 20)
                    return img
                }
            }
        }

        // フォールバック: .app タイプのデフォルトアイコン（macOS 12+）
        let fallback = ws.icon(for: UTType.applicationBundle)
        fallback.size = NSSize(width: 20, height: 20)
        return fallback
    }
}
