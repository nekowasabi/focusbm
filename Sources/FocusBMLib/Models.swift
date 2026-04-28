import Foundation
import Yams

// Why: 定数を一箇所に集約し、散在するマジックナンバーを排除。enum にすることで
//      インスタンス化不可であることを型レベルで保証する（namespaced constants パターン）
public enum PanelDefaults {
    public static let width: CGFloat = 500
    public static let widthTwoColumns: CGFloat = 800
    public static let height: CGFloat = 400
}

// アプリ固有の状態（Tagged Union で型安全に表現）
public enum AppState: Codable {
    case browser(urlPattern: String, title: String, tabIndex: Int?, urlPrefix: String?)
    case app(windowTitle: String)
    case floatingWindows  // 実行時に CGWindowList + AXUIElement で動的列挙

    private enum CodingKeys: String, CodingKey {
        case type, urlPattern, title, tabIndex, windowTitle, urlPrefix
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .browser(let urlPattern, let title, let tabIndex, let urlPrefix):
            try container.encode("browser", forKey: .type)
            try container.encode(urlPattern, forKey: .urlPattern)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(tabIndex, forKey: .tabIndex)
            try container.encodeIfPresent(urlPrefix, forKey: .urlPrefix)
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
            let urlPrefix = try container.decodeIfPresent(String.self, forKey: .urlPrefix)
            self = .browser(urlPattern: urlPattern, title: title, tabIndex: tabIndex, urlPrefix: urlPrefix)
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
    public var noShortcut: Bool? = nil   // true: ショートカット数字バッジを表示しない
    public var shortcut: String? = nil   // YAML shortcut key (e.g., "g" for Cmd+G)
    public var lowPriority: Bool? = nil  // true: デフォルト表示でリスト下部に移動

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
        case .browser(let urlPattern, let title, let tabIndex, _):
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
    /// パネル幅（デフォルト nil → 500）
    public var panelWidth: Double?
    /// パネル高さ（デフォルト nil → 400）
    public var panelHeight: Double?
    /// フォント名（デフォルト nil → system monospaced）
    public var fontName: String?
    /// 優先ターミナル（bundleIdentifier 形式、例: "com.github.wez.wezterm"）
    public var preferredTerminal: String?
    /// 絞り込み結果が1件になったとき自動実行する（デフォルト: false）
    public var autoExecuteOnSingleResult: Bool?
    /// 自動実行までの遅延秒数（デフォルト: 0.3秒）
    public var autoExecuteDelay: Double?
    /// 数字キー単体でブックマークにフォーカスする（デフォルト: true）
    public var directNumberKeys: Bool?
    /// 1=縦列（デフォルト）、2=横2列、他=nil扱い
    public var bookmarkListColumns: Int?
    /// AIエージェント行にショートカット番号を割り当てるか（デフォルト: true）
    /// Why: showTmuxAgents（行自体の表示制御）とは責務が異なる。
    /// 表示はするがブックマーク側の番号連続性を優先したいユースケース向けに独立トグルを用意した。
    public var showAIAgentShortcut: Bool?

    public init(
        hotkey: HotkeySettings = HotkeySettings(),
        displayNumber: Int? = nil,
        listFontSize: Double? = nil,
        showTmuxAgents: Bool? = nil,
        panelWidth: Double? = nil,
        panelHeight: Double? = nil,
        fontName: String? = nil,
        preferredTerminal: String? = nil,
        autoExecuteOnSingleResult: Bool? = nil,
        autoExecuteDelay: Double? = nil,
        directNumberKeys: Bool? = nil,
        bookmarkListColumns: Int? = nil,
        showAIAgentShortcut: Bool? = nil
    ) {
        self.hotkey = hotkey
        self.displayNumber = displayNumber
        self.listFontSize = listFontSize
        self.showTmuxAgents = showTmuxAgents
        self.panelWidth = panelWidth
        self.panelHeight = panelHeight
        self.fontName = fontName
        self.preferredTerminal = preferredTerminal
        self.autoExecuteOnSingleResult = autoExecuteOnSingleResult
        self.autoExecuteDelay = autoExecuteDelay
        self.directNumberKeys = directNumberKeys
        self.bookmarkListColumns = bookmarkListColumns
        self.showAIAgentShortcut = showAIAgentShortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decodeIfPresent(HotkeySettings.self, forKey: .hotkey) ?? HotkeySettings()
        displayNumber = try container.decodeIfPresent(Int.self, forKey: .displayNumber)
        listFontSize = try container.decodeIfPresent(Double.self, forKey: .listFontSize)
        showTmuxAgents = try container.decodeIfPresent(Bool.self, forKey: .showTmuxAgents)
        panelWidth = try container.decodeIfPresent(Double.self, forKey: .panelWidth)
        panelHeight = try container.decodeIfPresent(Double.self, forKey: .panelHeight)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
        preferredTerminal = try container.decodeIfPresent(String.self, forKey: .preferredTerminal)
        autoExecuteOnSingleResult = try container.decodeIfPresent(Bool.self, forKey: .autoExecuteOnSingleResult)
        autoExecuteDelay = try container.decodeIfPresent(Double.self, forKey: .autoExecuteDelay)
        directNumberKeys = try container.decodeIfPresent(Bool.self, forKey: .directNumberKeys)
        showAIAgentShortcut = try container.decodeIfPresent(Bool.self, forKey: .showAIAgentShortcut)
        let rawColumns = try container.decodeIfPresent(Int.self, forKey: .bookmarkListColumns)
        // Why: normalizedColumns で {1,2} 以外を nil に正規化。
        // UIは最大2列グリッドのみサポートするため、それ以外の値は未指定扱いとする。
        bookmarkListColumns = AppSettings.normalizedColumns(rawColumns)
    }

