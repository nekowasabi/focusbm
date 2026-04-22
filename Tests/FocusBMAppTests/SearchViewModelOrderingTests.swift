import Testing
import Foundation
@testable import FocusBMApp
@testable import FocusBMLib

// MARK: - Helpers

private func makeBookmark(
    name: String,
    appName: String,
    lowPriority: Bool = false,
    noShortcut: Bool = false,
    shortcut: String? = nil
) -> Bookmark {
    var bm = Bookmark(
        id: name,
        appName: appName,
        bundleIdPattern: nil,
        context: "",
        state: .app(windowTitle: ""),
        createdAt: "2024-01-01T00:00:00Z"
    )
    bm.lowPriority = lowPriority
    bm.noShortcut = noShortcut
    bm.shortcut = shortcut  // RED PHASE: Bookmark.shortcut は未実装 → compile error expected
    return bm
}

private func makeTmuxPane(id: String) -> TmuxPane {
    TmuxPane(
        paneId: id,
        sessionName: "test",
        windowIndex: 0,
        windowName: "win",
        command: "claude",
        title: "Claude Code",
        currentPath: "/tmp"
    )
}

private func makeAIProcess(pid: Int32) -> ProcessProvider.AIProcess {
    ProcessProvider.AIProcess(
        pid: pid,
        command: "claude",
        workingDirectory: "/tmp",
        terminalBundleId: "com.apple.Terminal",
        terminalAppName: "Terminal",
        terminalEmoji: "💻",
        title: "claude"
    )
}

// MARK: - query.isEmpty ordering tests

/// query.isEmpty 時: lowPriority ブックマークは tmuxPane より後ろに来ること
@Test func test_emptyQuery_lowPriorityBookmark_appearsAfterTmuxPane() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [])
    vm.updateItems()

    let indices = vm.searchItems.enumerated().reduce(into: [String: Int]()) { acc, pair in
        let (i, item) = pair
        switch item {
        case .bookmark(let b) where b.lowPriority == true: acc["lpBookmark"] = i
        case .tmuxPane: acc["tmux"] = i
        default: break
        }
    }

    guard let tmuxIdx = indices["tmux"], let lpIdx = indices["lpBookmark"] else {
        Issue.record("tmuxPane or lowPriority bookmark missing from searchItems")
        return
    }
    #expect(tmuxIdx < lpIdx, "tmuxPane should appear before lowPriority bookmark (tmux=\(tmuxIdx), lp=\(lpIdx))")
}

/// query.isEmpty 時: lowPriority ブックマークは aiProcess より後ろに来ること
@Test func test_emptyQuery_lowPriorityBookmark_appearsAfterAIProcess() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "slack", appName: "com.tinyspeck.slackmacgap", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [], aiProcesses: [makeAIProcess(pid: 9999)])
    vm.updateItems()

    let indices = vm.searchItems.enumerated().reduce(into: [String: Int]()) { acc, pair in
        let (i, item) = pair
        switch item {
        case .bookmark(let b) where b.lowPriority == true: acc["lpBookmark"] = i
        case .aiProcess: acc["ai"] = i
        default: break
        }
    }

    guard let aiIdx = indices["ai"], let lpIdx = indices["lpBookmark"] else {
        Issue.record("aiProcess or lowPriority bookmark missing from searchItems")
        return
    }
    #expect(aiIdx < lpIdx, "aiProcess should appear before lowPriority bookmark (ai=\(aiIdx), lp=\(lpIdx))")
}

/// query.isEmpty 時: 通常ブックマーク → AI エージェント → lowPriority ブックマーク の順序
@Test func test_emptyQuery_fullOrder_normalThenAIThenLowPriority() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%2")], aiProcesses: [])
    vm.updateItems()

    // 期待: [normal, tmux, lpBookmark]
    let labels: [String] = vm.searchItems.map { item in
        switch item {
        case .bookmark(let b): return b.lowPriority == true ? "lp" : "normal"
        case .tmuxPane: return "tmux"
        case .aiProcess: return "ai"
        case .floatingWindow: return "window"
        }
    }

    #expect(labels == ["normal", "tmux", "lp"],
            "Expected [normal, tmux, lp] but got \(labels)")
}

