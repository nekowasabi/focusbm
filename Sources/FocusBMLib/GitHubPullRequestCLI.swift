import Foundation

public enum GitHubPullRequestCLI {
    public static let timeoutSeconds: TimeInterval = 5
    static let envPath = "/usr/bin/env"
    static let ghArguments = ["pr", "view", "--json", "url", "--jq", ".url"]

    // Why: Adopt candidate-path lookup instead of `/usr/bin/env gh`. Reason: login-item
    //      launchd PATH has no Homebrew, so env cannot find gh while tmux already works.
    static let ghCandidatePaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/usr/bin/gh",
    ]

    struct Launch: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    static func resolvedLaunch(
        candidates: [String] = ghCandidatePaths,
        fileManager: FileManager = .default
    ) -> Launch {
        if let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return Launch(
                executableURL: URL(fileURLWithPath: path),
                arguments: ghArguments
            )
        }
        return Launch(
            executableURL: URL(fileURLWithPath: envPath),
            arguments: ["gh"] + ghArguments
        )
    }

    public static func resolveURLString(
        workingDirectory: String,
        timeout: TimeInterval = timeoutSeconds
    ) -> String? {
        let launch = resolvedLaunch()
        return resolveURLString(
            workingDirectory: workingDirectory,
            timeout: timeout,
            executableURL: launch.executableURL,
            arguments: launch.arguments
        )
    }

    static func resolveURLString(
        workingDirectory: String,
        timeout: TimeInterval,
        executableURL: URL,
        arguments: [String]
    ) -> String? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
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

        let completion = DispatchGroup()
        completion.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            completion.leave()
        }

        guard completion.wait(timeout: .now() + timeout) == .success else {
            if process.isRunning {
                process.terminate()
            }
            completion.wait()
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
