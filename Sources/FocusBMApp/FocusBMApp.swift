import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import FocusBMLib

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var searchPanel: SearchPanel?
    private let viewModel = SearchViewModel()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    // ホットキー設定（setupHotkey で更新）
    private var targetKeyCode: CGKeyCode = 11  // 'b'
    private var targetFlags: CGEventFlags = [.maskCommand, .maskControl]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock アイコンを非表示（メニューバー常駐）
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupSearchPanel()
        setupHotkey()
    }

    // MARK: - Hotkey (CGEventTap)

    private func setupHotkey() {
        let store = BookmarkStore.loadYAML()
        let hotkeyString = store.settings?.hotkey.togglePanel ?? "cmd+ctrl+b"
        let parsed = HotkeyParser.parse(hotkeyString)

        // HotkeyModifiers → CGEventFlags
        var flags: CGEventFlags = []
        if parsed.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if parsed.modifiers.contains(.control) { flags.insert(.maskControl) }
        if parsed.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if parsed.modifiers.contains(.shift) { flags.insert(.maskShift) }
        targetFlags = flags

        // キー文字 → CGKeyCode
        targetKeyCode = Self.keyCodeForCharacter(parsed.key)

        if AXIsProcessTrusted() {
            startEventTap()
        } else {
            requestAccessibilityPermission()
        }
    }

    private func requestAccessibilityPermission() {
        // システムダイアログを表示
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // 権限付与を Timer でポーリング
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.permissionTimer = nil
                // 権限付与後は必ず再起動する。
                // CGEventTap のオブジェクト作成（tapCreate）は成功しても、
                // 権限付与直後はシステムがイベント配送を完全に有効化するまで
                // 遅延が生じる。再起動が最も確実。
                self?.relaunchSelf()
            }
        }
    }

    private func relaunchSelf() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        // /usr/bin/open で確実に新インスタンスを起動してから終了
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        // open コマンドが新プロセスを起動した後に終了
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func startEventTap() {
        // 既存の tap があれば解放
        stopEventTap()

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
                return delegate.handleCGEvent(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // タイムアウトで無効化された場合は再有効化
        if type == .tapDisabledByTimeout {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])

        if keyCode == targetKeyCode && flags == targetFlags {
            DispatchQueue.main.async { [weak self] in
                self?.toggleSearchPanel()
            }
            return nil  // イベントを消費（他アプリに渡さない）
        }

        return Unmanaged.passUnretained(event)
    }

    // キー文字 → CGKeyCode 変換テーブル
    private static func keyCodeForCharacter(_ char: String) -> CGKeyCode {
        let map: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, "space": 49,
            "return": 36, "tab": 48, "escape": 53,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        ]
        return map[char.lowercased()] ?? 11
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "focusbm"
        statusItem.isVisible = true
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

    // MARK: - Search Panel

    private func setupSearchPanel() {
        viewModel.load()
        searchPanel = SearchPanel(viewModel: viewModel)
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

    // MARK: - Menu Actions

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