/// query.isEmpty 時: lowPriority ブックマークのみ（AI エージェントなし）でも末尾に来ること
@Test func test_emptyQuery_noAIAgents_lowPriorityBookmark_isLast() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.updateItems()

    guard let lastItem = vm.searchItems.last else {
        Issue.record("searchItems is empty")
        return
    }
    if case .bookmark(let b) = lastItem {
        #expect(b.lowPriority == true, "Last item should be lowPriority bookmark")
    } else {
        Issue.record("Last item is not a bookmark: \(lastItem)")
    }
}

// MARK: - query あり ordering tests

/// query あり時: lowPriority アイテムは末尾に来ること
@Test func test_withQuery_lowPriorityItems_appearsAtEnd() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "chrome-pulls", appName: "com.google.Chrome", lowPriority: true),
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.query = "g"  // 両方マッチするクエリ
    vm.updateItems()

    guard let lastItem = vm.searchItems.last else {
        Issue.record("searchItems is empty")
        return
    }
    #expect(lastItem.lowPriority == true,
            "Last item should be lowPriority, but got \(lastItem.debugLabel)")
}

// MARK: - Alphabet Shortcut Tests (TDD Red Phase)
// NOTE: These tests reference Bookmark.shortcut and SearchViewModel.labelToIndex
//       which do not yet exist. Compile errors are EXPECTED until Tasks #2 and #3
//       are implemented.

/// shortcut:"g" を持つアイテムの shortcutAssignments ラベルが "g" になること
@Test func test_shortcutOverride_usesYAMLLabel() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let ghosttyPair = assignments.first(where: { $0.item.id == "ghostty" }) else {
        Issue.record("ghostty not found in shortcutAssignments")
        return
    }
    #expect(ghosttyPair.label == "g",
            "Expected label 'g' but got \(String(describing: ghosttyPair.label))")
}

/// shortcut:"g" を持つアイテムは auto-assign スロット "1" を占有しないこと
@Test func test_shortcutOverride_doesNotConflictWithAutoAssign() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let chromePair = assignments.first(where: { $0.item.id == "chrome" }) else {
        Issue.record("chrome not found in shortcutAssignments")
        return
    }
    // chrome は shortcut 未指定なので auto-assign "1" を得るはず（ghostty の "g" とは別枠）
    #expect(chromePair.label == "1",
            "Expected auto-assign label '1' but got \(String(describing: chromePair.label))")
}

/// noShortcut:true は shortcut フィールドより優先されること（ラベルなし）
@Test func test_noShortcut_withShortcutField_isIgnored() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", noShortcut: true, shortcut: "a"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let pair = assignments.first(where: { $0.item.id == "ghostty" }) else {
        Issue.record("ghostty not found in shortcutAssignments")
        return
    }
    #expect(pair.label == nil,
            "noShortcut:true should override shortcut field, but got label \(String(describing: pair.label))")
}

/// labelToIndex["g"] は mainListAssignments ベースのインデックスを返す。
/// shortcut:"g" を持つアイテムは shortcutBarItems に入るため mainListAssignments には含まれず、
/// labelToIndex["g"] は nil になる。アルファベット shortcut は shortcutBarItems 経由でアクセスする。
@Test func test_labelToIndex_containsOverriddenLabel() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.updateItems()

    // shortcut:"g" は shortcutBarItems に入るため labelToIndex["g"] は nil
    // アルファベットショートカットは shortcutBarItems 経由でアクティベートする
    #expect(vm.labelToIndex["g"] == nil,
            "labelToIndex should not contain alphabet shortcut 'g' (it belongs to shortcutBarItems)")
    // chrome は mainListAssignments の 0-based index 0 になる
    guard let index = vm.labelToIndex["1"] else {
        Issue.record("labelToIndex does not contain key '1'")
        return
    }
    let item = vm.mainListAssignments[index].item
    #expect(item.id == "chrome",
            "Expected chrome at labelToIndex['1'] (mainListAssignments[0]) but got \(item.id)")
}

