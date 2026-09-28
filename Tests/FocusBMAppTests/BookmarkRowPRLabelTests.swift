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
        columns: TableColumns(totalWidth: 800), directNumberKeys: true, fontSize: nil, fontName: nil
    )
    #expect(row.prLabel == nil)
}

/// Verifies the named PR behavior without network access.
@Test func bookmarkRow_prLabelAcceptsFormattedString() {
    let row = BookmarkRow(
        searchItem: bookmarkRowItem(), isSelected: false, shortcutLabel: nil,
        columns: TableColumns(totalWidth: 800), directNumberKeys: true, fontSize: nil, fontName: nil, prLabel: "#123"
    )
    #expect(row.prLabel == "#123")
}

@Test func tableColumns_splitsRemainingWidth3to2to2() {
    let c = TableColumns(totalWidth: 52 + 120 + 20 + 700)
    #expect(c.name == 300)
    #expect(c.detail == 200)
    #expect(c.pr == 200)
}
