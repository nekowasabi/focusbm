import AppKit
import SwiftUI
import FocusBMLib

class SearchPanel: NSPanel {
    private let viewModel: SearchViewModel

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
}
