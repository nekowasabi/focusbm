import AppKit
import SwiftUI
import FocusBMLib

class SearchPanel: NSPanel {
    private let viewModel: SearchViewModel
    private var localKeyMonitor: Any?

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel

        let contentRect = NSRect(x: 0, y: 0, width: 500, height: 400)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        // Visual effect background
        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12

        let hostingView = NSHostingView(rootView: SearchView(viewModel: viewModel, panel: self))
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]

        visualEffect.addSubview(hostingView)
        self.contentView = visualEffect
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        startLocalKeyMonitor()
    }

    override func close() {
        stopLocalKeyMonitor()
        super.close()
    }

    // 数字キー 1-9 の keyCode
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]

    private func startLocalKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Cmd+1〜9: query が空のときのみダイレクト復元（fuzzy 検索中はインデックスが変動するため無効）
            if event.modifierFlags.contains(.command),
               Self.digitKeyCodes[event.keyCode] != nil {
                if self.viewModel.query.isEmpty,
                   let number = Self.digitKeyCodes[event.keyCode] {
                    let index = number - 1
                    if index < self.viewModel.searchItems.count {
                        self.viewModel.selectedIndex = index
                        if self.viewModel.restoreSelected() {
                            self.close()
                        }
                    }
                }
                return nil  // query あり/なし問わずイベントを消費
            }

            switch event.keyCode {
            case 126: // Up arrow
                self.viewModel.moveUp()
                return nil
            case 125: // Down arrow
                self.viewModel.moveDown()
                return nil
            case 53: // Escape
                self.close()
                return nil
            default:
                return event
            }
        }
    }

    private func stopLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    deinit {
        stopLocalKeyMonitor()
    }
}
