import SwiftUI
import FocusBMLib

struct ShortcutBarView: View {
    let items: [(item: SearchItem, label: String)]
    let directNumberKeys: Bool
    let fontSize: Double?
    let fontName: String?
    var onActivate: (SearchItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.item.id) { _, pair in
                    ShortcutBadge(
                        item: pair.item,
                        label: pair.label,
                        directNumberKeys: directNumberKeys,
                        fontSize: fontSize,
                        fontName: fontName
                    )
                    .onTapGesture { onActivate(pair.item) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct ShortcutBadge: View {
    let item: SearchItem
    let label: String
    let directNumberKeys: Bool
    let fontSize: Double?
    let fontName: String?

    // Why: BookmarkRow と同じ解決ロジックを適用。固定サイズではなく設定値を優先
    private var resolvedLabelFont: Font {
        if let name = fontName {
            let size = fontSize ?? NSFont.systemFontSize
            return .custom(name, size: size * 0.85)
        }
        if let size = fontSize {
            return .system(size: size * 0.85, design: .monospaced)
        }
        return .caption
    }

    // Why: アイコンサイズをフォントサイズに合わせてスケール。視覚的バランスを保つ
    private var iconSize: CGFloat {
        let base = fontSize ?? NSFont.systemFontSize
        return CGFloat(base * 1.4)
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: AppIconProvider.shared.icon(forAppName: item.appName))
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .accessibilityLabel(item.displayName)
            Text(directNumberKeys ? label : "⌘\(label)")
                .font(resolvedLabelFont)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(6)
        .accessibilityLabel("\(item.displayName) shortcut \(label)")
    }
}
