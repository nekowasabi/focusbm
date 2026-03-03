import Testing
import AppKit
@testable import FocusBMLib

// MARK: - AppIconProvider Tests

@Test func test_icon_for_known_app_is_not_nil() {
    // Finder.app は macOS に必ず存在するため、アイコン取得できることを確認
    let provider = AppIconProvider()
    let icon = provider.icon(forAppName: "Finder")
    #expect(icon.size.width > 0)
}

@Test func test_icon_size_is_20x20() {
    // SearchPanel のリスト表示用に 20x20 を期待
    let provider = AppIconProvider()
    let icon = provider.icon(forAppName: "Finder")
    #expect(icon.size.width == 20)
    #expect(icon.size.height == 20)
}

@Test func test_caching_returns_same_instance() {
    // 2回取得しても同一インスタンスが返ること（キャッシュ確認）
    let provider = AppIconProvider()
    let icon1 = provider.icon(forAppName: "Finder")
    let icon2 = provider.icon(forAppName: "Finder")
    // NSImage は参照型なので === で同一性を確認
    #expect(icon1 === icon2, "同じ appName には同一インスタンスが返るべき")
}

@Test func test_unknown_app_returns_default_icon() {
    // 存在しないアプリ名でもデフォルトアイコン（NSWorkspace の汎用アイコン）を返すこと
    let provider = AppIconProvider()
    let icon = provider.icon(forAppName: "NonExistentApp12345")
    #expect(icon.size.width > 0, "不明なアプリでも有効なアイコンを返すべき")
}
