import AppKit
import CInputSource
import SwiftUI
import FocusBMLib

class SearchPanel: NSPanel {
    private let viewModel: SearchViewModel
    private var localKeyMonitor: Any?

    init(viewModel: SearchViewModel, width: CGFloat = 500, height: CGFloat = 400) {
        self.viewModel = viewModel

        let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
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

        // 候補が1件になったとき自動実行
        viewModel.onAutoExecute = { [weak self] in
            guard let self else { return }
            if let target = self.viewModel.restoreSelected() {
                self.close()
                DispatchQueue.main.async {
                    target.activate()
                }
            }
        }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        switchToASCIIInput()
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

            // 数字キー 1〜9: query が空のときダイレクト復元
            // directNumberKeys=true(デフォルト): 修飾キー不要、Cmd併用も可
            // directNumberKeys=false: Cmd+数字のみ
            if let number = Self.digitKeyCodes[event.keyCode] {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let direct = self.viewModel.appSettings?.directNumberKeys ?? true
                let isBareOrCmd = direct ? (flags.isEmpty || flags == .command) : flags == .command
                if isBareOrCmd, self.viewModel.query.isEmpty {
                    let index = number - 1
                    if index < self.viewModel.searchItems.count {
                        self.viewModel.selectedIndex = index
                        if let target = self.viewModel.restoreSelected() {
                            self.close()
                            DispatchQueue.main.async {
                                target.activate()
                            }
                        }
                    }
                    return nil
                }
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

    private func switchToASCIIInput() {
        CInputSource_switchToASCII()
    }

    deinit {
        stopLocalKeyMonitor()
    }
}
