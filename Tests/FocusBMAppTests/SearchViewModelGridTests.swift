import Testing
import Foundation
@testable import FocusBMApp
@testable import FocusBMLib

// MARK: - Helpers

private func makeBookmarkItem(name: String) -> Bookmark {
    Bookmark(
        id: name,
        appName: name,
        bundleIdPattern: nil,
        context: "",
        state: .app(windowTitle: ""),
        createdAt: "2024-01-01T00:00:00Z"
    )
}

private func makeVM(count: Int, columns: Int? = nil) -> SearchViewModel {
    let vm = SearchViewModel()
    var settings = AppSettings()
    settings.bookmarkListColumns = columns
    vm.appSettings = settings
    vm.bookmarks = (0..<count).map { makeBookmarkItem(name: "bm\($0)") }
    vm.updateItems()
    return vm
}

// MARK: - moveUp / moveDown (table layout: always ±1)

@Test func test_moveDown_movesByOne() {
    let vm = makeVM(count: 4)
    vm.selectedIndex = 0
    vm.moveDown()
    #expect(vm.selectedIndex == 1)
}

@Test func test_moveUp_movesByOne() {
    let vm = makeVM(count: 4)
    vm.selectedIndex = 2
    vm.moveUp()
    #expect(vm.selectedIndex == 1)
}

@Test func test_moveUp_atTop_clamps() {
    let vm = makeVM(count: 4)
    vm.selectedIndex = 0
    vm.moveUp()
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveDown_atBottom_clamps() {
    let vm = makeVM(count: 4)
    vm.selectedIndex = 3
    vm.moveDown()
    #expect(vm.selectedIndex == 3)
}

@Test func test_moveDown_ignoresBookmarkListColumns() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 0
    vm.moveDown()
    #expect(vm.selectedIndex == 1)
}

@Test func test_moveUp_ignoresBookmarkListColumns() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 3
    vm.moveUp()
    #expect(vm.selectedIndex == 2)
}

@Test func test_moveDown_columns2_atBottom_clamps() {
    let vm = makeVM(count: 3, columns: 2)
    vm.selectedIndex = 2
    vm.moveDown()
    #expect(vm.selectedIndex == 2)
}

// MARK: - selectByDigit

@Test func test_selectByDigit_success() {
    let vm = makeVM(count: 4)
    let result = vm.selectByDigit(1)
    #expect(result == true)
    #expect(vm.selectedIndex == 0)
}

@Test func test_selectByDigit_secondItem_setsIndexToOne() {
    let vm = makeVM(count: 4)
    let result = vm.selectByDigit(2)
    #expect(result == true)
    #expect(vm.selectedIndex == 1)
}

@Test func test_selectByDigit_outOfRange_returnsFalse() {
    let vm = makeVM(count: 2)
    #expect(vm.selectByDigit(9) == false)
}

@Test func test_selectByDigit_zeroIsInvalid() {
    let vm = makeVM(count: 4)
    #expect(vm.selectByDigit(0) == false)
}
