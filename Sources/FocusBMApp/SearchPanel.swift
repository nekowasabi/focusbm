import AppKit
import CInputSource
import SwiftUI
import FocusBMLib

class SearchPanel: NSPanel {
    private let viewModel: SearchViewModel
    private var localKeyMonitor: Any?
    // Why: close()一点で全close pathのフォーカス復元をカバーするため、
    //      パネル表示時の前アプリ参照を保持する。各close pathに個別にactivate()を
    //      追加する方式(Strategy D)ではなく一元管理を選択した理由:
    //      将来のclose path追加でも自動的にフォーカス復元が保証されるため
    private var previousApp: NSRunningApplication?

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
                self.activateItem(target: target)
            }
        }
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        // Why: toggleSearchPanel()内ではなくここでキャプチャする理由:
        //      将来のパネル表示経路追加でも自動的にキャプチャされるため。
        //      NSApp.activate()の前に取得必須 — activate()後はfocusbm自身が返される
        previousApp = NSWorkspace.shared.frontmostApplication
        switchToASCIIInput()
        super.makeKeyAndOrderFront(sender)
        startLocalKeyMonitor()
    }

    override func close() {
        let appToRestore = previousApp
        previousApp = nil  // 先にnilクリア（再入防止）
        stopLocalKeyMonitor()
        super.close()
        // Why: 同期activate()はsuper.close()直後のAppKitイベントループと干渉しフリーズする。
        //      非同期化により安全にフォーカス移動。OK paths (P4-P8) の target.activate() も
        //      DispatchQueue.main.asyncのため、キュー順序で後勝ちセマンティクスは維持される
        DispatchQueue.main.async {
            appToRestore?.activate()
        }
    }

    // 数字キー 1-9 の keyCode
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]

    // アルファベットキー a-z の keyCode → 文字 逆引きマップ
    // ANSI layout only - AppDelegate.keyCodeForCharacter() から逆引き生成（DRY: ハードコード禁止）
    // Note: JIS キーボードでは keyCode が異なるため将来的な対応が必要
    private static let alphabetKeyCodes: [UInt16: String] = {
        let letters = "abcdefghijklmnopqrstuvwxyz".map { String($0) }
        var result: [UInt16: String] = [:]
        for letter in letters {
            let code = UInt16(AppDelegate.keyCodeForCharacter(letter))
            result[code] = letter
        }
        return result
    }()

    // Why: SearchPanel に配置。理由: panel.close() が必要なためPanel層のメソッドが適切
    // Why: target を受け取る設計。理由: restoreSelected() は既に ActivationTarget? を返すため変換不要
    private func activateItem(target: ActivationTarget) {
        self.close()
        DispatchQueue.main.async {
            target.activate()
        }
    }

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
                    if self.viewModel.selectByDigit(number) {
                        if let target = self.viewModel.restoreSelected() {
                            self.activateItem(target: target)
                        }
                    }
                    return nil
                }
            }

            // アルファベットショートカット: query が空かつ shortcutBarItems に登録済みキーで発動
            // Why: selectedIndex をバイパス。理由: shortcutBarItems はメインリスト外のためインデックスが対応しない
            // ANSI layout only - see alphabetKeyCodes
            if let label = Self.alphabetKeyCodes[event.keyCode] {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let isBareOrCmd = flags.isEmpty || flags == .command
                if isBareOrCmd, self.viewModel.query.isEmpty,
                   let pair = self.viewModel.shortcutBarItems.first(where: { $0.label == label }) {
                    if let target = self.viewModel.activationTarget(for: pair.item) {
                        self.activateItem(target: target)
                    }
                    return nil
                }
            }

            // Why: 矢印キーのロジックを SearchPanel に持たず VM に委譲することで、
            //      ナビゲーション挙動は SearchViewModelGridTests でテスト可能となる。
            //      SearchPanel はキー監視とイベント消費のみを担う薄いレイヤーに留める。
            switch event.keyCode {
            case 126: // Up arrow
                self.viewModel.moveUp()
                return nil
            case 125: // Down arrow
                self.viewModel.moveDown()
                return nil
            case 123: // Left arrow
                self.viewModel.moveLeft()
                return nil
            case 124: // Right arrow
                self.viewModel.moveRight()
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
