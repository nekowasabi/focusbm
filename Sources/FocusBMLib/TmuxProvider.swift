import Foundation
import AppKit

public enum TmuxError: Error, LocalizedError {
    case tmuxNotAvailable
    case executionFailed(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .tmuxNotAvailable: return "tmux is not available"
        case .executionFailed(let msg): return "tmux command failed: \(msg)"
        case .parseError(let msg): return "Failed to parse tmux output: \(msg)"
        }
    }
}

public enum TmuxAgentStatus {
    case running, planMode, acceptEdits, idle
}

public struct TmuxPane {
    public let paneId: String
    public let sessionName: String
    public let windowIndex: Int
    public let windowName: String
    public let command: String
    public let title: String
    public let currentPath: String
    public var terminalEmoji: String = "❓"

    public var isAIAgent: Bool {
        let t = title.lowercased()
        return command == "claude" ||
               title.contains("Claude Code") ||
               command == "aider" ||
               t.contains("aider") ||
               command == "gemini" ||
               t.contains("gemini") ||
               t.contains("codex") ||          // codex runs as node
               command == "copilot" ||
               t.contains("copilot") ||
               command == "agent" ||
               t.contains("openai") ||
               t.contains("ai agent")
    }

    public var agentStatus: TmuxAgentStatus {
        if title.contains("⏸") { return .planMode }
        if title.contains("⏵") { return .acceptEdits }
        if let scalar = title.unicodeScalars.first,
           scalar.value >= 0x2800 && scalar.value <= 0x28FF {
            return .running
        }
        return .idle
    }

    public var statusEmoji: String {
        switch agentStatus {
        case .running:     return "●"
        case .planMode:    return "⏸"
        case .acceptEdits: return "⏵"
        case .idle:        return "○"
        }
    }

    public var agentName: String {
        let t = title.lowercased()
        switch command {
        case "claude":  return "Claude Code"
        case "aider":   return "Aider"
        case "gemini":  return "Gemini"
        case "copilot": return "Copilot"
        case "agent":   return "Agent"
        default:
            if t.contains("codex")   { return "Codex" }
            if t.contains("copilot") { return "Copilot" }
            return command
        }
    }

    public var displayName: String {
        let pathPart = currentPath.isEmpty ? "" :
            " — \(URL(fileURLWithPath: currentPath).lastPathComponent)"
        return "\(terminalEmoji) \(statusEmoji) \(agentName)\(pathPart)"
    }
}

public struct TmuxProvider {
    static let envPath = "/usr/bin/env"
    static let separator = "||"
    static let formatString = "#{pane_id}||#{session_name}||#{window_index}||#{window_name}||#{pane_current_command}||#{pane_title}||#{pane_current_path}"

    // tmuxが起動しているか確認
    public static func isTmuxAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = ["tmux", "info"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // 全ペインを取得
    public static func listAllPanes() throws -> [TmuxPane] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = ["tmux", "list-panes", "-a", "-F", formatString]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw TmuxError.tmuxNotAvailable
        }
        process.waitUntilExit()

