import ArgumentParser
import Foundation
import FocusBMLib

private func pipeThroughFzf(_ input: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["fzf", "--with-nth=2..", "--delimiter=\t"]
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    try process.run()
    inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
    inputPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw AppleScriptError.executionFailed("fzf cancelled or not found")
    }
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

@main
struct FocusBM: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focusbm",
        abstract: "macOS アプリフォーカスのブックマークツール",
        subcommands: [Add.self, Edit.self, Save.self, Restore.self, RestoreContext.self, List.self, Delete.self, Switch.self, TmuxList.self]
    )
}

// MARK: - add

extension FocusBM {
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "ブックマークを手動追加（YAML テンプレート生成）"
        )

        @Argument(help: "ブックマーク名")
        var name: String

        @Argument(help: "アプリの bundleId（正規表現可）")
        var bundleIdPattern: String

        @Option(name: .shortAndLong, help: "コンテキスト")
        var context: String = "default"

        @Option(help: "表示用アプリ名（省略時は bundleIdPattern）")
        var appName: String?

        @Option(help: "ブラウザ URL パターン（指定するとブラウザブックマークになる）")
        var url: String?

        @Option(help: "タブインデックス")
        var tabIndex: Int?

        mutating func run() throws {
            let displayName = appName ?? bundleIdPattern
            let state: AppState
            if let urlPattern = url {
                state = .browser(urlPattern: urlPattern, title: displayName, tabIndex: tabIndex)
            } else {
                state = .app(windowTitle: "")
            }

            var store = BookmarkStore.loadYAML()
            store.bookmarks.removeAll { $0.id == name }
            let bookmark = Bookmark(
                id: name,
                appName: displayName,
                bundleIdPattern: bundleIdPattern,
                context: context,
                state: state,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            store.bookmarks.append(bookmark)
            try store.saveYAML()
            print("✓ Added: [\(name)] \(bookmark.description)")
            print("  → \(BookmarkStore.storePath.path) を編集して詳細を調整できます")
        }
    }
}

// MARK: - edit

extension FocusBM {
    struct Edit: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "ブックマーク YAML をエディタで開く"
        )

        mutating func run() throws {
            let path = BookmarkStore.storePath.path
            // ファイルが存在しない場合は空の store を作成
            if !FileManager.default.fileExists(atPath: path) {
                try BookmarkStore().saveYAML()
            }
            let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vi"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editor, path]
            process.standardInput = FileHandle.standardInput
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
            try process.run()
            process.waitUntilExit()
        }
    }
}

// MARK: - save

extension FocusBM {
    struct Save: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "現在フォーカス中のアプリからブックマーク保存（補助コマンド）"
        )

        @Argument(help: "ブックマーク名（エイリアス）")
        var name: String

        @Option(name: .shortAndLong, help: "コンテキスト（タグ）")
        var context: String = "default"

        mutating func run() throws {
            let (appName, bundleId, windowTitle) = try AppleScriptBridge.getFrontAppInfo()

            let state: AppState
            if AppleScriptBridge.isBrowser(bundleId: bundleId) {
                state = (try? AppleScriptBridge.getBrowserState(bundleId: bundleId)) ?? .app(windowTitle: windowTitle)
            } else {
                state = .app(windowTitle: windowTitle)
            }

            var store = BookmarkStore.loadYAML()
            // 同名が存在する場合は上書き
            store.bookmarks.removeAll { $0.id == name }
            let bookmark = Bookmark(
                id: name,
                appName: appName,
                bundleIdPattern: bundleId,
                context: context,
                state: state,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            store.bookmarks.append(bookmark)
            try store.saveYAML()

            print("✓ Saved: [\(name)] \(bookmark.description)")
        }
    }
}

// MARK: - restore

extension FocusBM {
    struct Restore: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "ブックマークを復元してフォーカス"
        )

        @Argument(help: "ブックマーク名")
        var name: String

        mutating func run() throws {
            let store = BookmarkStore.loadYAML()
            guard let bookmark = store.bookmarks.first(where: { $0.id == name }) else {
                throw ValidationError("Bookmark '\(name)' not found. Run `focusbm list` to see available bookmarks.")
            }

            try BookmarkRestorer.restore(bookmark)
            print("✓ Restored: [\(name)] \(bookmark.description)")
        }
    }
}

// MARK: - restore-context