/// shortcut 未指定のアイテムは "1","2","3",... の自動ラベルを得ること
@Test func test_labelToIndex_autoAssignedLabels() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
        makeBookmark(name: "slack", appName: "com.tinyspeck.slackmacgap"),
    ]
    vm.updateItems()

    // RED PHASE: vm.labelToIndex は SearchViewModel に未実装 → compile error expected
    let map = vm.labelToIndex
    #expect(map["1"] != nil, "Expected label '1' in labelToIndex")
    #expect(map["2"] != nil, "Expected label '2' in labelToIndex")
    #expect(map["3"] != nil, "Expected label '3' in labelToIndex")
    if let idx1 = map["1"] { #expect(vm.searchItems[idx1].id == "ghostty") }
    if let idx2 = map["2"] { #expect(vm.searchItems[idx2].id == "chrome") }
    if let idx3 = map["3"] { #expect(vm.searchItems[idx3].id == "slack") }
}

/// 同じ shortcut:"g" を持つ2アイテムでは最初のアイテムが shortcutBarItems で優先されること
@Test func test_duplicateShortcut_firstWins() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty", shortcut: "g"),
        makeBookmark(name: "gitkraken", appName: "com.axosoft.gitkraken", shortcut: "g"),
    ]
    vm.updateItems()

    // shortcut:"g" は shortcutBarItems 経由でアクティベート。重複時は最初のアイテムが優先。
    guard let pair = vm.shortcutBarItems.first(where: { $0.label == "g" }) else {
        Issue.record("shortcutBarItems does not contain label 'g'")
        return
    }
    #expect(pair.item.id == "ghostty",
            "First item should win on duplicate shortcut, but got \(pair.item.id)")
}

// MARK: - P1: ViewModel データ分離テスト

@Test func shortcutBarItems_returnsOnlyYAMLShortcutItems() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    #expect(vm.shortcutBarItems.count == 2)
    #expect(vm.shortcutBarItems.allSatisfy { $0.label == "g" || $0.label == "v" })
}

@Test func mainListAssignments_excludesShortcutBarItems() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    let mainIds = Set(vm.mainListAssignments.map { $0.item.id })
    let barIds = Set(vm.shortcutBarItems.map { $0.item.id })
    #expect(mainIds.isDisjoint(with: barIds))
}

@Test func shortcutBarItems_plus_mainListAssignments_equals_shortcutAssignments() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari")
    ]
    vm.query = ""
    vm.updateItems()

    #expect(vm.shortcutBarItems.count + vm.mainListAssignments.count == vm.shortcutAssignments.count)
}

@Test func shortcutBarItems_emptyWhenNoShortcuts() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari")
    ]
    vm.query = ""
    vm.updateItems()

    #expect(vm.shortcutBarItems.isEmpty)
    #expect(vm.mainListAssignments.count == vm.shortcutAssignments.count)
}

// MARK: - P3: selectedIndex 参照先統一テスト

@Test func selectedIndex_boundsClampedToMainListAssignments() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    // mainListAssignments は3件（shortcutBarItems除外）
    let mainCount = vm.mainListAssignments.count
    #expect(mainCount == 3)

    // moveDown を mainCount 回実行 → selectedIndex は mainCount-1 で停止
    for _ in 0..<mainCount + 2 {
        vm.moveDown()
    }
    #expect(vm.selectedIndex == mainCount - 1)
}

@Test func moveUp_from_zero_stays_at_zero() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder")
    ]
    vm.query = ""
    vm.updateItems()
    vm.selectedIndex = 0
    vm.moveUp()
    #expect(vm.selectedIndex == 0)
}

