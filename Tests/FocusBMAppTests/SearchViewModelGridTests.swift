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

// MARK: - process-11: 追加ケース
// Why: 既存20ケースは columns=1/2 のみ対象。
// columns=3 の挙動と切替シナリオを追加し、未カバーの境界値を厳密化する。

// MARK: - columns 派生プロパティ（追加）

@Test func test_columns_nil_bookmarkListColumns_treatedAsOne() {
    // Arrange
    let vm = SearchViewModel()
    var settings = AppSettings()
    settings.bookmarkListColumns = nil  // 明示的に nil
    vm.appSettings = settings

    // Act / Assert
    #expect(vm.columns == 1)
}

@Test func test_columns_three_whenSet() {
    // Arrange
    let vm = SearchViewModel()
    var settings = AppSettings()
    settings.bookmarkListColumns = 3
    vm.appSettings = settings

    // Act / Assert
    #expect(vm.columns == 3)
}

// MARK: - indexToGrid (columns=3)

@Test func test_indexToGrid_columns3_index3_isRow1Col0() {
    // Arrange: 6件 columns=3 → index 3 = row1,col0
    let vm = makeVM(count: 6, columns: 3)

    // Act
    let grid = vm.indexToGrid(3)

    // Assert
    #expect(grid.row == 1 && grid.col == 0)
}

@Test func test_indexToGrid_columns3_index5_isRow1Col2() {
    // Arrange: 6件 columns=3 → index 5 = row1,col2
    let vm = makeVM(count: 6, columns: 3)

    // Act
    let grid = vm.indexToGrid(5)

    // Assert
    #expect(grid.row == 1 && grid.col == 2)
}

// MARK: - gridToIndex (境界値)

@Test func test_gridToIndex_columns2_negativeRow_returnsNil() {
    // Arrange
    let vm = makeVM(count: 4, columns: 2)

    // Act: 負の row → 負のインデックス → nil
    let result = vm.gridToIndex(row: -1, col: 0)

    // Assert
    #expect(result == nil)
}

@Test func test_gridToIndex_columns3_allRoundtrip() {
    // Arrange: 6件 columns=3
    let vm = makeVM(count: 6, columns: 3)

    // Act / Assert: 全インデックスの往復変換が一致する
    for i in 0..<6 {
        let (row, col) = vm.indexToGrid(i)
        let back = vm.gridToIndex(row: row, col: col)
        #expect(back == i, "index \(i) roundtrip failed")
    }
}

// MARK: - moveLeft / moveRight (columns=3)

@Test func test_moveLeft_columns3_atRowStart_isNoop() {
    // Arrange: index=3 (row=1, col=0) は行頭
    let vm = makeVM(count: 6, columns: 3)
    vm.selectedIndex = 3

    // Act
    vm.moveLeft()

    // Assert
    #expect(vm.selectedIndex == 3)
}

@Test func test_moveRight_columns3_atRowEnd_isNoop() {
    // Arrange: index=2 (row=0, col=2) は行末
    let vm = makeVM(count: 6, columns: 3)
    vm.selectedIndex = 2

    // Act
    vm.moveRight()

    // Assert
    #expect(vm.selectedIndex == 2)
}

@Test func test_moveRight_columns3_movesToNext() {
    // Arrange: index=1 (row=0, col=1) → 右移動 → index=2
    let vm = makeVM(count: 6, columns: 3)
    vm.selectedIndex = 1

    // Act
    vm.moveRight()

    // Assert
    #expect(vm.selectedIndex == 2)
}

// MARK: - moveUp / moveDown (columns=3)

@Test func test_moveUp_columns3_decrementsBy3() {
    // Arrange: index=3 (row=1) → 上移動 → index=0
    let vm = makeVM(count: 6, columns: 3)
    vm.selectedIndex = 3

    // Act
    vm.moveUp()

    // Assert
    #expect(vm.selectedIndex == 0)
}

@Test func test_moveDown_columns3_incrementsBy3() {
    // Arrange: index=1 (row=0) → 下移動 → index=4
    let vm = makeVM(count: 6, columns: 3)
    vm.selectedIndex = 1

    // Act
    vm.moveDown()

    // Assert
    #expect(vm.selectedIndex == 4)
}

@Test func test_moveDown_columns2_oddCount_atLastExisting_clamps() {
    // Arrange: 3件 columns=2、index=2 (row=1,col=0) から下移動 → 存在しない → クランプ
    let vm = makeVM(count: 3, columns: 2)
    vm.selectedIndex = 2

    // Act
    vm.moveDown()

    // Assert: index=4 は存在しないため index=2 のまま（clamp）
    #expect(vm.selectedIndex == 2)
}

@Test func test_moveUp_columns2_rightCol_movesUpByColumns() {
    // Arrange: index=3 (row=1, col=1) から上移動 → index=1
    let vm = makeVM(count: 4, columns: 2)
    vm.selectedIndex = 3

    // Act
    vm.moveUp()

    // Assert
    #expect(vm.selectedIndex == 1)
}

// MARK: - 1D→2D 切替でのアイテム維持

@Test func test_switchColumns_preservesSelectedItem() {
    // Arrange: columns=1 で index=1 (bm1) を選択
    let vm = makeVM(count: 4, columns: 1)
    vm.selectedIndex = 1
    // Why: selectedIndex を固定して appSettings 変更後に同じインデックスが指すアイテムを確認する。
    // columns 変更は selectedIndex を変えず、表示レイアウトのみ変更するため
    // 同一 selectedIndex が指す mainListAssignments[1] は変わらないことを期待する。
    let itemBeforeId = vm.mainListAssignments[vm.selectedIndex].item.id

    // Act: 1列→2列に切替
    var newSettings = AppSettings()
    newSettings.bookmarkListColumns = 2
    vm.appSettings = newSettings
    vm.updateItems()

    // Assert: 同じインデックスに同じブックマークIDが存在する
    let itemAfterId = vm.mainListAssignments[vm.selectedIndex].item.id
    #expect(itemBeforeId == itemAfterId)
}

// MARK: - selectByDigit（追加境界値）

@Test func test_selectByDigit_secondItem_setsIndexToOne() {
    // Arrange: 4件 columns=1 → "2" は index=1
    let vm = makeVM(count: 4, columns: 1)

    // Act
    let result = vm.selectByDigit(2)

    // Assert
    #expect(result == true)
    #expect(vm.selectedIndex == 1)
}

@Test func test_selectByDigit_zeroIsInvalid() {
    // Arrange: digit 0 は割り当てなし（割り当ては "1"〜"9"）
    let vm = makeVM(count: 4, columns: 1)

    // Act
    let result = vm.selectByDigit(0)

    // Assert
    #expect(result == false)
}
