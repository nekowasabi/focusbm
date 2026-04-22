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

/// columns=2 で n 件のブックマークを持つ SearchViewModel を構築する
private func makeVM(count: Int, columns: Int = 2) -> SearchViewModel {
    let vm = SearchViewModel()
    var settings = AppSettings()
    settings.bookmarkListColumns = columns == 1 ? nil : columns
    vm.appSettings = settings
    vm.bookmarks = (0..<count).map { makeBookmarkItem(name: "bm\($0)") }
    vm.updateItems()
    return vm
}

// MARK: - columns 派生プロパティ

@Test func test_columns_defaultsToOne_whenAppSettingsNil() {
    let vm = SearchViewModel()
    // appSettings が nil の場合 columns は 1
    #expect(vm.columns == 1)
}

@Test func test_columns_returnsBookmarkListColumns_whenSet() {
    let vm = SearchViewModel()
    var settings = AppSettings()
    settings.bookmarkListColumns = 2
    vm.appSettings = settings
    #expect(vm.columns == 2)
}

// MARK: - indexToGrid / gridToIndex 往復変換 (columns=2)

@Test func test_indexToGrid_columns2_index0() {
    let vm = makeVM(count: 4, columns: 2)
    let grid = vm.indexToGrid(0)
    #expect(grid.row == 0 && grid.col == 0)
}

@Test func test_indexToGrid_columns2_index1() {
    let vm = makeVM(count: 4, columns: 2)
    let grid = vm.indexToGrid(1)
    #expect(grid.row == 0 && grid.col == 1)
}

@Test func test_indexToGrid_columns2_index2() {
    let vm = makeVM(count: 4, columns: 2)
    let grid = vm.indexToGrid(2)
    #expect(grid.row == 1 && grid.col == 0)
}

@Test func test_gridToIndex_roundtrip_columns2() {
    let vm = makeVM(count: 4, columns: 2)
    for i in 0..<4 {
        let (row, col) = vm.indexToGrid(i)
        let back = vm.gridToIndex(row: row, col: col)
        #expect(back == i, "index \(i) → grid (\(row),\(col)) → back \(String(describing: back))")
    }
}

// MARK: - 奇数件最終行右セル nil

@Test func test_gridToIndex_oddCount_lastRowRightCell_returnsNil() {
    // 3件 (columns=2): row=1, col=1 は存在しない
    let vm = makeVM(count: 3, columns: 2)
    let result = vm.gridToIndex(row: 1, col: 1)
    #expect(result == nil)
}

// MARK: - moveLeft / moveRight (columns=1)

@Test func test_moveLeft_columns1_isNoop() {
    let vm = makeVM(count: 4, columns: 1)
    vm.selectedIndex = 2
    vm.moveLeft()
    #expect(vm.selectedIndex == 2)
}

@Test func test_moveRight_columns1_isNoop() {
    let vm = makeVM(count: 4, columns: 1)
    vm.selectedIndex = 2
    vm.moveRight()
    #expect(vm.selectedIndex == 2)
}

// MARK: - moveLeft / moveRight (columns=2)

@Test func test_moveLeft_columns2_movesToPrevious() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 1
    vm.moveLeft()
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveLeft_columns2_atRowStart_isNoop() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 0  // 行頭
    vm.moveLeft()
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveRight_columns2_movesToNext() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 0
    vm.moveRight()
    #expect(vm.selectedIndex == 1)
}

@Test func test_moveRight_columns2_atRowEnd_isNoop() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 1  // 行末
    vm.moveRight()
    #expect(vm.selectedIndex == 1)
}

@Test func test_moveRight_columns2_oddCount_lastRowLeft_staysOnExisting() {
    // 3件: index=2 (row=1, col=0) で右移動 → col=1 は存在しない → no-op
    let vm = makeVM(count: 3, columns: 2)
    vm.selectedIndex = 2
    vm.moveRight()
    #expect(vm.selectedIndex == 2)
}

// MARK: - moveUp / moveDown (columns=2)

@Test func test_moveUp_columns2_movesUpByColumns() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 2
    vm.moveUp()
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveUp_columns2_atTopRow_clamps() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 0
    vm.moveUp()
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveDown_columns2_movesDownByColumns() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 0
    vm.moveDown()
    #expect(vm.selectedIndex == 2)
}

@Test func test_moveDown_columns2_atBottomRow_clamps() {
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 3  // 最終行
    vm.moveDown()
    #expect(vm.selectedIndex == 3)
}

// MARK: - selectByDigit

@Test func test_selectByDigit_success() {
    let vm = makeVM(count: 4, columns: 1)
    // 自動割り当てで "1" が index 0 に対応する
    let result = vm.selectByDigit(1)
    #expect(result == true)
    #expect(vm.selectedIndex == 0)
}

@Test func test_selectByDigit_outOfRange_returnsFalse() {
    let vm = makeVM(count: 2, columns: 1)
    // digit 9 は存在しない
    let result = vm.selectByDigit(9)
    #expect(result == false)
}
