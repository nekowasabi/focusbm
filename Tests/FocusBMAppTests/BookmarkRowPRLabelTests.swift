import Testing
@testable import FocusBMApp
@testable import FocusBMLib

private func bookmarkRowItem() -> SearchItem {
    .aiProcess(ProcessProvider.AIProcess(
        pid: 1,
        command: "codex",
        workingDirectory: "/tmp/focusbm-row",
        terminalBundleId: nil,
        terminalAppName: nil,
        terminalEmoji: "🤖",
        title: "Codex"
    ))
}

/// Verifies the named PR behavior without network access.
@Test func bookmarkRow_prLabelDefaultsToNil() {
    let row = BookmarkRow(
        searchItem: bookmarkRowItem(), isSelected: false, shortcutLabel: nil,
        directNumberKeys: true, fontSize: nil, fontName: nil
    )
    #expect(row.prLabel == nil)
}

/// Verifies the named PR behavior without network access.
@Test func bookmarkRow_prLabelAcceptsFormattedString() {
    let row = BookmarkRow(
        searchItem: bookmarkRowItem(), isSelected: false, shortcutLabel: nil,
        directNumberKeys: true, fontSize: nil, fontName: nil, prLabel: "#123"
    )
    #expect(row.prLabel == "#123")
}
