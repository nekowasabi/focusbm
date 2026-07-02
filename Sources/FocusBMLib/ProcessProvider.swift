import Foundation
import AppKit
import Darwin

/// tmux外のAIエージェントプロセスを検出するプロバイダー
public struct ProcessProvider {

    /// tmux外で実行中のAIエージェントプロセス情報
    public struct AIProcess {
        public let pid: pid_t
        public let command: String         // "claude", "aider" 等
        public let workingDirectory: String
        public let terminalBundleId: String?
        public let terminalAppName: String?
        public let terminalEmoji: String
        public let title: String           // プロセスの識別用タイトル

        public init(
            pid: pid_t,
            command: String,
            workingDirectory: String,
            terminalBundleId: String?,
            terminalAppName: String?,
            terminalEmoji: String,
            title: String
        ) {
            self.pid = pid
            self.command = command
            self.workingDirectory = workingDirectory
            self.terminalBundleId = terminalBundleId
            self.terminalAppName = terminalAppName
            self.terminalEmoji = terminalEmoji
            self.title = title
        }
    }

    /// 検出対象のAIエージェントコマンド名
    static let aiAgentCommands = ["claude", "aider", "gemini", "copilot", "codex", "hermes"]

    // MARK: - Daemon Process Filtering

    /// Command-line markers for non-interactive helper processes.
    // Why: Adopted command-line marker filtering instead of changing the pgrep pattern.
    //      The same executable can run either interactively or as a helper process.
    static let daemonSubcommands = ["app-server", "mcp-server", "--chrome-native-host"]

    /// コマンドライン文字列がデーモンプロセスかどうかを判定する
    /// - Parameter commandLine: ps コマンドで取得したフルコマンドライン文字列
    /// - Returns: デーモンサブコマンドを含む場合 true
    // Why: pgrep パターンだけではサブコマンドの除外が困難 —
    //      コマンドライン文字列から既知のデーモンサブコマンドを検出する純粋関数方式を採用
    static func isDaemonCommandLine(_ commandLine: String) -> Bool {
        return daemonSubcommands.contains { commandLine.contains(" " + $0) }
    }