/// shortcutAssignments の各エントリの label プロパティが String? 型であること
@Test func test_shortcutAssignments_labelIsString() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    guard let pair = assignments.first else {
        Issue.record("shortcutAssignments is empty")
        return
    }
    // RED PHASE: pair.label は存在しない（現在は pair.digit: Int?）→ compile error expected
    let _: String? = pair.label
    #expect(pair.label == "1",
            "First auto-assigned item should get label '1' but got \(String(describing: pair.label))")
}

// MARK: - P10: 統合テスト

/// シナリオ A: 基本分離
/// YAML shortcut "g","v" + 通常3件 → shortcutBarItems==2, mainListAssignments==3
/// mainListAssignments に "g","v" が含まれない
@Test func integration_scenarioA_basicSeparation() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    #expect(vm.shortcutBarItems.count == 2, "shortcutBarItems は shortcut 付き2件")
    #expect(vm.mainListAssignments.count == 3, "mainListAssignments は通常3件")

    let mainIds = Set(vm.mainListAssignments.map { $0.item.id })
    let barIds = Set(vm.shortcutBarItems.map { $0.item.id })
    #expect(mainIds.isDisjoint(with: barIds), "mainListAssignments に shortcutBarItems が含まれない")
    #expect(barIds.contains("Chrome"), "shortcutBarItems に Chrome が含まれる")
    #expect(barIds.contains("VSCode"), "shortcutBarItems に VSCode が含まれる")
}

/// シナリオ B: キーボードナビゲーション
/// mainListAssignments 3件、moveDown 3回 → selectedIndex == 2
/// moveUp 1回 → selectedIndex == 1
@Test func integration_scenarioB_keyboardNavigation() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    let mainCount = vm.mainListAssignments.count
    #expect(mainCount == 3, "mainListAssignments は shortcut 除外後3件")

    // moveDown を mainCount 回実行 → selectedIndex は mainCount-1 で停止
    for _ in 0..<mainCount {
        vm.moveDown()
    }
    #expect(vm.selectedIndex == mainCount - 1, "moveDown 後 selectedIndex == \(mainCount - 1)")

    vm.moveUp()
    #expect(vm.selectedIndex == mainCount - 2, "moveUp 後 selectedIndex == \(mainCount - 2)")
}

/// シナリオ C: 検索モード遷移
/// query 空→非空: shortcutBarItems はデータとして存在するが UI 非表示条件
/// 検索結果に shortcut 付きアイテムが含まれる
@Test func integration_scenarioC_searchModeTransition() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari")
    ]

    // query 空: shortcutBarItems 存在
    vm.query = ""
    vm.updateItems()
    #expect(!vm.shortcutBarItems.isEmpty, "query 空の時 shortcutBarItems はデータとして存在")
    let shouldShowEmpty = vm.query.isEmpty && !vm.shortcutBarItems.isEmpty
    #expect(shouldShowEmpty, "query 空の時バー表示条件が成立")

    // query 非空: バー非表示条件
    vm.query = "chrome"
    vm.updateItems()
    let shouldShowNonEmpty = vm.query.isEmpty && !vm.shortcutBarItems.isEmpty
    #expect(!shouldShowNonEmpty, "query 非空の時バー非表示条件")

    // 検索結果に shortcut 付きアイテムが含まれる
    let chromeInSearch = vm.searchItems.contains(where: { $0.id == "Chrome" })
    #expect(chromeInSearch, "検索結果に Chrome が含まれる")
}

/// シナリオ D: アルファベットキーアクティベーション
/// shortcutBarItems に "g" → Chrome
/// selectedIndex が変更されない
@Test func integration_scenarioD_alphabetKeyActivation() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari")
    ]
    vm.query = ""
    vm.updateItems()
    let initialIndex = vm.selectedIndex

    // shortcutBarItems に "g" が存在
    let pair = vm.shortcutBarItems.first(where: { $0.label == "g" })
    #expect(pair != nil, "shortcutBarItems に label='g' のアイテムが存在")
    #expect(pair?.item.id == "Chrome", "label='g' は Chrome に対応")

    // activationTarget 呼び出し（AX 操作は失敗するがメソッドは呼べる）
    if let pair = pair {
        let _ = vm.activationTarget(for: pair.item)
    }

    // selectedIndex が変更されない
    #expect(vm.selectedIndex == initialIndex, "shortcutBarItems 経由では selectedIndex を変更しない")
}

