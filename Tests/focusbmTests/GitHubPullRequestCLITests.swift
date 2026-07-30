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