    /// プロセスのコマンドライン引数を取得する
    /// - Parameter pid: 対象プロセスID
    /// - Returns: フルコマンドライン文字列（取得失敗時は空文字列）
    // Why: getTTYForProcess と同パターンでプロセスのコマンドライン引数を取得 —
    //      DRY 違反だが、共通化は Refactor Phase のスコープ（本ミッションのスコープ外）
    static func getCommandLineArgs(_ pid: pid_t) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "args="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// PID が存在し、かつゾンビ状態ではないことを判定する
    static func isProcessAlive(_ pid: pid_t) -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0, size > 0 else { return false }
        return info.kp_proc.p_stat != SZOMB
    }

    /// 絞り込み画面から復元可能な AI プロセスかどうかを判定する
    static func isRecoverableAIProcess(_ process: AIProcess) -> Bool {
        return process.terminalBundleId != nil
    }

    // MARK: - Debug Logging

    private static var debugLog: ((String) -> Void)? = nil

    public static func enableDebugLog(_ handler: @escaping (String) -> Void) {
        debugLog = handler
    }

    private static func log(_ message: String) {
        debugLog?("[ProcessProvider] \(message)")
    }

    // MARK: - Public API

    /// tmux外で実行中のAIエージェントプロセスを取得
    /// tmuxペインに属するプロセスは除外する
    public static func listNonTmuxAIProcesses() -> [AIProcess] {
        clearTmuxCheckCache()
        var result: [AIProcess] = []

        for commandName in aiAgentCommands {
            let pids = findProcessesByName(commandName)
            log("search '\(commandName)': found \(pids.count) processes")

            for pid in pids {
                // tmuxペインに属するプロセスは除外
                if isProcessInTmux(pid) {
                    log("  pid \(pid): skip (in tmux)")
                    continue
                }

                // Why: pgrep の結果だけを採用すると終了済み/ゾンビ化した PID が残り、
                //      復元不能な「❓」項目として絞り込み画面に表示されるため事前に除外する。
                guard isProcessAlive(pid) else {
                    log("  pid \(pid): skip (not alive or zombie)")
                    continue
                }

                // Why: codex app-server 等のデーモンプロセスを AI エージェントリストから除外
                let cmdLine = getCommandLineArgs(pid)
                if isDaemonCommandLine(cmdLine) {
                    log("  pid \(pid): skip (daemon subcommand)")
                    continue
                }

                let tty = getTTYForProcess(pid)
                let cwd = getWorkingDirectory(pid)
                let terminalInfo = findTerminalForTTY(tty)

                log("  pid \(pid): tty=\(tty ?? "nil"), cwd=\(cwd ?? "nil"), terminal=\(terminalInfo?.appName ?? "nil")")

                let emoji = TmuxProvider.terminalBundleIdToEmoji(terminalInfo?.bundleId)
                let aiProcess = AIProcess(
                    pid: pid,
                    command: commandName,
                    workingDirectory: cwd ?? "~",
                    terminalBundleId: terminalInfo?.bundleId,
                    terminalAppName: terminalInfo?.appName,
                    terminalEmoji: emoji,
                    title: "\(commandName) (pid: \(pid))"
                )

                // Why: terminalBundleId が無い AI プロセスは restoreSelected()/activationTarget(for:) が
                //      nil になり、ユーザーが選んでもフォーカス切り替えできないため表示対象から外す。
                guard isRecoverableAIProcess(aiProcess) else {
                    log("  pid \(pid): skip (unrecoverable terminal)")
                    continue
                }

                result.append(aiProcess)
            }
        }

        log("total non-tmux AI processes: \(result.count)")
        return result
    }

    // MARK: - Private Helpers

    /// pgrep でコマンド名からPIDを取得
    static func processNamePattern(_ name: String) -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        return "(^|/)" + escapedName + "([[:space:]]|$)"
    }

    static func findProcessesByName(_ name: String) -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", processNamePattern(name)]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// 同一リフレッシュサイクル内のメモ化キャッシュ
    private static var tmuxCheckCache: [pid_t: Bool] = [:]

    /// メモ化キャッシュをクリア（リフレッシュサイクル開始時に呼ぶ）
    static func clearTmuxCheckCache() {
        tmuxCheckCache = [:]
    }

    /// プロセスがtmux内で実行されているか判定（親プロセスチェーンに tmux があるか）
    /// sysctl を使用してサブプロセス spawn を回避
    static func isProcessInTmux(_ pid: pid_t) -> Bool {
        if let cached = tmuxCheckCache[pid] {
            return cached
        }
        var currentPid = pid
        var visited: Set<pid_t> = []
        for _ in 0..<20 {
            guard let ppid = TmuxProvider.sysctlParentPID(currentPid) else { break }
            if visited.contains(ppid) { break }  // ループ検出
            visited.insert(ppid)

            // メモ化チェック: 祖先が既に判定済みなら再利用
            if let cached = tmuxCheckCache[ppid] {
                tmuxCheckCache[pid] = cached
                return cached
            }

            if let name = TmuxProvider.sysctlProcessName(ppid),
               name.contains("tmux") {
                tmuxCheckCache[pid] = true
                return true
            }
            currentPid = ppid
        }
        tmuxCheckCache[pid] = false
        return false
    }

    /// ps でプロセスのTTYを取得
    static func getTTYForProcess(_ pid: pid_t) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "tty="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        let tty = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return tty.isEmpty || tty == "??" ? nil : tty
    }

    /// proc_pidinfo でプロセスの作業ディレクトリを取得（lsof の100-300ms → ~1ms）
    /// 失敗時は従来の lsof にフォールバック
    static func getWorkingDirectory(_ pid: pid_t) -> String? {
        // Fast path: proc_pidinfo (Darwin API)
        var vnodeInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let ret = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnodeInfo, Int32(size))
        if ret == Int32(size) {
            let path = withUnsafePointer(to: &vnodeInfo.pvi_cdir.vip_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cString in
                    String(cString: cString)
                }
            }
            if !path.isEmpty {
                return path
            }
        }

        // Fallback: lsof (proc_pidinfo が失敗した場合)
        return getWorkingDirectoryViaLsof(pid)
    }

    /// 従来の lsof ベース実装（フォールバック用）
    private static func getWorkingDirectoryViaLsof(_ pid: pid_t) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-p", "\(pid)", "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in output.split(separator: "\n") {
            if line.hasPrefix("n") && !line.hasPrefix("n ") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    /// TTY名からターミナルアプリを特定（TmuxProvider.findTerminalAppForTTY を再利用）
    private static func findTerminalForTTY(_ tty: String?) -> (bundleId: String?, appName: String)? {
        guard let tty = tty else { return nil }
        let ttyName = tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
        return TmuxProvider.findTerminalAppForTTY(ttyName)
    }
}
