import Foundation

/// `ps -axo pid=,ppid=,tty=,stat=,args=` を 1 回だけ spawn して保持するプロセス表。
// Why: 絞り込み画面の AI プロセス取得は pgrep×10 + プロセス毎の ps×3 が主コストだった。
//      1 回のスナップショットに集約し、args/tty/stat/ppid をインメモリ参照に置き換える。
public struct ProcessSnapshot {

    public struct Entry {
        public let pid: pid_t
        public let ppid: pid_t
        /// TTY 名（"/dev/" プレフィックス無しに正規化。ps が "?"/"??" を返す場合は nil）
        public let tty: String?
        /// stat カラムの先頭が "Z" ならゾンビ（isProcessAlive の p_stat != SZOMB と同義）
        public let isZombie: Bool
        /// フルコマンドライン（pgrep -f の検索対象と同じ文字列）
        public let args: String

        public init(pid: pid_t, ppid: pid_t, tty: String?, isZombie: Bool, args: String) {
            self.pid = pid
            self.ppid = ppid
            self.tty = tty
            self.isZombie = isZombie
            self.args = args
        }
    }

    /// pid 昇順（pgrep の出力順に合わせる）
    public let entries: [Entry]
    public let byPid: [pid_t: Entry]
    private let pidsByTTY: [String: [pid_t]]
    private let childrenByParent: [pid_t: [pid_t]]

    public init(entries: [Entry]) {
        let sorted = entries.sorted { $0.pid < $1.pid }
        self.entries = sorted
        var byPid: [pid_t: Entry] = [:]
        var pidsByTTY: [String: [pid_t]] = [:]
        var childrenByParent: [pid_t: [pid_t]] = [:]
        for entry in sorted {
            byPid[entry.pid] = entry
            if let tty = entry.tty {
                pidsByTTY[tty, default: []].append(entry.pid)
            }
            childrenByParent[entry.ppid, default: []].append(entry.pid)
        }
        self.byPid = byPid
        self.pidsByTTY = pidsByTTY
        self.childrenByParent = childrenByParent
    }

    /// 現在のプロセス表を取得。ps 失敗時は空スナップショット（pgrep 失敗→空と同じ扱い）
    public static func capture() -> ProcessSnapshot {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,tty=,stat=,args="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ProcessSnapshot(entries: [])
        }
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parse(output)
    }

    /// ps -axo 出力のパース。`pid ppid tty stat args(残り全部)` の固定5カラム。
    static func parse(_ output: String) -> ProcessSnapshot {
        var entries: [Entry] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = pid_t(parts[0]),
                  let ppid = pid_t(parts[1]) else { continue }
            let rawTTY = parts[2]
            let tty: String?
            if rawTTY == "?" || rawTTY == "??" {
                tty = nil
            } else {
                let name = rawTTY.hasPrefix("/dev/") ? rawTTY.dropFirst(5) : rawTTY
                tty = String(name)
            }
            let stat = parts[3]
            // Why: maxSplits 残り部分は列パディングの先頭空白を保持する。
            //      `(^|/)name` のような行頭アンカーパターンが args 先頭に効くよう除去する。
            let args = parts.count >= 5
                ? String(parts[4].drop(while: { $0 == " " }))
                : ""
            entries.append(Entry(
                pid: pid,
                ppid: ppid,
                tty: tty,
                isZombie: stat.hasPrefix("Z"),
                args: args
            ))
        }
        return ProcessSnapshot(entries: entries)
    }

    /// TTY に接続する全 pid（"/dev/" あり/なしどちらの指定も可）。ps -t の代替。
    public func pids(onTTY tty: String) -> [pid_t] {
        let name = tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
        return pidsByTTY[name] ?? []
    }

    /// 子孫 pid を BFS で maxDepth まで収集（pgrep -P 多段探索の代替）
    public func descendants(of pid: pid_t, maxDepth: Int = 3) -> [pid_t] {
        var result: [pid_t] = []
        var visited: Set<pid_t> = [pid]
        var level: [pid_t] = [pid]
        for _ in 0..<maxDepth {
            var next: [pid_t] = []
            for parent in level {
                for child in childrenByParent[parent] ?? [] where !visited.contains(child) {
                    visited.insert(child)
                    next.append(child)
                    result.append(child)
                }
            }
            if next.isEmpty { break }
            level = next
        }
        return result
    }

    public func commandLine(for pid: pid_t) -> String? {
        byPid[pid]?.args
    }
}
