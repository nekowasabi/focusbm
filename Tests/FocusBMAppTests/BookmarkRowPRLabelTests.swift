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

private func bookmarkRowWithURL(_ urlPattern: String = "github.com/myorg/pull") -> SearchItem {
    .bookmark(Bookmark(
        id: "gh",
        appName: "Firefox",
        bundleIdPattern: nil,
        context: "work",
        state: .browser(urlPattern: urlPattern, title: "PR", tabIndex: nil, urlPrefix: nil),
        createdAt: "2026-01-01T00:00:00Z"
    ))
}

private func bookmarkRow(
    item: SearchItem = bookmarkRowItem(),
    prLabel: String? = nil
) -> BookmarkRow {
    BookmarkRow(
        searchItem: item, isSelected: false, shortcutLabel: nil,
        columns: TableColumns(totalWidth: 800), directNumberKeys: true, fontSize: nil, fontName: nil,
        prLabel: prLabel
    )
}

/// Verifies the named PR behavior without network access.
@Test func bookmarkRow_prLabelDefaultsToNil() {
    let row = bookmarkRow()
    #expect(row.prLabel == nil)
    #expect(row.prColumnText == nil)
}

/// Verifies the named PR behavior without network access.
@Test func bookmarkRow_prLabelAcceptsFormattedString() {
    let row = bookmarkRow(prLabel: "#123")
    #expect(row.prLabel == "#123")
    #expect(row.prColumnText == "#123")
}

@Test func bookmarkRow_prColumnShowsPrLabelNotUrlPattern() {
    let url = "github.com/myorg/pull"
    let item = bookmarkRowWithURL(url)
    let row = bookmarkRow(item: item, prLabel: "#123")
    #expect(item.urlPattern == url)
    #expect(row.prLabel == "#123")
    #expect(row.prColumnText == "#123")
    #expect(row.prColumnText != url)
}

@Test func bookmarkRow_prColumnOmitsUrlPatternWhenPrLabelMissing() {
    let url = "github.com/myorg/pull"
    let item = bookmarkRowWithURL(url)
    let row = bookmarkRow(item: item)
    #expect(item.urlPattern == url)
    #expect(row.prLabel == nil)
    #expect(row.prColumnText == nil)
}

@Test func tableColumns_splitsRemainingWidth3to2to2() {
    let c = TableColumns(totalWidth: 52 + 120 + 20 + 700)
    #expect(c.name == 300)
    #expect(c.detail == 200)
    #expect(c.pr == 200)
}
