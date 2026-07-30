import Foundation

public enum GitHubPullRequestCLI {
    public static let timeoutSeconds: TimeInterval = 5

    public static func resolveURLString(
        workingDirectory: String,
        timeout: TimeInterval = timeoutSeconds
    ) -> String? {
        resolveURLString(
            workingDirectory: workingDirectory,
            timeout: timeout,
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["gh", "pr", "view", "--json", "url", "--jq", ".url"]
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
