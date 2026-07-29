import Foundation

public let DEFAULT_OPEN_PR_HOTKEY = "cmd+p"
public let CLAUDE_SESSION_REGISTRY_DIR = ".claude/sessions"
public let CLAUDE_PROJECTS_DIR = ".claude/projects"
public let PR_URL_FIELD = "prUrl"
public let SUPPORTED_PR_HOST = "github.com"

public protocol SessionPullRequestAgentResolver {
    var command: String { get }
    func resolveURL(for pid: pid_t?, workingDirectory: String?) -> URL?
}

public struct SessionPullRequestResolver {
    private let resolvers: [String: SessionPullRequestAgentResolver]

    public init() {
        let resolver = ClaudeSessionPullRequestResolver()
        self.resolvers = [resolver.command: resolver]
    }

    public init(resolvers: [SessionPullRequestAgentResolver]) {
        self.resolvers = Dictionary(uniqueKeysWithValues: resolvers.map { ($0.command.lowercased(), $0) })
    }

    public func supports(command: String) -> Bool {
        resolvers[command.lowercased()] != nil
    }

    public func resolveURL(for process: ProcessProvider.AIProcess) -> URL? {
        guard let resolver = resolvers[process.command.lowercased()] else { return nil }
        return resolver.resolveURL(for: process.pid, workingDirectory: process.workingDirectory)
    }

    // Why: tmux panes expose a working directory but no Claude registry PID, so resolve from the checkout directly.

    public func resolveURL(for command: String, workingDirectory: String) -> URL? {
        guard let resolver = resolvers[command.lowercased()] else { return nil }
        return resolver.resolveURL(for: nil, workingDirectory: workingDirectory)
    }

    // Why: Validate only the structured GitHub PR URL instead of scanning session text.
    //      Conversation and tool output can contain unrelated links.
    public static func validatedPullRequestURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == SUPPORTED_PR_HOST,
              components.user == nil,
              components.password == nil,
              components.port == nil else {
            return nil
        }

        let path = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard path.count == 5,
              path[0].isEmpty,
              !path[1].isEmpty,
              !path[2].isEmpty,
              path[3] == "pull",
              String(path[4]).allSatisfy(\.isNumber),
              Int(path[4]) ?? 0 > 0 else {
            return nil
        }
        return url
    }

    // Why: Return a URL only when all valid candidates collapse to one URL; conflicts fail closed.
    public static func uniquePullRequestURL(from values: [String]) -> URL? {
        let urls = values.compactMap(validatedPullRequestURL)
        let uniqueURLs = Dictionary(grouping: urls, by: \.absoluteString).values.compactMap(\.first)
        guard uniqueURLs.count == 1 else { return nil }
        return uniqueURLs[0]
    }
}
