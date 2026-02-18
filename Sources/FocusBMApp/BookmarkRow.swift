import SwiftUI
import FocusBMLib

struct BookmarkRow: View {
    let bookmark: Bookmark
    let isSelected: Bool

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
                    Text("[\(bookmark.context)]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
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
