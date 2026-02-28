import SwiftUI
import FocusBMLib

struct BookmarkRow: View {
    let searchItem: SearchItem
    let isSelected: Bool
    let shortcutIndex: Int?  // 0-based; nil if >= 9
    let fontSize: Double?

    private var resolvedBodyFont: Font {
        if let size = fontSize {
            return .system(size: size, design: .monospaced)
        }
        return .system(.body, design: .monospaced)
    }

    private var resolvedCaptionFont: Font {
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

            // Item info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(searchItem.displayName)
                        .font(resolvedBodyFont)
                        .fontWeight(isSelected ? .bold : .regular)
                    Spacer()
                    if !searchItem.context.isEmpty && searchItem.context != "default" {
                        Text("[\(searchItem.context)]")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    if let idx = shortcutIndex {
                        Text("⌘\(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
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