/// シナリオ E: エッジケース
/// ショートカット0件 → shortcutBarItems 空
/// 全アイテムがショートカット → mainListAssignments は数字ラベルのみ
@Test func integration_scenarioE_edgeCases() {
    // ケース1: ショートカット0件
    let vm1 = SearchViewModel()
    vm1.bookmarks = [
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari")
    ]
    vm1.query = ""
    vm1.updateItems()
    #expect(vm1.shortcutBarItems.isEmpty, "ショートカット0件の時 shortcutBarItems は空")
    #expect(vm1.mainListAssignments.count == vm1.shortcutAssignments.count,
            "ショートカット0件の時 mainListAssignments == shortcutAssignments")

    // ケース2: 全アイテムがアルファベットショートカット → mainListAssignments は数字ラベルのみ
    let vm2 = SearchViewModel()
    vm2.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v")
    ]
    vm2.query = ""
    vm2.updateItems()
    #expect(vm2.shortcutBarItems.count == 2, "全アイテムがショートカットの時 shortcutBarItems == 2")
    // mainListAssignments はショートカットバーに入らないアイテム（数字ラベルのみ）
    // この場合は全アイテムが shortcutBarItems に入るため mainListAssignments は空
    let mainLabels = vm2.mainListAssignments.compactMap { $0.label }
    for label in mainLabels {
        let isNumeric = Int(label) != nil
        #expect(isNumeric, "mainListAssignments のラベルは数字のみ: \(label)")
    }
}

// MARK: - P11: digitToIndex バグ修正テスト

@Test func digitToIndex_basedOnMainListAssignments() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "VSCode", appName: "Visual Studio Code", shortcut: "v"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes"),
        makeBookmark(name: "Mail", appName: "Mail"),
        makeBookmark(name: "Maps", appName: "Maps")
    ]
    vm.query = ""
    vm.updateItems()

    // mainListAssignments: 5件（Finder=1, Safari=2, Notes=3, Mail=4, Maps=5）
    // digitToIndex[4] should == 3 (mainListAssignments の 0-based index)
    // NOT 5 (shortcutAssignments の index)
    let index4 = vm.digitToIndex[4]
    #expect(index4 != nil)
    #expect(index4! < vm.mainListAssignments.count, "digitToIndex[4] must be within mainListAssignments bounds")
    #expect(index4 == 3, "digitToIndex[4] should be 3 (0-based in mainListAssignments)")
}

// MARK: - showAIAgentShortcut toggle tests

/// showAIAgentShortcut 未指定: AI 行にもショートカット番号が割り当てられる（従来動作）
@Test func test_showAIAgentShortcut_nil_defaultsToAssigningLabels() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [makeAIProcess(pid: 1001)])
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    let tmuxPair = assignments.first(where: {
        if case .tmuxPane = $0.item { return true }
        return false
    })
    let aiPair = assignments.first(where: {
        if case .aiProcess = $0.item { return true }
        return false
    })
    #expect(tmuxPair?.label == "2", "未指定時は tmuxPane にも番号が振られる")
    #expect(aiPair?.label == "3", "未指定時は aiProcess にも番号が振られる")
}

/// showAIAgentShortcut == true: AI 行にもショートカット番号が割り当てられる（明示 true）
@Test func test_showAIAgentShortcut_true_assignsLabels() {
    let vm = SearchViewModel()
    vm.appSettings = AppSettings(showAIAgentShortcut: true)
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [makeAIProcess(pid: 1001)])
    vm.updateItems()

    let assignments = vm.shortcutAssignments
    let tmuxPair = assignments.first(where: {
        if case .tmuxPane = $0.item { return true }
        return false
    })
    let aiPair = assignments.first(where: {
        if case .aiProcess = $0.item { return true }
        return false
    })
    #expect(tmuxPair?.label == "2")
    #expect(aiPair?.label == "3")
}

