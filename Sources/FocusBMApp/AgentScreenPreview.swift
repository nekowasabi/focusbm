import SwiftUI
import FocusBMLib

struct AgentScreenCapture: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
    let index: Int

    init(id: String, title: String, text: String, index: Int = 0) {
        self.id = id
        self.title = title
        self.text = text
        self.index = index
    }

    var numberedTitle: String { index > 0 ? "\(index)  \(title)" : title }
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
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Group {
                    if state.isTiled {
                        tiledCaptures
                    } else if let capture = state.captures.first {
                        captureView(capture, showTitle: false)
                    }
                }
                .padding(12)

                Text("Esc で閉じる")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.bottom, 10)
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
        .allowsHitTesting(true)
    }

    private var captureFont: Font {
        let size = fontSize ?? 14
        if let fontName, !fontName.isEmpty {
            return Font.custom(fontName, size: size)
        }
        return Font.system(size: size, design: .monospaced)
    }

    private var tiledCaptures: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        let count = max(1, state.captures.count)
        let rows = CGFloat((count + 1) / 2)
        let cellHeight = max(160, (cardSize.height - 48) / rows - 8)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(state.captures) { capture in
                captureView(capture, showTitle: true)
                    .frame(minHeight: cellHeight, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func captureView(_ capture: AgentScreenCapture, showTitle: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                if showTitle {
                    Text(capture.title)
                        .font(captureFont)
                        .foregroundColor(Color.white.opacity(0.9))
                        .lineLimit(1)
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 2)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(capture.text)
                            .font(captureFont)
                            .foregroundColor(Color(white: 0.9))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .textSelection(.enabled)
                            .id("capture-bottom")
                    }
                    .onAppear {
                        proxy.scrollTo("capture-bottom", anchor: .bottom)
                    }
                }
            }
            if showTitle, capture.index > 0 {
                Text("\(capture.index)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 1, green: 0.1, blue: 0.1))
                    .shadow(color: .black, radius: 4)
                    .padding(.trailing, 8)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
        }
        .padding(10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 1)
        }
        .background(Color(white: 0.07))
    }
}