extension FocusBM {
    struct RestoreContext: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "restore-context",
            abstract: "コンテキスト内の全ブックマークを一括復元"
        )

        @Argument(help: "コンテキスト名")
        var context: String

        @Flag(name: .shortAndLong, help: "各復元の間に待機（0.5秒）")
        var wait: Bool = false

        mutating func run() throws {
            let store = BookmarkStore.loadYAML()
            let targets = store.bookmarks.filter { $0.context == context }

            guard !targets.isEmpty else {
                throw ValidationError("No bookmarks found in context '\(context)'. Run `focusbm list` to see available contexts.")
            }

            print("Restoring \(targets.count) bookmark(s) in context '\(context)'...")
            var errors: [(String, Error)] = []

            for bm in targets {
                do {
                    try BookmarkRestorer.restore(bm)
                    print("  ✓ \(bm.id): \(bm.description)")
                    if wait {
                        Thread.sleep(forTimeInterval: 0.5)
                    }
                } catch {
                    errors.append((bm.id, error))
                    print("  ✗ \(bm.id): \(error.localizedDescription)")
                }
            }

            if errors.isEmpty {
                print("Done. All \(targets.count) bookmark(s) restored.")
            } else {
                print("Done with \(errors.count) error(s).")
            }
        }
    }
}

// MARK: - list

extension FocusBM {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "ブックマーク一覧を表示"
        )

        @Option(name: .shortAndLong, help: "コンテキストで絞り込み")
        var context: String?

        @Option(name: .long, help: "出力フォーマット: human | fzf")
        var format: String = "human"

        mutating func run() throws {
            let store = BookmarkStore.loadYAML()
            var bookmarks = store.bookmarks

            if let ctx = context {
                bookmarks = bookmarks.filter { $0.context == ctx }
            }

            switch format {
            case "fzf":
                outputFzf(bookmarks)
            default:
                outputHuman(bookmarks)
            }
        }

        private func outputHuman(_ bookmarks: [Bookmark]) {
            if bookmarks.isEmpty { print("No bookmarks found."); return }
            let grouped = Dictionary(grouping: bookmarks) { $0.context }
            for ctx in grouped.keys.sorted() {
                print("\n[\(ctx)]")
                for bm in grouped[ctx]! {
                    print("  \(bm.id.padding(toLength: 20, withPad: " ", startingAt: 0))  \(bm.description)")
                }
            }
        }

        private func outputFzf(_ bookmarks: [Bookmark]) {
            for bm in bookmarks {
                print("\(bm.id)\t\(bm.context)/\(bm.id) (\(bm.appName))")
            }
        }
    }
}

// MARK: - switch (fzf interactive)

extension FocusBM {
    struct Switch: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "switch",
            abstract: "fzf でブックマークを絞り込み選択して復元"
        )

        @Option(name: .shortAndLong, help: "コンテキスト絞り込み")
        var context: String?

        mutating func run() throws {
            let store = BookmarkStore.loadYAML()
            var bookmarks = store.bookmarks

            if let ctx = context {
                bookmarks = bookmarks.filter { $0.context == ctx }
            }

            guard !bookmarks.isEmpty else {
                print("ブックマークが見つかりません")
                return
            }

            let lines = bookmarks.map { "\($0.id)\t\($0.context)/\($0.id) (\($0.appName))" }
            let input = lines.joined(separator: "\n")
            let selected = try pipeThroughFzf(input)
            guard let id = selected.split(separator: "\t").first.map(String.init) else { return }
            guard let bm = bookmarks.first(where: { $0.id == id }) else { return }
            try BookmarkRestorer.restore(bm)
            print("✓ Switched to: [\(bm.id)] \(bm.description)")
        }
    }
}

// MARK: - tmux-list

extension FocusBM {
    struct TmuxList: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "tmux-list",
            abstract: "tmux 内で動作中の AI エージェントセッションを一覧表示"
        )

        mutating func run() throws {
            guard TmuxProvider.isTmuxAvailable() else {
                print("tmux is not running")
                return
            }

            let panes = try TmuxProvider.listAIAgentPanes()

            if panes.isEmpty {
                print("No AI agent sessions found.")
                return
            }

            print("Found \(panes.count) AI agent session(s):")
            for (index, pane) in panes.enumerated() {
                print("  [\(index)] \(pane.displayName) \(pane.currentPath)")
            }
        }
    }
}

// MARK: - delete

extension FocusBM {
    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "ブックマークを削除"
        )

        @Argument(help: "ブックマーク名")
        var name: String

        mutating func run() throws {
            var store = BookmarkStore.loadYAML()
            let before = store.bookmarks.count
            store.bookmarks.removeAll { $0.id == name }

            guard store.bookmarks.count < before else {
                throw ValidationError("Bookmark '\(name)' not found.")
            }

            try store.saveYAML()
            print("✓ Deleted: \(name)")
        }
    }
}
