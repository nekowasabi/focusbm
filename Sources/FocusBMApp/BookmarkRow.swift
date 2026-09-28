import SwiftUI
import FocusBMLib

// Why: Instead of HStack flexible frames, adopted widths precomputed from the panel width. Reason: HStack cannot split space 3:2:2, and the header and every row must share identical column edges.
struct TableColumns {
    static let horizontalPadding: CGFloat = 10
    let key: CGFloat = 52
    let status: CGFloat = 120
    let name: CGFloat
    let detail: CGFloat
    let pr: CGFloat

    init(totalWidth: CGFloat) {
        let remaining = max(0, totalWidth - 52 - 120 - Self.horizontalPadding * 2)
        name = remaining * 3 / 7
        detail = remaining * 2 / 7
        pr = remaining * 2 / 7
    }
}

struct BookmarkRow: View {
    let searchItem: SearchItem
    let isSelected: Bool
    let shortcutLabel: String?
    let columns: TableColumns
    let directNumberKeys: Bool
    let fontSize: Double?
    let fontName: String?
    let prLabel: String?

    init(
        searchItem: SearchItem,
        isSelected: Bool,
        shortcutLabel: String?,
        columns: TableColumns,
        directNumberKeys: Bool,
        fontSize: Double?,
        fontName: String?,
        prLabel: String? = nil
    ) {
        self.searchItem = searchItem
        self.isSelected = isSelected
        self.shortcutLabel = shortcutLabel
        self.columns = columns
        self.directNumberKeys = directNumberKeys
        self.fontSize = fontSize
        self.fontName = fontName
        self.prLabel = prLabel
    }

    private var resolvedBodyFont: Font {
        if let name = fontName {
            let size = fontSize ?? NSFont.systemFontSize
            return .custom(name, size: size)
        }
        if let size = fontSize {
            return .system(size: size, design: .monospaced)
        }
        return .system(.body, design: .monospaced)
    }

    private var resolvedCaptionFont: Font {
        if let name = fontName {
            let size = fontSize ?? NSFont.systemFontSize
            return .custom(name, size: size * 0.85)
        }
        if let size = fontSize {
            return .system(size: size * 0.85)
        }
        return .caption
    }

    private func statusColor(for status: TmuxAgentStatus) -> Color {
        // Why: Map the preserved agent state directly instead of deriving color from a running boolean.
        switch status {
        case .running:
            return Color(red: 0.30, green: 0.95, blue: 0.45)
        case .planMode, .acceptEdits:
            return Color(red: 1.00, green: 0.80, blue: 0.20)
        case .idle:
            return Color(red: 1.00, green: 0.45, blue: 0.45)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(shortcutLabel.map { directNumberKeys ? $0 : "⌘\($0)" } ?? "")
                .font(resolvedBodyFont.monospaced())
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: columns.key, alignment: .center)

            Group {
                if let status = searchItem.agentStatus {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(for: status))
                            .frame(width: 10, height: 10)
                        Text(status.label)
                            .font(resolvedCaptionFont)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("—")
                        .font(resolvedCaptionFont)
                        .foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .frame(width: columns.status, alignment: .leading)

            HStack(spacing: 6) {
                if searchItem.isAIAgent {
                    Text(searchItem.agentEmoji)
                        .font(.system(size: 16))
                        .frame(width: 20, height: 20)
                } else {
                    Image(nsImage: AppIconProvider.shared.icon(forAppName: searchItem.appName))
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(searchItem.listName)
                    .font(resolvedBodyFont)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: columns.name, alignment: .leading)

            Text(searchItem.listDetail)
                .font(resolvedCaptionFont)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: columns.detail, alignment: .leading)

            HStack(spacing: 6) {
                if let prLabel {
                    Text(prLabel)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
                if let url = searchItem.urlPattern {
                    Text(url)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(resolvedCaptionFont)
            .lineLimit(1)
            .frame(width: columns.pr, alignment: .leading)
        }
    }
}