/// showAIAgentShortcut == false: AI 行はラベル nil、かつブックマーク側の番号が詰まる
@Test func test_showAIAgentShortcut_false_aiRowsGetNilLabel_bookmarksStayContiguous() {
    let vm = SearchViewModel()
    vm.appSettings = AppSettings(showAIAgentShortcut: false)
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
        makeBookmark(name: "chrome", appName: "com.google.Chrome"),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [makeAIProcess(pid: 1001)])
    vm.updateItems()

    // 想定順序: [ghostty(bm), chrome(bm), tmuxPane, aiProcess]
    // ラベル:    ["1",        "2",        nil,      nil]
    let assignments = vm.shortcutAssignments
    let labels = assignments.map { $0.label ?? "nil" }
    #expect(labels == ["1", "2", "nil", "nil"],
            "AI 行は nil、ブックマーク番号は 1,2 と連続すべきだが got \(labels)")
}

/// showAIAgentShortcut == false: AI 行が先頭に来てもブックマーク番号は 1 から始まる
@Test func test_showAIAgentShortcut_false_aiFirst_bookmarkStartsAt1() {
    // bookmarks が空でも lowPriority=false なので、AI 行が先に並ぶケースを作る
    let vm = SearchViewModel()
    vm.appSettings = AppSettings(showAIAgentShortcut: false)
    vm.bookmarks = [
        makeBookmark(name: "chrome", appName: "com.google.Chrome", lowPriority: true),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [makeAIProcess(pid: 1001)])
    vm.updateItems()

    // 期待順序: [tmuxPane, aiProcess, lpBookmark]
    // ラベル:   [nil,     nil,       "1"]
    let assignments = vm.shortcutAssignments
    let labels = assignments.map { $0.label ?? "nil" }
    #expect(labels == ["nil", "nil", "1"],
            "AI 行が先でも後続ブックマークは '1' から始まるべきだが got \(labels)")
}

/// showAIAgentShortcut == false: labelToIndex から AI 行が引けない
@Test func test_showAIAgentShortcut_false_labelToIndex_excludesAIRows() {
    let vm = SearchViewModel()
    vm.appSettings = AppSettings(showAIAgentShortcut: false)
    vm.bookmarks = [
        makeBookmark(name: "ghostty", appName: "com.mitchellh.ghostty"),
    ]
    vm.applyBackgroundCache(tmuxPanes: [makeTmuxPane(id: "%1")], aiProcesses: [makeAIProcess(pid: 1001)])
    vm.updateItems()

    let map = vm.labelToIndex
    // ブックマーク "1" は引けるが、"2"/"3" は存在しない（AI 行分のラベルなし）
    #expect(map["1"] != nil, "ブックマーク側のラベル '1' は存在すべき")
    #expect(map["2"] == nil, "AI 行はラベル nil のため labelToIndex に '2' は存在しない")
    #expect(map["3"] == nil, "AI 行はラベル nil のため labelToIndex に '3' は存在しない")
}

@Test func digitKey_selectedIndex_withinMainListBounds() {
    let vm = SearchViewModel()
    vm.bookmarks = [
        makeBookmark(name: "Chrome", appName: "Google Chrome", shortcut: "g"),
        makeBookmark(name: "Finder", appName: "Finder"),
        makeBookmark(name: "Safari", appName: "Safari"),
        makeBookmark(name: "Notes", appName: "Notes")
    ]
    vm.query = ""
    vm.updateItems()

    // shortcutBarItems: 1件(g), mainListAssignments: 3件(1,2,3)
    for (_, index) in vm.digitToIndex {
        #expect(index >= 0 && index < vm.mainListAssignments.count,
                "All digitToIndex values must be within mainListAssignments bounds")
    }
}
