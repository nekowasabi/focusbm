import Foundation

private final class DataBox: @unchecked Sendable { var value = Data() }

extension Process {
    /// Runs the process, drains stdout and stderr to EOF, then waits for exit.
    // Why: waitUntilExit() before reading deadlocks once output exceeds the pipe buffer.
    //      macOS shrinks new pipe buffers to 512 bytes under system-wide pipe memory pressure,
    //      so even a 4KB `tmux list-panes` hung forever (measured 2026-10-06).
    //      stderr is drained on a dedicated Thread, not a GCD queue: callers already block GCD
    //      workers, and a starved pool left the reader unscheduled (seen under parallel tests).
    public func runDrainingOutput(stdin: Data? = nil) throws -> (stdout: Data, stderr: Data) {
        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe = Pipe()
        standardOutput = outPipe
        standardError = errPipe
        if stdin != nil { standardInput = inPipe }

        try run()

        let errBox = DataBox()
        let errDone = DispatchSemaphore(value: 0)
        Thread {
            errBox.value = errPipe.fileHandleForReading.readDataToEndOfFile()
            errDone.signal()
        }.start()
        if let stdin {
            inPipe.fileHandleForWriting.write(stdin)
            inPipe.fileHandleForWriting.closeFile()
        }
        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        errDone.wait()
        waitUntilExit()
        return (out, errBox.value)
    }
}
