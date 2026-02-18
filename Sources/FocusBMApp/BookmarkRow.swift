import SwiftUI
import FocusBMLib

struct BookmarkRow: View {
    let bookmark: Bookmark
    let isSelected: Bool
    let shortcutIndex: Int?  // 0-based; nil if >= 9

    var body: some View {
        HStack {
            // Selection indicator
            Text(isSelected ? "▸" : " ")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 16)

            // Bookmark info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(bookmark.id)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(isSelected ? .bold : .regular)
                    Spacer()
                    if bookmark.context != "default" {
                        Text("[\(bookmark.context)]")
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
                    Text(bookmark.appName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if case .browser(let url, _, _) = bookmark.state {
                        Text("— \(url)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
