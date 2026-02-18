import SwiftUI
import AppKit
import FocusBMLib

@main
struct FocusBMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var searchPanel: SearchPanel?
    private let viewModel = SearchViewModel()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock アイコンを非表示（メニューバー常駐）
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupSearchPanel()
        setupHotkey()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: "focusbm")
        }

        let menu = NSMenu()

        let searchItem = NSMenuItem(title: "検索パネルを開く", action: #selector(toggleSearchPanel), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        menu.addItem(NSMenuItem.separator())

        // コンテキスト別ブックマーク
        let store = BookmarkStore.loadYAML()
        let grouped = Dictionary(grouping: store.bookmarks) { $0.context }
        for ctx in grouped.keys.sorted() {
            let contextItem = NSMenuItem(title: "[\(ctx)]", action: nil, keyEquivalent: "")
            contextItem.isEnabled = false
            menu.addItem(contextItem)
            for bm in grouped[ctx]! {
                let bmItem = NSMenuItem(title: "  \(bm.id) — \(bm.appName)", action: #selector(restoreBookmarkFromMenu(_:)), keyEquivalent: "")
                bmItem.representedObject = bm.id
                bmItem.target = self
                menu.addItem(bmItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let editItem = NSMenuItem(title: "YAML を編集...", action: #selector(openYAMLEditor), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)

        let reloadItem = NSMenuItem(title: "再読み込み", action: #selector(reloadBookmarks), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupSearchPanel() {
        viewModel.load()
        searchPanel = SearchPanel(viewModel: viewModel)
    }

    private func setupHotkey() {
        let store = BookmarkStore.loadYAML()
        let hotkeyString = store.settings?.hotkey.togglePanel ?? "cmd+ctrl+b"
        let parsed = HotkeyParser.parse(hotkeyString)

        // Convert HotkeyModifiers to NSEvent.ModifierFlags
        var flags: NSEvent.ModifierFlags = []
        if parsed.modifiers.contains(.command) { flags.insert(.command) }
        if parsed.modifiers.contains(.control) { flags.insert(.control) }
        if parsed.modifiers.contains(.option) { flags.insert(.option) }
        if parsed.modifiers.contains(.shift) { flags.insert(.shift) }

        let keyChar = parsed.key

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == flags {
                let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if chars == keyChar {
                    DispatchQueue.main.async {
                        self?.toggleSearchPanel()
                    }
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == flags {
                let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                if chars == keyChar {
                    DispatchQueue.main.async {
                        self?.toggleSearchPanel()
                    }
                    return nil
                }
            }
            return event
        }
    }

    @objc private func toggleSearchPanel() {
        guard let panel = searchPanel else { return }
        if panel.isVisible {
            panel.close()
        } else {
            viewModel.load()
            viewModel.query = ""
            viewModel.selectedIndex = 0
            viewModel.isActive = false
            centerOnTargetDisplay(panel)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Trigger focus on next run loop to ensure view is ready
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.isActive = true
            }
        }
    }

    private func centerOnTargetDisplay(_ panel: NSPanel) {
        let store = BookmarkStore.loadYAML()
        let screens = NSScreen.screens

        if let displayNumber = store.settings?.displayNumber,
           displayNumber >= 1, displayNumber <= screens.count {
            // displayNumber は 1 始まり（ユーザー向け）
            let screen = screens[displayNumber - 1]
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
    }

    @objc private func restoreBookmarkFromMenu(_ sender: NSMenuItem) {
        guard let bookmarkId = sender.representedObject as? String else { return }
        let store = BookmarkStore.loadYAML()
        guard let bookmark = store.bookmarks.first(where: { $0.id == bookmarkId }) else { return }
        do {
            try BookmarkRestorer.restore(bookmark)
        } catch {
            let alert = NSAlert()
            alert.messageText = "復元エラー"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func openYAMLEditor() {
        let path = BookmarkStore.storePath.path
        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "open -t"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "\(editor) \"\(path)\""]
        try? process.run()
    }

    @objc private func reloadBookmarks() {
        viewModel.load()
        setupStatusItem()
    }
}
