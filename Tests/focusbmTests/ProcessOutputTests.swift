import Foundation
import Testing
@testable import FocusBMLib

private final class ResultBox: @unchecked Sendable { var value: (stdout: Data, stderr: Data)? }

/// Output far larger than any pipe buffer on both streams must not deadlock.
@Test func runDrainingOutput_largeStdoutAndStderr_returnsAllBytes() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "head -c 300000 /dev/zero; head -c 200000 /dev/zero >&2"]

    let box = ResultBox()
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        box.value = try? process.runDrainingOutput()
        done.signal()
    }

    #expect(done.wait(timeout: .now() + 10) == .success)
    #expect(box.value?.stdout.count == 300000)
    #expect(box.value?.stderr.count == 200000)
    #expect(process.terminationStatus == 0)
}

@Test func runDrainingOutput_feedsStdin() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/cat")
    let result = try process.runDrainingOutput(stdin: Data("hello".utf8))
    #expect(String(data: result.stdout, encoding: .utf8) == "hello")
}
