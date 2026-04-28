import SwiftUI
import FocusBMLib

struct BookmarkRow: View {
    let searchItem: SearchItem
    let isSelected: Bool
    let shortcutLabel: String?
    let directNumberKeys: Bool
    let fontSize: Double?
    let fontName: String?

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

    var body: some View {
        HStack {
            // Selection indicator
            Text(isSelected ? "▸" : " ")
                .font(resolvedBodyFont)
                .foregroundColor(.accentColor)
                .frame(width: 16)

            // App icon
            if searchItem.isAIAgent {
                Text(searchItem.agentEmoji)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
            } else {
                Image(nsImage: AppIconProvider.shared.icon(forAppName: searchItem.appName))
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            // Shortcut badge (fixed width to keep displayName aligned)
            ZStack {
                if let label = shortcutLabel {
                    Text(directNumberKeys ? label : "⌘\(label)")
                        .font(resolvedCaptionFont)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .frame(width: 32)

            // Item info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let agent = searchItem.agentDisplay {
                        Text("\(agent.emoji) \(agent.nameWithoutEmoji)")
                            .foregroundColor(agent.isRunning ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                            .font(resolvedBodyFont)
                            .fontWeight(isSelected ? .bold : .regular)
                    } else {
                        Text(searchItem.displayName)
                            .font(resolvedBodyFont)
                            .fontWeight(isSelected ? .bold : .regular)
                    }
                    Spacer()
                }

                HStack {
                    Text(searchItem.appName)
                        .font(resolvedCaptionFont)
                        .foregroundColor(.secondary)

                    if let url = searchItem.urlPattern {
                        Text("— \(url)")
                            .font(resolvedCaptionFont)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
