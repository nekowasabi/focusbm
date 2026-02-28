import Foundation
import Yams

// アプリ固有の状態（Tagged Union で型安全に表現）
public enum AppState: Codable {
    case browser(urlPattern: String, title: String, tabIndex: Int?)
    case app(windowTitle: String)
    case floatingWindows  // 実行時に CGWindowList + AXUIElement で動的列挙

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
        case .floatingWindows:
            try container.encode("floatingWindows", forKey: .type)
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
        case "floatingWindows":
            self = .floatingWindows
        default:
            let windowTitle = try container.decode(String.self, forKey: .windowTitle)
            self = .app(windowTitle: windowTitle)
        }
    }
}

public struct Bookmark: Codable, Identifiable {
    public var id: String          // ユーザー指定のエイリアス
    public var appName: String
    public var bundleIdPattern: String?  // 省略可能: nil の場合は appName でマッチング
    public var context: String     // contexts フィルタリング用タグ
    public var state: AppState
    public var createdAt: String  // ISO8601形式

    public init(id: String, appName: String, bundleIdPattern: String?, context: String, state: AppState, createdAt: String) {
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
        case .floatingWindows:
            return "\(appName): [floating windows]"
        }
    }
}

public struct BookmarkStore: Codable {
    public var settings: AppSettings?
    public var bookmarks: [Bookmark] = []

    public init() {}

    public static var storePath: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/focusbm")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir.appendingPathComponent("bookmarks.yml")
    }

}

// MARK: - Settings

public struct HotkeySettings: Codable, Equatable {
    public var togglePanel: String

    public init(togglePanel: String = "cmd+ctrl+b") {
        self.togglePanel = togglePanel
    }
}

public struct AppSettings: Codable, Equatable {
    public var hotkey: HotkeySettings
    public var displayNumber: Int?
    public var listFontSize: Double?
    /// tmux AIエージェントペインを検索UIに表示するか（デフォルト: true）
    public var showTmuxAgents: Bool?

    public init(
        hotkey: HotkeySettings = HotkeySettings(),
        displayNumber: Int? = nil,
        listFontSize: Double? = nil,
        showTmuxAgents: Bool? = nil
    ) {
        self.hotkey = hotkey
        self.displayNumber = displayNumber
        self.listFontSize = listFontSize
        self.showTmuxAgents = showTmuxAgents
    }
}

// MARK: - Hotkey Parsing

public struct HotkeyModifiers: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let control = HotkeyModifiers(rawValue: 1 << 1)
    public static let option  = HotkeyModifiers(rawValue: 1 << 2)
    public static let shift   = HotkeyModifiers(rawValue: 1 << 3)
}

public struct ParsedHotkey {
    public let modifiers: HotkeyModifiers
    public let key: String
}

public struct HotkeyParser {
    public static func parse(_ hotkeyString: String) -> ParsedHotkey {
        let parts = hotkeyString.lowercased().split(separator: "+").map(String.init)
        var modifiers = HotkeyModifiers()
        var key = ""

        for part in parts {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "ctrl", "control": modifiers.insert(.control)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            default: key = part
            }
        }

        return ParsedHotkey(modifiers: modifiers, key: key)
    }
}

// MARK: - Bookmark Search

public struct BookmarkSearcher {
    /// FZF 風サブシーケンスマッチ: クエリの文字が順番通りに text に登場するかチェック
    /// 戻り値: マッチしない場合 nil、マッチした場合スコア（高いほど関連度高）
    public static func fuzzyScore(text: String, query: String) -> Int? {
        let t = text.lowercased()
        let q = query.lowercased()
        guard !q.isEmpty else { return 0 }
        var score = 0
        var textIdx = t.startIndex
        for queryChar in q {
            guard let found = t[textIdx...].firstIndex(of: queryChar) else {
                return nil  // クエリ文字が順番通りに見つからない
            }
            if found == t.startIndex { score += 10 }  // 先頭一致ボーナス
            if found > t.startIndex {
                let prev = t.index(before: found)
                if " -_".contains(t[prev]) { score += 5 }  // 単語区切り直後ボーナス
            }
            score += 1
            textIdx = t.index(after: found)
        }
        return score
    }

    /// fuzzy フィルタ + スコア順ソート
    public static func filter(bookmarks: [Bookmark], query: String) -> [Bookmark] {
        guard !query.isEmpty else { return bookmarks }
        return bookmarks
            .compactMap { bm -> (Bookmark, Int)? in
                let texts = [bm.id, bm.appName, bm.context]
                let maxScore = texts.compactMap { fuzzyScore(text: $0, query: query) }.max()
                return maxScore.map { (bm, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}

// MARK: - SearchItem

/// Bookmark（静的）と FloatingWindowEntry（動的）を統合する表示型
public enum SearchItem: Identifiable {
    case bookmark(Bookmark)
    case floatingWindow(FloatingWindowEntry)
    case tmuxPane(TmuxPane)

    public var id: String {
        switch self {
        case .bookmark(let b): return b.id
        case .floatingWindow(let f): return f.id
        case .tmuxPane(let p): return p.paneId
        }
    }

    public var displayName: String {
        switch self {
        case .bookmark(let b): return b.id
        case .floatingWindow(let f): return f.displayName
        case .tmuxPane(let p): return p.displayName
        }
    }

    public var appName: String {
        switch self {
        case .bookmark(let b): return b.appName
        case .floatingWindow(let f): return f.appName
        case .tmuxPane(let p): return "session \(p.sessionName), win \(p.windowIndex)"
        }
    }

    public var context: String {
        switch self {
        case .bookmark(let b): return b.context
        case .floatingWindow: return ""
        case .tmuxPane: return "tmux"
        }
    }

    /// browser 状態の場合のみ URL パターンを返す
    public var urlPattern: String? {
        switch self {
        case .bookmark(let b):
            if case .browser(let url, _, _) = b.state { return url }
            return nil
        case .floatingWindow:
            return nil
        case .tmuxPane:
            return nil
        }
    }
}
