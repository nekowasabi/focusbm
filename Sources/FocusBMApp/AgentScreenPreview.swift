import SwiftUI
import FocusBMLib

struct AgentScreenCapture: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
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

/// Full-panel overlay of tmux visible-pane text. Esc / click dismisses it.
struct AgentScreenPreviewOverlay: View {
    let state: AgentScreenPreviewState
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
        }
        .allowsHitTesting(true)
    }

    private var tiledCaptures: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(state.captures) { capture in
                    captureView(capture, showTitle: true)
                        .frame(minHeight: 160, maxHeight: 280, alignment: .topLeading)
                }
            }
        }
    }

    private func captureView(_ capture: AgentScreenCapture, showTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if showTitle {
                Text(capture.title)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
            ScrollView {
                Text(capture.text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(white: 0.9))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
