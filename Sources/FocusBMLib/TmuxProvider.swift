import Foundation
import AppKit
import Darwin

// MARK: - RunningAppProtocol

/// ターミナルアプリ検出用プロトコル（テスト可能にするためのDI用）
public protocol RunningAppProtocol {
    var processIdentifier: pid_t { get }
    var bundleIdentifier: String? { get }
    var localizedName: String? { get }
}
extension NSRunningApplication: RunningAppProtocol {}

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
    public var terminalBundleId: String? = nil
    public var terminalAppName: String? = nil
    public var clientTTY: String? = nil  // focusPane() で -c 指定に使用

    public var isAIAgent: Bool {
        let t = title.lowercased()
        // コマンド名で直接判定できるエージェント（終了すればコマンドがシェルに戻る）
        if command == "claude" || command == "aider" || command == "gemini" ||
           command == "copilot" || command == "agent" {
            return true
        }
        // タイトル含有で判定する場合、コマンドがシェルなら終了済みと判断
        if isShellCommand { return false }
        return title.contains("Claude Code") ||
               t.contains("aider") ||
               t.contains("gemini") ||
               t.contains("codex") ||
               t.contains("copilot") ||
               t.contains("openai") ||
               t.contains("ai agent")
    }

    private var isShellCommand: Bool {
        let shells = ["zsh", "bash", "fish", "sh", "dash", "tcsh", "csh", "ksh", "nu"]
        return shells.contains(command)
    }

    // Internal helper exposed for logging in TmuxProvider (avoids duplicating shell list)
    var isShellCommandPublic: Bool { isShellCommand }

    /// Human-readable reason why isAIAgent returned its value (for debug logging)
    var aiAgentReason: String {
        let t = title.lowercased()
        if command == "claude" || command == "aider" || command == "gemini" ||
           command == "copilot" || command == "agent" {
            return "command_match(\(command))"
        }
        if isShellCommand { return "ghost_shell" }
        if title.contains("Claude Code") { return "title_match(Claude Code)" }
        if t.contains("aider")   { return "title_match(aider)" }
        if t.contains("gemini")  { return "title_match(gemini)" }
        if t.contains("codex")   { return "title_match(codex)" }
        if t.contains("copilot") { return "title_match(copilot)" }
        if t.contains("openai")  { return "title_match(openai)" }
        if t.contains("ai agent") { return "title_match(ai agent)" }
        return "not_ai"
    }

    /// Convenience accessor for logging (returns terminalAppName)
    var terminalApp: String? { terminalAppName }

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

    // MARK: - Debug Logging

    private static var debugLog: ((String) -> Void)? = nil

    public static func enableDebugLog(_ handler: @escaping (String) -> Void) {
        debugLog = handler
    }

    private static func log(_ message: String) {
        debugLog?("[TmuxProvider] \(message)")
    }

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

    // MARK: - Client Map (list-clients)

    /// tmux list-clients で全クライアントを一括取得し、セッション→(tty, bundleId, appName) マッピングを構築
    static func buildClientMap() -> [String: (tty: String, bundleId: String?, appName: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = ["tmux", "list-clients", "-F", "#{client_tty}||#{client_session}||#{client_pid}"]

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            log("buildClientMap: list-clients failed with exit code \(process.terminationStatus)")
            return [:]
        }

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        log("buildClientMap raw output: \(output)")

        return parseClientMapOutput(output)
    }

    /// list-clients -a の出力をパースしてセッション→ターミナル情報の辞書を構築
    static func parseClientMapOutput(_ output: String) -> [String: (tty: String, bundleId: String?, appName: String)] {
        var result: [String: (tty: String, bundleId: String?, appName: String)] = [:]

        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            let parts = line.components(separatedBy: "||")
            guard parts.count >= 3 else { continue }
            let tty = parts[0]
            let sessionName = parts[1]
            let clientPid: pid_t? = Int32(parts[2])

            guard !tty.isEmpty, !sessionName.isEmpty else { continue }
            // 同一セッションに複数クライアントがある場合は先勝ち
            if result[sessionName] != nil { continue }

            // TTY からターミナルアプリを特定
            let ttyName = tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
            if let app = findTerminalAppForTTY(ttyName) {
                log("buildClientMap: session '\(sessionName)' -> tty=\(tty), app=\(app.appName)")
                result[sessionName] = (tty: tty, bundleId: app.bundleId, appName: app.appName)
                continue
            }

            // TTY 失敗時: client_pid 祖先プロセス走査
            if let pid = clientPid,
               let app = findTerminalByAncestorProcess(
                   pid,
                   runningApps: NSWorkspace.shared.runningApplications,
                   getParentPID: { sysctlParentPID($0) }) {
                log("buildClientMap: session '\(sessionName)' -> tty=\(tty), ancestor=\(app.appName)")
                result[sessionName] = (tty: tty, bundleId: app.bundleId, appName: app.appName)
                continue
            }

            // フォールバック: tty は記録するが bundleId は未解決
            log("buildClientMap: session '\(sessionName)' -> tty=\(tty), unresolved")
            result[sessionName] = (tty: tty, bundleId: nil, appName: "Terminal")
        }
        return result
    }

    // 全ペインを取得
    public static func listAllPanes(settings: AppSettings? = nil) throws -> [TmuxPane] {
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
        log("list-panes raw output: \(output.trimmingCharacters(in: .newlines))")
        var panes = try parseOutput(output)
        log("parsed panes count: \(panes.count)")

        // list-clients で全クライアントを一括取得（セッション→TTY/bundleId マッピング）
        let clientMap = buildClientMap()
        log("clientMap: \(clientMap.mapValues { (tty: $0.tty, bundleId: $0.bundleId ?? "nil", appName: $0.appName) })")

        // セッションごとに1回だけターミナルを検出してキャッシュ
        var sessionTerminalCache: [String: (bundleId: String?, appName: String?, emoji: String, tty: String?)] = [:]
        for i in panes.indices {
            let sessionName = panes[i].sessionName
            if let cached = sessionTerminalCache[sessionName] {
                panes[i].terminalEmoji = cached.emoji
                panes[i].terminalBundleId = cached.bundleId
                panes[i].terminalAppName = cached.appName
                panes[i].clientTTY = cached.tty
            } else {
                let info = detectTerminalApp(for: panes[i], settings: settings, clientMap: clientMap)
                let emoji = terminalBundleIdToEmoji(info?.bundleId)
                let tty = clientMap[sessionName]?.tty
                panes[i].terminalEmoji = emoji
                panes[i].terminalBundleId = info?.bundleId
                panes[i].terminalAppName = info?.appName
                panes[i].clientTTY = tty
                sessionTerminalCache[sessionName] = (info?.bundleId, info?.appName, emoji, tty)
            }
        }
        return panes
    }

    // AIエージェントのペインのみ取得
    public static func listAIAgentPanes(settings: AppSettings? = nil) throws -> [TmuxPane] {
        let allPanes = try listAllPanes(settings: settings)
        let aiPanes = allPanes.filter { pane in
            let result = pane.isAIAgent
            log("pane \(pane.paneId): command='\(pane.command)', title='\(pane.title)', isShell=\(pane.isShellCommandPublic)")
            log("pane \(pane.paneId): isAIAgent=\(result) reason=\(pane.aiAgentReason)")
            return result
        }
        log("listAIAgentPanes: total=\(allPanes.count), ai=\(aiPanes.count)")
        for pane in aiPanes {
            log("  AI pane: \(pane.paneId) cmd='\(pane.command)' terminal='\(pane.terminalApp ?? "nil")'")
        }
        return aiPanes
    }

    // focusPane の select-window 引数を構築（テスト可能にするため分離）
    // 戻り値: ["tmux", "select-window", "-t", "session:windowIndex"] 形式の引数配列
    static func selectWindowArgs(_ pane: TmuxPane) -> [String] {
        return ["tmux", "select-window", "-t", "\(pane.sessionName):\(pane.windowIndex)"]
    }

    // focusPane の switch-client 引数を構築（detached セッション用）
    // 戻り値: ["tmux", "switch-client", ...] 形式の引数配列
    // 注意: detached の場合のみ使用。attached セッションでは switch-client を呼ばない。
    static func focusPaneArgs(_ pane: TmuxPane) -> [String] {
        var args = ["tmux", "switch-client", "-t", "\(pane.sessionName):\(pane.windowIndex)"]
        if let tty = pane.clientTTY {
            // switch-client -c /dev/ttys005 -t session:windowIndex
            args.insert(contentsOf: ["-c", tty], at: 2)
        }
        return args
    }

    // select-pane の引数を構築（テスト可能にするため分離）
    // 戻り値: ["tmux", "select-pane", "-t", paneId] 形式の引数配列
    static func selectPaneArgs(_ pane: TmuxPane) -> [String] {
        return ["tmux", "select-pane", "-t", pane.paneId]
    }

    // 指定ペインにフォーカス
    //
    // attached セッション（clientTTY != nil）:
    //   activateApp → select-window → select-pane
    //   ※ switch-client は呼ばない（セッションへのアタッチは既に完了しているため）
    //
    // detached セッション（clientTTY == nil）:
    //   switch-client → select-window → select-pane
    public static func focusPane(_ pane: TmuxPane, settings: AppSettings? = nil) throws {
        let isAttached = pane.clientTTY != nil

        if isAttached {
            // --- attached セッション ---
            // 1. ターミナルGUIを前面にアクティベート
            let bundleId = pane.terminalBundleId ?? settings?.preferredTerminal
            let appName = pane.terminalAppName ?? "Terminal"
            if let bid = bundleId {
                log("focusPane(attached): activating terminal '\(appName)' (\(bid))")
                try AppleScriptBridge.activateApp(bundleIdPattern: bid, appName: appName)
                Thread.sleep(forTimeInterval: 0.1)
            }

            // 2. select-window
            try runTmuxCommand(selectWindowArgs(pane),
                               description: "select-window -t \(pane.sessionName):\(pane.windowIndex)",
                               fatalOnFailure: false)

            // 3. select-pane
            try runTmuxCommand(selectPaneArgs(pane),
                               description: "select-pane -t \(pane.paneId)",
                               fatalOnFailure: false)

        } else {
            // --- detached セッション ---
            // 1. switch-client でセッションにアタッチ
            let switchArgs = focusPaneArgs(pane)
            log("focusPane(detached): switch-client -t \(pane.sessionName):\(pane.windowIndex)")
            try runTmuxCommand(switchArgs,
                               description: "switch-client -t \(pane.sessionName):\(pane.windowIndex)",
                               fatalOnFailure: true)

            // 2. select-window
            try runTmuxCommand(selectWindowArgs(pane),
                               description: "select-window -t \(pane.sessionName):\(pane.windowIndex)",
                               fatalOnFailure: false)

            // 3. select-pane
            try runTmuxCommand(selectPaneArgs(pane),
                               description: "select-pane -t \(pane.paneId)",
                               fatalOnFailure: false)
        }
    }

    /// tmux コマンドを実行する内部ヘルパー
    /// - Parameters:
    ///   - arguments: Process に渡す引数配列（先頭は "tmux"）
    ///   - description: ログ用の説明文字列
    ///   - fatalOnFailure: true の場合、終了コード != 0 で TmuxError をスロー
    private static func runTmuxCommand(_ arguments: [String], description: String, fatalOnFailure: Bool) throws {
        log("focusPane: \(description)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        let errPipe = Pipe()
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
            if fatalOnFailure {
                throw TmuxError.executionFailed(errOutput.isEmpty ? "\(description) failed" : errOutput)
            } else {
                log("focusPane: \(description) exited with \(process.terminationStatus) (non-fatal)")
            }
        }
    }

    // bundleId から絵文字を返す
    public static func terminalBundleIdToEmoji(_ bundleId: String?) -> String {
        guard let id = bundleId else { return "❓" }
        switch id {
        case "com.mitchellh.ghostty":     return "👻"
        case "com.googlecode.iterm2":     return "🍎"
        case "com.apple.Terminal":        return "🖥️"
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
        case "WezTerm":
            return ("com.github.wez.wezterm", "WezTerm")
        default:
            // kitty 等: 実行中のターミナルを検索
            return (nil, "iTerm2")
        }
    }

    /// TERM_PROGRAM 値から (bundleId, appName) を解決（terminalAppInfo() を再利用し追加マッピングで補完）
    private static func bundleIdInfoForTermProgram(_ termProgram: String) -> (bundleId: String?, appName: String)? {
        // terminalAppInfo() のマッピングを優先利用（executor-1 が WezTerm 等を追加済み）
        let info = terminalAppInfo(termProgram: termProgram)
        if info.bundleId != nil { return info }

        // 追加マッピング（Ghostty, Alacritty 等 terminalAppInfo() 未対応分）
        switch termProgram.lowercased() {
        case "ghostty":   return ("com.mitchellh.ghostty", "Ghostty")
        case "alacritty": return ("org.alacritty", "Alacritty")
        default:          return nil
        }
    }

    /// tmux show-environment でセッション作成時の TERM_PROGRAM を取得してターミナルを識別
    private static func terminalAppFromTmuxEnv(session: String) -> (bundleId: String?, appName: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: envPath)
        process.arguments = ["tmux", "show-environment", "-t", session, "TERM_PROGRAM"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 出力形式: "TERM_PROGRAM=iTerm.app"（設定済み）or "-TERM_PROGRAM"（未設定）
        guard output.hasPrefix("TERM_PROGRAM=") else { return nil }
        let termProgram = String(output.dropFirst("TERM_PROGRAM=".count))
        return bundleIdInfoForTermProgram(termProgram)
    }

    // TTYからターミナルアプリを特定
    static func detectTerminalApp(
        for pane: TmuxPane,
        settings: AppSettings? = nil,
        clientMap: [String: (tty: String, bundleId: String?, appName: String)]? = nil
    ) -> (bundleId: String?, appName: String)? {
        let sessionName = pane.sessionName

        // preferredTerminal が設定されていれば最優先で返す
        if let preferred = settings?.preferredTerminal {
            let appName = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == preferred })?.localizedName ?? preferred
            log("detectTerminal for session '\(sessionName)': preferred terminal override -> (\(preferred), \(appName))")
            return (preferred, appName)
        }

        // clientMap（list-clients ベース）にヒットすればそれを返す
        if let mapped = clientMap?[sessionName], mapped.bundleId != nil {
            log("detectTerminal for session '\(sessionName)': clientMap hit -> (\(mapped.bundleId!), \(mapped.appName))")
            return (mapped.bundleId, mapped.appName)
        }

        // clientMap ミスの場合: per-session list-clients にフォールバック
        let clientProcess = Process()
        clientProcess.executableURL = URL(fileURLWithPath: envPath)
        let pipe = Pipe()
        clientProcess.standardOutput = pipe
        clientProcess.standardError = Pipe()
        clientProcess.arguments = ["tmux", "list-clients",
            "-t", "\(sessionName):\(pane.windowIndex)",
            "-F", "#{client_tty}||#{client_pid}"]
        try? clientProcess.run()
        clientProcess.waitUntilExit()

        let rawOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        log("detectTerminal for session '\(sessionName)': clientMap miss, per-session fallback")
        log("list-clients raw output: '\(rawOutput)'")

        let firstLine = rawOutput.components(separatedBy: "\n").first ?? rawOutput
        let outputParts = firstLine.components(separatedBy: "||")
        let ttyOutput = outputParts[0]
        let clientPid: pid_t? = outputParts.count > 1 ? Int32(outputParts[1]) : nil
        log("list-clients parsed: tty='\(ttyOutput)', clientPid=\(clientPid ?? -1)")

        guard !ttyOutput.isEmpty else {
            // フォールバック1: client_pid 祖先プロセス走査
            if let pid = clientPid,
               let app = findTerminalByAncestorProcess(
                   pid,
                   runningApps: NSWorkspace.shared.runningApplications,
                   getParentPID: { sysctlParentPID($0) }) {
                log("detectTerminal: ancestor fallback -> (\(app.bundleId ?? "nil"), \(app.appName))")
                return app
            }
            // フォールバック2: tmux show-environment
            if let app = terminalAppFromTmuxEnv(session: sessionName) {
                log("detectTerminal: env fallback -> (\(app.bundleId ?? "nil"), \(app.appName))")
                return app
            }
            log("detectTerminal: no terminal detected, skipping activate")
            return nil
        }

        // TTYの親プロセスからターミナルアプリを特定
        let ttyName = ttyOutput.hasPrefix("/dev/") ? String(ttyOutput.dropFirst(5)) : ttyOutput
        if let app = findTerminalAppForTTY(ttyName) {
            log("detectTerminal: TTY path -> (\(app.bundleId ?? "nil"), \(app.appName))")
            return app
        }

        // TTY検索失敗時: client_pid 祖先プロセス走査 → tmux show-environment
        if let pid = clientPid,
           let app = findTerminalByAncestorProcess(
               pid,
               runningApps: NSWorkspace.shared.runningApplications,
               getParentPID: { sysctlParentPID($0) }) {
            log("detectTerminal: ancestor fallback -> (\(app.bundleId ?? "nil"), \(app.appName))")
            return app
        }
        if let app = terminalAppFromTmuxEnv(session: sessionName) {
            log("detectTerminal: env fallback -> (\(app.bundleId ?? "nil"), \(app.appName))")
            return app
        }
        log("detectTerminal: no terminal detected, skipping activate")
        return nil
    }

    // 実行中のターミナルアプリを優先順位で返す
    static func findRunningTerminalApp() -> (bundleId: String?, appName: String)? {
        let runningApps = NSWorkspace.shared.runningApplications

        // まず環境変数 TERM_PROGRAM を確認して該当アプリが起動中ならそれを優先
        if let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"],
           let info = bundleIdInfoForTermProgram(termProgram),
           let bundleId = info.bundleId,
           runningApps.contains(where: { $0.bundleIdentifier == bundleId }) {
            return info
        }

        // 優先順位リスト（WezTermを上位に配置）
        let terminalApps: [(bundleId: String, appName: String)] = [
            ("com.mitchellh.ghostty", "Ghostty"),
            ("com.github.wez.wezterm", "WezTerm"),
            ("com.googlecode.iterm2", "iTerm2"),
            ("com.apple.Terminal", "Terminal"),
            ("org.alacritty", "Alacritty"),
        ]

        for app in terminalApps {
            if runningApps.contains(where: { $0.bundleIdentifier == app.bundleId }) {
                return (app.bundleId, app.appName)
            }
        }
        return nil
    }

    // TTYの親プロセスPIDからGUIターミナルアプリを特定
    public static func findTerminalAppForTTY(_ ttyName: String) -> (bundleId: String?, appName: String)? {
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

        // nil を返す（フォールバックは detectTerminalApp() で tmux show-environment → 実行中アプリ順次検索）
        return nil
    }

    // MARK: - client_pid ベースのターミナル検出

    /// 既知のターミナルアプリのbundleId一覧
    static let knownTerminalBundleIds: Set<String> = [
        "com.mitchellh.ghostty",
        "com.github.wez.wezterm",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "org.alacritty",
    ]

    /// startPidから親プロセスを最大10回辿り、既知ターミナルアプリを返す
    static func findTerminalByAncestorProcess(
        _ startPid: pid_t,
        runningApps: [any RunningAppProtocol],
        getParentPID: (pid_t) -> pid_t?
    ) -> (bundleId: String?, appName: String)? {
        var currentPid = startPid
        for _ in 0..<10 {
            if let app = runningApps.first(where: { $0.processIdentifier == currentPid }),
               let bundleId = app.bundleIdentifier,
               knownTerminalBundleIds.contains(bundleId) {
                return (bundleId, app.localizedName ?? bundleId)
            }
            guard let ppid = getParentPID(currentPid), ppid > 1 else { break }
            currentPid = ppid
        }
        return nil
    }

    /// sysctl を使って親プロセスPIDを取得
    public static func sysctlParentPID(_ pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0, size > 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        guard ppid > 1 else { return nil }
        return ppid
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