        let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            throw TmuxError.executionFailed(errOutput.isEmpty ? "exit code \(process.terminationStatus)" : errOutput)
        }

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var panes = try parseOutput(output)

        // セッションごとに1回だけターミナルを検出してキャッシュ
        var sessionTerminalCache: [String: String] = [:]
        for i in panes.indices {
            let sessionName = panes[i].sessionName
            if let cached = sessionTerminalCache[sessionName] {
                panes[i].terminalEmoji = cached
            } else {
                let info = detectTerminalApp(for: panes[i])
                let emoji = terminalBundleIdToEmoji(info?.bundleId)
                sessionTerminalCache[sessionName] = emoji
                panes[i].terminalEmoji = emoji
            }
        }
        return panes
    }

    // AIエージェントのペインのみ取得
    public static func listAIAgentPanes() throws -> [TmuxPane] {
        return try listAllPanes().filter { $0.isAIAgent }
    }

    // 指定ペインにフォーカス
    public static func focusPane(_ pane: TmuxPane) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = ["tmux", "switch-client", "-t", "\(pane.sessionName):\(pane.windowIndex)"]

        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw TmuxError.tmuxNotAvailable
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw TmuxError.executionFailed(errOutput.isEmpty ? "switch-client failed" : errOutput)
        }

        // TTYベースでターミナルアプリを検出してアクティブ化
        if let termApp = detectTerminalApp(for: pane) {
            try AppleScriptBridge.activateApp(bundleIdPattern: termApp.bundleId, appName: termApp.appName)
        }
    }

    // bundleId から絵文字を返す
    static func terminalBundleIdToEmoji(_ bundleId: String?) -> String {
        guard let id = bundleId else { return "❓" }
        switch id {
        case "com.mitchellh.ghostty":     return "👻"
        case "com.googlecode.iterm2":     return "🍎"
        case "com.apple.Terminal":        return "🍎"
        case "com.github.wez.wezterm":    return "⚡"
        case "org.alacritty":             return "🔲"
        default:                          return "❓"
        }
    }

    // 内部テスト用: TERM_PROGRAM から (bundleId, appName) を返す（テスト互換性維持）
    static func terminalAppInfo(termProgram: String) -> (bundleId: String?, appName: String) {
        switch termProgram {
        case "iTerm.app":
            return ("com.googlecode.iterm2", "iTerm2")
        case "Apple_Terminal":
            return ("com.apple.Terminal", "Terminal")
        default:
            // kitty, wezterm 等: 実行中のターミナルを検索
            return (nil, "iTerm2")
        }
    }

    // TTYからターミナルアプリを特定
    static func detectTerminalApp(for pane: TmuxPane) -> (bundleId: String?, appName: String)? {
        // tmux list-clients でTTYを取得
        let clientProcess = Process()
        clientProcess.executableURL = URL(fileURLWithPath: envPath)
        let pipe = Pipe()
        clientProcess.standardOutput = pipe
        clientProcess.standardError = Pipe()
        clientProcess.arguments = ["tmux", "list-clients",
            "-t", "\(pane.sessionName):\(pane.windowIndex)",
            "-F", "#{client_tty}"]
        try? clientProcess.run()
        clientProcess.waitUntilExit()

        let ttyOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !ttyOutput.isEmpty else {
            // フォールバック: 既知ターミナルアプリを優先順位で検索
            return findRunningTerminalApp()
        }

        // TTYの親プロセスからターミナルアプリを特定
        let ttyName = ttyOutput.hasPrefix("/dev/") ? String(ttyOutput.dropFirst(5)) : ttyOutput
        return findTerminalAppForTTY(ttyName)
    }

    // 実行中のターミナルアプリを優先順位で返す
    static func findRunningTerminalApp() -> (bundleId: String?, appName: String)? {
        let terminalApps: [(bundleId: String, appName: String)] = [
            ("com.mitchellh.ghostty", "Ghostty"),
            ("com.googlecode.iterm2", "iTerm2"),
            ("com.apple.Terminal", "Terminal"),
            ("org.alacritty", "Alacritty"),
            ("com.github.wez.wezterm", "WezTerm"),
        ]

        let runningApps = NSWorkspace.shared.runningApplications
        for app in terminalApps {
            if runningApps.contains(where: { $0.bundleIdentifier == app.bundleId }) {
                return (app.bundleId, app.appName)
            }
        }
        return nil
    }

    // TTYの親プロセスPIDからGUIターミナルアプリを特定
    static func findTerminalAppForTTY(_ ttyName: String) -> (bundleId: String?, appName: String)? {
        // ps でTTYに接続しているプロセスのPIDを取得
        let psProcess = Process()
        psProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
        let pipe = Pipe()
        psProcess.standardOutput = pipe
        psProcess.standardError = Pipe()
        psProcess.arguments = ["-t", ttyName, "-o", "pid=,ppid="]
        try? psProcess.run()
        psProcess.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let pids = output.split(separator: "\n").compactMap { line -> pid_t? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
            return parts.first.flatMap { Int32($0) }
        }

        // PIDからNSRunningApplicationを検索（GUIアプリのみ）
        let runningApps = NSWorkspace.shared.runningApplications
        for pid in pids {
            if let app = runningApps.first(where: { $0.processIdentifier == pid }),
               let bundleId = app.bundleIdentifier {
                return (bundleId, app.localizedName ?? "Terminal")
            }
        }

        // フォールバック
        return findRunningTerminalApp()
    }

    // パース処理（テスト可能にするため internal）
    static func parseOutput(_ output: String) throws -> [TmuxPane] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        return try lines.map { line in
            let parts = line.components(separatedBy: "||")
            guard parts.count >= 7 else {
                throw TmuxError.parseError("Expected 7 fields, got \(parts.count): \(line)")
            }
            return TmuxPane(
                paneId: parts[0],
                sessionName: parts[1],
                windowIndex: Int(parts[2]) ?? 0,
                windowName: parts[3],
                command: parts[4],
                title: parts[5],
                currentPath: parts[6]
            )
        }
    }
}
