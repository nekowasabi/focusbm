import Foundation

public struct ClaudeSessionPullRequestResolver: SessionPullRequestAgentResolver {
    public let command: String

    private let homeDirectory: URL
    private let fileManager: FileManager
    private let pullRequestURLProvider: (String) -> String?

    public init(
        command: String = "claude",
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.init(
            command: command,
            homeDirectory: homeDirectory,
            fileManager: fileManager,
            pullRequestURLProvider: {
                GitHubPullRequestCLI.resolveURLString(
                    workingDirectory: $0,
                    timeout: GitHubPullRequestCLI.timeoutSeconds
                )
            }
        )
    }

    init(
        command: String = "claude",
        homeDirectory: URL,
        fileManager: FileManager,
        pullRequestURLProvider: @escaping (String) -> String?
    ) {
        self.command = command
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
        self.pullRequestURLProvider = pullRequestURLProvider
    }

    public func resolveURL(for pid: pid_t?, workingDirectory: String? = nil) -> URL? {
        if let workingDirectory,
           let url = workingDirectoryPullRequestURL(in: workingDirectory) {
            return url
        }
        guard command.lowercased() == "claude" else { return nil }
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

    // Why: Codex has no compatible Claude session index, so only Claude may use this fallback.
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
