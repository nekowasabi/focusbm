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
    static let aiAgentCommands = ["claude", "aider", "gemini", "copilot", "codex"]

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

                let tty = getTTYForProcess(pid)
                let cwd = getWorkingDirectory(pid)
                let terminalInfo = findTerminalForTTY(tty)

                log("  pid \(pid): tty=\(tty ?? "nil"), cwd=\(cwd ?? "nil"), terminal=\(terminalInfo?.appName ?? "nil")")

                let emoji = TmuxProvider.terminalBundleIdToEmoji(terminalInfo?.bundleId)

                result.append(AIProcess(
                    pid: pid,
                    command: commandName,
                    workingDirectory: cwd ?? "~",
                    terminalBundleId: terminalInfo?.bundleId,
                    terminalAppName: terminalInfo?.appName,
                    terminalEmoji: emoji,
                    title: "\(commandName) (pid: \(pid))"
                ))
            }
        }

        log("total non-tmux AI processes: \(result.count)")
        return result
    }

    // MARK: - Private Helpers

    /// pgrep でコマンド名からPIDを取得
    static func findProcessesByName(_ name: String) -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "bin/" + name]
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
