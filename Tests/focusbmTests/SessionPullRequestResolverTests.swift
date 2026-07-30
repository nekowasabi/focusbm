import Foundation
import Testing
@testable import FocusBMLib

private func temporaryClaudeHome() throws -> URL {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("focusbm-session-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    return home
}

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(text.utf8).write(to: url)
}

@Test func claudeResolver_returnsTheUniqueSessionPullRequest() throws {
    let home = try temporaryClaudeHome()
    defer { try? FileManager.default.removeItem(at: home) }

    try write("{\"pid\":123,\"sessionId\":\"session-1\"}", to: home
        .appendingPathComponent(".claude/sessions/123.json"))
    try write("{\"entries\":[{\"sessionId\":\"session-1\",\"prUrl\":\"https://github.com/acme/focusbm/pull/42\"}]}", to: home
        .appendingPathComponent(".claude/projects/project/sessions-index.json"))

    let resolver = ClaudeSessionPullRequestResolver(homeDirectory: home)
    #expect(resolver.resolveURL(for: 123)?.absoluteString == "https://github.com/acme/focusbm/pull/42")
}

@Test func claudeResolver_resolvesPullRequestFromWorkingDirectory() throws {
    let home = try temporaryClaudeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let checkout = home.appendingPathComponent("checkout")
    try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)

    var requestedDirectory: String?
    let resolver = ClaudeSessionPullRequestResolver(
        homeDirectory: home,
        fileManager: .default,
        pullRequestURLProvider: { directory in
            requestedDirectory = directory
            return "https://github.com/acme/focusbm/pull/953\n"
        }
    )

    #expect(resolver.resolveURL(for: 123, workingDirectory: checkout.path)?.absoluteString == "https://github.com/acme/focusbm/pull/953")
    #expect(requestedDirectory == checkout.path)
}

@Test func claudeResolver_fallsBackToSessionIndexWhenWorkingDirectoryHasNoPullRequest() throws {
    let home = try temporaryClaudeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let checkout = home.appendingPathComponent("checkout")
    try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)

    try write("{\"pid\":123,\"sessionId\":\"session-1\"}", to: home
        .appendingPathComponent(".claude/sessions/123.json"))
    try write("{\"entries\":[{\"sessionId\":\"session-1\",\"prUrl\":\"https://github.com/acme/focusbm/pull/42\"}]}", to: home
        .appendingPathComponent(".claude/projects/project/sessions-index.json"))

    let resolver = ClaudeSessionPullRequestResolver(
        homeDirectory: home,
        fileManager: .default,
        pullRequestURLProvider: { _ in nil }
    )

    #expect(resolver.resolveURL(for: 123, workingDirectory: checkout.path)?.absoluteString == "https://github.com/acme/focusbm/pull/42")
}

@Test func claudeResolver_rejectsMissingCorruptOrMismatchedData() throws {
    let home = try temporaryClaudeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let resolver = ClaudeSessionPullRequestResolver(homeDirectory: home)

    #expect(resolver.resolveURL(for: 123) == nil)

    try write("{", to: home.appendingPathComponent(".claude/sessions/123.json"))
    #expect(resolver.resolveURL(for: 123) == nil)

    try write("{\"pid\":999,\"sessionId\":\"session-1\"}", to: home
        .appendingPathComponent(".claude/sessions/123.json"))
    try write("{\"entries\":[{\"sessionId\":\"session-1\"}]}", to: home
        .appendingPathComponent(".claude/projects/project/sessions-index.json"))
    #expect(resolver.resolveURL(for: 123) == nil)
}

@Test func sessionPullRequestResolver_rejectsInvalidAndConflictingURLs() {
    #expect(SessionPullRequestResolver.validatedPullRequestURL("http://github.com/acme/focusbm/pull/42") == nil)
    #expect(SessionPullRequestResolver.validatedPullRequestURL("https://example.com/acme/focusbm/pull/42") == nil)
    #expect(SessionPullRequestResolver.validatedPullRequestURL("https://github.com/acme/focusbm/issues/42") == nil)
    #expect(SessionPullRequestResolver.validatedPullRequestURL("https://github.com/acme/focusbm/pull/0") == nil)

    let url = "https://github.com/acme/focusbm/pull/42"
    #expect(SessionPullRequestResolver.uniquePullRequestURL(from: [url, url])?.absoluteString == url)
    #expect(SessionPullRequestResolver.uniquePullRequestURL(from: [url, "https://github.com/acme/focusbm/pull/43"]) == nil)
    #expect(SessionPullRequestResolver.uniquePullRequestURL(from: ["not-a-url"]) == nil)
}

@Test func sessionPullRequestResolver_supportsClaudeAndCodexOnly() {
    let resolver = SessionPullRequestResolver()
    #expect(resolver.supports(command: "claude"))
    #expect(resolver.supports(command: "codex"))
    #expect(!resolver.supports(command: "aider"))
}

/// Verifies that Codex resolves only the working-directory PR source.
@Test func codexResolver_resolvesFromWorkingDirectoryWithoutSessionIndex() throws {
    let home = try temporaryClaudeHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let checkout = home.appendingPathComponent("checkout")
    try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)

    let resolver = ClaudeSessionPullRequestResolver(
        command: "codex",
        homeDirectory: home,
        fileManager: .default,
        pullRequestURLProvider: { _ in "https://github.com/acme/focusbm/pull/42" }
    )
    let url = resolver.resolveURL(for: 999, workingDirectory: checkout.path)
    #expect(url?.absoluteString == "https://github.com/acme/focusbm/pull/42")
    #expect(resolver.resolveURL(for: 999) == nil)
}