    // Why: private static helper に切り出してテスト可能性を確保。
    // 将来 3 列対応する場合はここの許可セットに 3 を追加するだけでよい。
    // Why: throw せず nil に正規化するのは UX 保護のため（不正値で起動不能になるリスクを排除）。
    // Why: 許可値を {1,2} に限定するのは UI が最大 2 列グリッドのみサポートするため
    //      （SearchView の 2D レイアウト制約による）。
    static func normalizedColumns(_ value: Int?) -> Int? {
        // Note: internal (not private) to allow unit testing from the same module
        guard let v = value else { return nil }
        guard v == 1 || v == 2 else {
            print("[FocusBM][WARN] bookmarkListColumns: \(v) is invalid (allowed: 1, 2); falling back to nil")
            return nil
        }
        return v
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

// MARK: - AgentDisplay

/// SearchItem の tmuxPane ケースにおけるエージェント表示情報
/// Color を含まず Bool で状態を表現するため、App 層で Color マッピングする責務とする
public struct AgentDisplay {
    public let emoji: String
    public let isRunning: Bool
    public let nameWithoutEmoji: String

    public init(emoji: String, isRunning: Bool, nameWithoutEmoji: String) {
        self.emoji = emoji
        self.isRunning = isRunning
        self.nameWithoutEmoji = nameWithoutEmoji
    }
}

// MARK: - SearchItem

/// Bookmark（静的）と FloatingWindowEntry（動的）を統合する表示型
public enum SearchItem: Identifiable {
    case bookmark(Bookmark)
    case floatingWindow(FloatingWindowEntry)
    case tmuxPane(TmuxPane)
    case aiProcess(ProcessProvider.AIProcess)

    public var id: String {
        switch self {
        case .bookmark(let b): return b.id
        case .floatingWindow(let f): return f.id
        case .tmuxPane(let p): return p.paneId
        case .aiProcess(let p): return "aiprocess-\(p.pid)"
        }
    }

    public var displayName: String {
        switch self {
        case .bookmark(let b): return b.id
        case .floatingWindow(let f): return f.displayName
        case .tmuxPane(let p): return p.displayName
        case .aiProcess(let p):
            let dir = URL(fileURLWithPath: p.workingDirectory).lastPathComponent
            return "\(p.terminalEmoji) \(p.command) — \(dir)"
        }
    }

    public var appName: String {
        switch self {
        case .bookmark(let b): return b.appName
        case .floatingWindow(let f): return f.appName
        case .tmuxPane(let p): return "session \(p.sessionName), win \(p.windowIndex)"
        case .aiProcess(let p): return p.terminalAppName ?? p.command
        }
    }

    public var context: String {
        switch self {
        case .bookmark(let b): return b.context
        case .floatingWindow: return ""
        case .tmuxPane: return "tmux"
        case .aiProcess: return "process"
        }
    }

    /// browser 状態の場合のみ URL パターンを返す
    public var urlPattern: String? {
        switch self {
        case .bookmark(let b):
            if case .browser(let url, _, _, _) = b.state { return url }
            return nil
        case .floatingWindow:
            return nil
        case .tmuxPane:
            return nil
        case .aiProcess:
            return nil
        }
    }

    /// AIエージェントツール固有の絵文字
    public var agentEmoji: String {
        switch self {
        case .tmuxPane(let p):
            // Why: Node.js経由で検出されたAIツールはcommandが"node"になるため、
            //      resolvedNodeCommandを優先して絵文字を解決する
            let effectiveCommand = p.resolvedNodeCommand ?? p.command
            return TmuxProvider.agentCommandToEmoji(effectiveCommand)
        case .aiProcess(let p):
            return TmuxProvider.agentCommandToEmoji(p.command)
        default:
            return "🤖"
        }
    }

    /// AI エージェントペイン（tmuxPane）の表示情報
    public var agentDisplay: AgentDisplay? {
        switch self {
        case .tmuxPane(let pane):
            let pathPart = pane.currentPath.isEmpty ? "" :
                " — \(URL(fileURLWithPath: pane.currentPath).lastPathComponent)"
            return AgentDisplay(
                emoji: pane.statusEmoji,
                isRunning: pane.agentStatus == .running,
                nameWithoutEmoji: "\(pane.agentName)\(pathPart)"
            )
        case .bookmark, .floatingWindow, .aiProcess:
            return nil
        }
    }

    /// AI エージェントプロセスかどうか
    public var isAIAgent: Bool {
        switch self {
        case .bookmark, .floatingWindow:
            return false
        case .tmuxPane(let p):
            return p.isAIAgent
        case .aiProcess:
            return true
        }
    }

    /// ショートカット数字バッジを表示しない
    public var noShortcut: Bool {
        if case .bookmark(let bm) = self { return bm.noShortcut ?? false }
        return false
    }

    /// デフォルト表示でリスト下部に移動
    public var lowPriority: Bool {
        if case .bookmark(let bm) = self { return bm.lowPriority ?? false }
        return false
    }

    /// デバッグ用ラベル
    public var debugLabel: String {
        switch self {
        case .bookmark(let b): return "bookmark:\(b.appName) lp=\(b.lowPriority ?? false)"
        case .floatingWindow(let w): return "window:\(w.displayName)"
        case .tmuxPane(let p): return "tmux:\(p.displayName)"
        case .aiProcess(let p): return "ai:\(p.command)"
        }
    }
}
