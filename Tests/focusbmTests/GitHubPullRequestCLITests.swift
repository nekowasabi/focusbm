import Foundation
import Testing
@testable import FocusBMLib

/// Verifies the named CLI behavior without invoking GitHub.
@Test func gitHubPullRequestCLI_returnsTrimmedURL() {
    let value = GitHubPullRequestCLI.resolveURLString(
        workingDirectory: FileManager.default.currentDirectoryPath,
        timeout: GitHubPullRequestCLI.timeoutSeconds,
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "printf 'https://github.com/acme/focusbm/pull/42\\n'"]
    )
    #expect(value == "https://github.com/acme/focusbm/pull/42")
}

/// Verifies the named CLI behavior without invoking GitHub.
@Test func gitHubPullRequestCLI_returnsNilForFailedCommand() {
    let value = GitHubPullRequestCLI.resolveURLString(
        workingDirectory: FileManager.default.currentDirectoryPath,
        timeout: GitHubPullRequestCLI.timeoutSeconds,
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "exit 1"]
    )
    #expect(value == nil)
}

/// Verifies the named CLI behavior without invoking GitHub.
@Test func gitHubPullRequestCLI_terminatesTimedOutCommand() {
    let startedAt = Date()
    let value = GitHubPullRequestCLI.resolveURLString(
        workingDirectory: FileManager.default.currentDirectoryPath,
        timeout: 0.05,
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "sleep 1"]
    )
    #expect(value == nil)
    #expect(Date().timeIntervalSince(startedAt) < 0.5)
}

/// Verifies launchd-style PATH holes are avoided by preferring an absolute gh binary.
@Test func gitHubPullRequestCLI_resolvedLaunchPrefersExecutableCandidate() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("focusbm-gh-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let gh = directory.appendingPathComponent("gh")
    try Data("#!/bin/sh\nprintf 'https://github.com/acme/focusbm/pull/42\\n'\n".utf8)
        .write(to: gh)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: gh.path)

    let missing = directory.appendingPathComponent("missing-gh").path
    let launch = GitHubPullRequestCLI.resolvedLaunch(candidates: [missing, gh.path])

    #expect(launch.executableURL.path == gh.path)
    #expect(launch.arguments == GitHubPullRequestCLI.ghArguments)

    let value = GitHubPullRequestCLI.resolveURLString(
        workingDirectory: FileManager.default.currentDirectoryPath,
        timeout: GitHubPullRequestCLI.timeoutSeconds,
        executableURL: launch.executableURL,
        arguments: launch.arguments
    )
    #expect(value == "https://github.com/acme/focusbm/pull/42")
}

@Test func gitHubPullRequestCLI_resolvedLaunchFallsBackToEnvWhenMissing() {
    let launch = GitHubPullRequestCLI.resolvedLaunch(
        candidates: ["/tmp/focusbm-does-not-exist-gh"]
    )
    #expect(launch.executableURL.path == GitHubPullRequestCLI.envPath)
    #expect(launch.arguments == ["gh"] + GitHubPullRequestCLI.ghArguments)
}

/// Verifies a present but non-executable candidate is skipped, unlike a mere existence check.
@Test func gitHubPullRequestCLI_resolvedLaunchSkipsNonExecutableCandidate() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("focusbm-gh-mode-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let blocked = directory.appendingPathComponent("gh")
    try Data("#!/bin/sh\nexit 1\n".utf8).write(to: blocked)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: blocked.path)

    let usable = directory.appendingPathComponent("gh-ok")
    try Data("#!/bin/sh\nprintf 'https://github.com/acme/focusbm/pull/7\\n'\n".utf8).write(to: usable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: usable.path)

    let launch = GitHubPullRequestCLI.resolvedLaunch(candidates: [blocked.path, usable.path])
    #expect(launch.executableURL.path == usable.path)
    #expect(launch.arguments == GitHubPullRequestCLI.ghArguments)
}
