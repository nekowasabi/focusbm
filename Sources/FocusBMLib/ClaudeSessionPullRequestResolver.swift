import Foundation

public struct ClaudeSessionPullRequestResolver: SessionPullRequestAgentResolver {
    public let command = "claude"

    private let homeDirectory: URL
    private let fileManager: FileManager
    private let pullRequestURLProvider: (String) -> String?

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.init(
            homeDirectory: homeDirectory,
            fileManager: fileManager,
            pullRequestURLProvider: Self.pullRequestURLFromGitHubCLI
        )
    }

    init(
        homeDirectory: URL,
        fileManager: FileManager,
        pullRequestURLProvider: @escaping (String) -> String?
    ) {
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
        self.pullRequestURLProvider = pullRequestURLProvider
    }

    public func resolveURL(for pid: pid_t?, workingDirectory: String? = nil) -> URL? {
        if let workingDirectory,
           let url = workingDirectoryPullRequestURL(in: workingDirectory) {
            return url
        }
        return sessionIndexPullRequestURL(for: pid)
    }

    private func workingDirectoryPullRequestURL(in workingDirectory: String) -> URL? {
        guard workingDirectory != "~",
              fileManager.fileExists(atPath: workingDirectory),
              let value = pullRequestURLProvider(workingDirectory) else {
            return nil
        }
        return SessionPullRequestResolver.uniquePullRequestURL(
            from: [value.trimmingCharacters(in: .whitespacesAndNewlines)]
        )
    }

    // Why: Ask gh for the branch's current PR instead of relying only on Claude's session index.
    //      Active Claude sessions can be absent from that index while their worktree has a PR.
    private static func pullRequestURLFromGitHubCLI(in workingDirectory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "pr", "view", "--json", "url", "--jq", ".url"]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        let outputPipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Why: Use the PID-specific registry path instead of scanning all registrations,
    //      so stale entries and another live session cannot be selected accidentally.
    private func sessionIndexPullRequestURL(for pid: pid_t?) -> URL? {
        guard let sessionID = sessionID(for: pid) else { return nil }
        let projectsDirectory = homeDirectory.appendingPathComponent(CLAUDE_PROJECTS_DIR)
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [],
            errorHandler: nil
        ) else {
            return nil
        }

        var candidates: [String] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "sessions-index.json" else { continue }
            guard let data = try? Data(contentsOf: fileURL),
                  let index = try? JSONDecoder().decode(SessionIndex.self, from: data) else {
                continue
            }
            candidates.append(contentsOf: index.entries
                .filter { $0.sessionId == sessionID }
                .compactMap { $0.prUrl })
        }
        return SessionPullRequestResolver.uniquePullRequestURL(from: candidates)
    }

    private func sessionID(for pid: pid_t?) -> String? {
        guard let pid else { return nil }
        let registryURL = homeDirectory
            .appendingPathComponent(CLAUDE_SESSION_REGISTRY_DIR)
            .appendingPathComponent("\(pid).json")
        guard let data = try? Data(contentsOf: registryURL),
              let registry = try? JSONDecoder().decode(SessionRegistry.self, from: data),
              registry.pid == pid,
              !registry.sessionId.isEmpty else {
            return nil
        }
        return registry.sessionId
    }
}

private struct SessionRegistry: Decodable {
    let pid: pid_t
    let sessionId: String
}

private struct SessionIndex: Decodable {
    let entries: [SessionIndexEntry]
}

private struct SessionIndexEntry: Decodable {
    let sessionId: String
    let prUrl: String?
}
