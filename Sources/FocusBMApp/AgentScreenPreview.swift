import SwiftUI
import FocusBMLib

struct AgentScreenCapture: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
    let index: Int
    let status: TmuxAgentStatus?

    init(id: String, title: String, text: String, index: Int = 0, status: TmuxAgentStatus? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.index = index
        self.status = status
    }
}

enum AgentScreenPreviewState: Equatable {
    case single(AgentScreenCapture)
    case tiled([AgentScreenCapture])

    var captures: [AgentScreenCapture] {
        switch self {
        case .single(let capture): return [capture]
        case .tiled(let captures): return captures
        }
    }

    var isTiled: Bool {
        if case .tiled = self { return true }
        return false
    }
}

/// Monitor-sized overlay of tmux visible-pane text. Esc / click dismisses it.
/// A single Ctrl+P capture is centered in a card of YAML previewWidth × previewHeight
/// (omitted size uses the monitor maximum).
struct AgentScreenPreviewOverlay: View {
    let state: AgentScreenPreviewState
    let cardSize: CGSize
    let fontSize: Double?
    let fontName: String?
    @Binding var promptText: String
    let promptTargetIndex: Int?
    let promptTargetKeyLabel: String
    let promptError: String?
    let isPromptFocused: FocusState<Bool>.Binding
    let onSubmitPrompt: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            PreviewPalette.backdrop
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Group {
                    if state.isTiled {
                        tiledCaptures
                    } else if let capture = state.captures.first {
                        captureView(capture, cellHeight: nil)
                    }
                }
                .padding(12)

                promptBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                Text("Esc で閉じる")
                    .font(.system(size: 12))
                    .foregroundColor(PreviewPalette.hint)
                    .padding(.bottom, 10)
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
        .allowsHitTesting(true)
    }

    private var promptBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if state.isTiled, let promptTargetIndex {
                    Text("→ \(promptTargetIndex)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PreviewPalette.accent)
                }
                TextField(
                    state.isTiled && promptTargetIndex == nil
                        ? "\(promptTargetKeyLabel)+数字で送信先を選んで入力（Enter で送信）"
                        : "エージェントへの指示（Enter で送信）",
                    text: $promptText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(PreviewPalette.text)
                .focused(isPromptFocused)
                .onSubmit(onSubmitPrompt)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 10).fill(PreviewPalette.pane))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PreviewPalette.accent, lineWidth: 1))

            if let promptError {
                Text(promptError)
                    .font(.system(size: 12))
                    .foregroundColor(PreviewPalette.error)
            }
        }
    }

    private var captureFont: Font {
        let size = fontSize ?? 14
        if let fontName, !fontName.isEmpty {
            return Font.custom(fontName, size: size)
        }
        return Font.system(size: size, design: .monospaced)
    }

    private var tiledCaptures: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        let count = max(1, state.captures.count)
        let rows = CGFloat((count + 1) / 2)
        // Why: 112 = padding (24) + prompt bar (60) + hint (28), so the bar is not pushed below the card.
        let cellHeight = max(160, (cardSize.height - 112) / rows - 12)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(state.captures) { capture in
                captureView(capture, cellHeight: cellHeight)
                    // Why: fixed height instead of minHeight/maxHeight: .infinity — LazyVGrid does not
                    // propagate a height limit, so rows grew to fit the capture text and pushed tiles off-screen.
                    .frame(height: cellHeight, alignment: .topLeading)
            }
        }
    }

    /// `cellHeight` is non-nil only for tiled captures, which show the index rail.
    private func captureView(_ capture: AgentScreenCapture, cellHeight: CGFloat?) -> some View {
        let isTarget = state.isTiled && capture.index == promptTargetIndex
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(capture.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PreviewPalette.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let status = capture.status {
                    statusPill(status)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 0) {
                if let cellHeight, capture.index > 0 {
                    // Why: 50 ≈ header (40) + bottom inset (10), leaving the body inset height.
                    indexNumber(capture, bodyHeight: cellHeight - 50, isTarget: isTarget)
                }
                captureText(capture)
            }
            .background(PreviewPalette.inset)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(PreviewPalette.pane)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(capture.status?.color ?? PreviewPalette.secondary)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTarget ? PreviewPalette.accent : PreviewPalette.border, lineWidth: 1)
        )
        .overlay {
            if isTarget {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(PreviewPalette.accent.opacity(0.25), lineWidth: 3)
                    .padding(-2)
            }
        }
    }

    private func statusPill(_ status: TmuxAgentStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
            Text(status.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(status.color)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Capsule().fill(status.color.opacity(0.14)))
    }

    private func captureText(_ capture: AgentScreenCapture) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(ANSIText.attributed(capture.text))
                    .font(captureFont)
                    .foregroundColor(PreviewPalette.bodyText)
                    .lineSpacing((fontSize ?? 14) * 0.5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .id("capture-bottom")
            }
            .onAppear {
                proxy.scrollTo("capture-bottom", anchor: .bottom)
            }
            // Why: ライブ更新で text が差し替わっても末尾を追従させるため onAppear に加えて再実行する
            .onChange(of: capture.text) { _ in
                proxy.scrollTo("capture-bottom", anchor: .bottom)
            }
        }
    }

    /// Why: Instead of aligning to the end of the longest output (drifts to the bottom-left on large screens), center the index vertically in the body.
    /// Colored by agent status.
    private func indexNumber(_ capture: AgentScreenCapture, bodyHeight: CGFloat, isTarget: Bool) -> some View {
        Text("\(capture.index)")
            .font(.system(size: PreviewLayout.indexNumberFontSize(bodyHeight: bodyHeight), weight: .heavy))
            .foregroundColor(capture.status?.color ?? PreviewPalette.secondary)
            .opacity(isTarget ? 1 : 0.55)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .frame(width: max(1, min(80, bodyHeight * 0.25)))
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

private enum PreviewPalette {
    static let backdrop = rgb(0x0D, 0x11, 0x17)
    static let pane = rgb(0x16, 0x1B, 0x22)
    static let border = rgb(0x30, 0x36, 0x3D)
    static let inset = rgb(0x0D, 0x11, 0x17)
    static let text = rgb(0xE6, 0xED, 0xF3)
    static let bodyText = rgb(0xC9, 0xD1, 0xD9)
    static let secondary = rgb(0x8B, 0x94, 0x9E)
    static let hint = rgb(0x6E, 0x76, 0x81)
    static let accent = rgb(0x58, 0xA6, 0xFF)
    static let error = rgb(0xFF, 0xA1, 0x98)

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
