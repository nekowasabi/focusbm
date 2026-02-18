import Foundation
import Yams

// アプリ固有の状態（Tagged Union で型安全に表現）
public enum AppState: Codable {
    case browser(urlPattern: String, title: String, tabIndex: Int?)
    case app(windowTitle: String)

    private enum CodingKeys: String, CodingKey {
        case type, urlPattern, title, tabIndex, windowTitle
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .browser(let urlPattern, let title, let tabIndex):
            try container.encode("browser", forKey: .type)
            try container.encode(urlPattern, forKey: .urlPattern)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(tabIndex, forKey: .tabIndex)
        case .app(let windowTitle):
            try container.encode("app", forKey: .type)
            try container.encode(windowTitle, forKey: .windowTitle)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "browser":
            let urlPattern = try container.decode(String.self, forKey: .urlPattern)
            let title = try container.decode(String.self, forKey: .title)
            let tabIndex = try container.decodeIfPresent(Int.self, forKey: .tabIndex)
            self = .browser(urlPattern: urlPattern, title: title, tabIndex: tabIndex)
        default:
            let windowTitle = try container.decode(String.self, forKey: .windowTitle)
            self = .app(windowTitle: windowTitle)
        }
    }
}

public struct Bookmark: Codable, Identifiable {
    public var id: String          // ユーザー指定のエイリアス
    public var appName: String
    public var bundleIdPattern: String
    public var context: String     // contexts フィルタリング用タグ
    public var state: AppState
    public var createdAt: String  // ISO8601形式

    public init(id: String, appName: String, bundleIdPattern: String, context: String, state: AppState, createdAt: String) {
        self.id = id
        self.appName = appName
        self.bundleIdPattern = bundleIdPattern
        self.context = context
        self.state = state
        self.createdAt = createdAt
    }

    public var description: String {
        switch state {
        case .browser(let urlPattern, let title, let tabIndex):
            let tab = tabIndex.map { " [tab:\($0)]" } ?? ""
            return "\(appName): \(title) (\(urlPattern))\(tab)"
        case .app(let windowTitle):
            return "\(appName): \(windowTitle)"
        }
    }
}

public struct BookmarkStore: Codable {
    public var bookmarks: [Bookmark] = []

    public init() {}

    public static var storePath: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/focusbm")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("bookmarks.yml")
    }

}
