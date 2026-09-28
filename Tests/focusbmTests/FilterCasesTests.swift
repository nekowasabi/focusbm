import Testing
import Foundation
@testable import FocusBMLib

// Shared with dotnet/FocusBM.Core.Tests/FilterCasesTests.cs via spec/filter-cases.json.
private struct FilterCases: Decodable {
    struct Fuzzy: Decodable { let name: String; let text: String; let query: String; let expected: Int? }
    struct Row: Decodable { let name: String; let texts: [String]; let query: String; let expected: Int? }
    struct Renumber: Decodable { let name: String; let query: String; let count: Int; let labels: [String?]? }
    let fuzzy: [Fuzzy]
    let rows: [Row]
    let renumber: [Renumber]

    static func load() throws -> FilterCases {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("spec/filter-cases.json"))
        return try JSONDecoder().decode(FilterCases.self, from: data)
    }
}

@Test func filterCases_fuzzyScore() throws {
    for c in try FilterCases.load().fuzzy {
        #expect(BookmarkSearcher.fuzzyScore(text: c.text, query: c.query) == c.expected, "\(c.name)")
    }
}

@Test func filterCases_rowScore() throws {
    for c in try FilterCases.load().rows {
        #expect(BookmarkSearcher.score(texts: c.texts, query: c.query) == c.expected, "\(c.name)")
    }
}

@Test func filterCases_renumber() throws {
    for c in try FilterCases.load().renumber {
        #expect(BookmarkSearcher.filteredNumberLabels(query: c.query, count: c.count) == c.labels, "\(c.name)")
    }
}
