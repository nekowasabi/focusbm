import SwiftUI
import Testing
@testable import FocusBMApp
@testable import FocusBMLib

@Test func ansiText_plainTextPassthrough() {
    let a = ANSIText.attributed("hello\nworld")
    #expect(String(a.characters) == "hello\nworld")
    #expect(a.runs.first?.foregroundColor == ANSIText.defaultForeground)
}

@Test func ansiText_256ColorRunAndReset() {
    let a = ANSIText.attributed("\u{1b}[38;5;174mred\u{1b}[0m plain")
    #expect(String(a.characters) == "red plain")
    let runs = Array(a.runs)
    #expect(runs.count == 2)
    #expect(runs[0].foregroundColor == ANSIText.palette(174))
    #expect(runs[1].foregroundColor == ANSIText.defaultForeground)
}

@Test func ansiText_dropsNonSGRAndLeavesNoEscape() {
    let a = ANSIText.attributed("\u{1b}[2K\u{1b}[1;38;2;1;2;3mx\u{1b}[m")
    #expect(String(a.characters) == "x")
}

@Test func ansiText_escapeOnlyTrailingLinesTrimmed() {
    let vm = SearchViewModel()
    vm.paneScreenCaptureProvider = { _ in "\u{1b}[32mok\u{1b}[0m\n\u{1b}[0m\n\u{1b}[49m  \n" }
    let pane = TmuxPane(paneId: "%1", sessionName: "0", windowIndex: 1, windowName: "claude",
                        command: "claude", title: "t", currentPath: "/tmp")
    vm.searchItems = [.tmuxPane(pane)]
    _ = vm.showAllAgentPreviews()
    guard case .single(let cap)? = vm.screenPreview else { Issue.record("no preview"); return }
    #expect(cap.text == "\u{1b}[32mok\u{1b}[0m")
}
