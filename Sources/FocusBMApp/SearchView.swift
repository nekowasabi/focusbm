import SwiftUI
import FocusBMLib

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    weak var panel: SearchPanel?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title2)
                TextField("Search bookmarks...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        if let target = viewModel.restoreSelected() {
                            panel?.close()
                            DispatchQueue.main.async {
                                target.activate()
                            }
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Item list
            if viewModel.mainListAssignments.isEmpty {
                Text("No bookmarks found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(viewModel.mainListAssignments.enumerated()), id: \.element.item.id) { index, pair in
                                BookmarkRow(
                                    searchItem: pair.item,
                                    isSelected: index == viewModel.selectedIndex,
                                    shortcutLabel: pair.label,
                                    directNumberKeys: viewModel.appSettings?.directNumberKeys ?? true,
                                    fontSize: viewModel.listFontSize,
                                    fontName: viewModel.fontName
                                )
                                .id(pair.item.id)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(index == viewModel.selectedIndex
                                            ? Color.accentColor.opacity(
                                                viewModel.isAutoExecuteHighlighted && viewModel.mainListAssignments.count == 1
                                                    ? 0.5 : 0.2)
                                            : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                    if let target = viewModel.restoreSelected() {
                                        panel?.close()
                                        DispatchQueue.main.async {
                                            target.activate()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        // Why: mainListAssignments[safe: newIndex]?.item を参照。理由: selectedIndex はメインリストのみを追跡する新契約
                        if let item = viewModel.mainListAssignments[safe: newIndex]?.item {
                            withAnimation {
                                proxy.scrollTo(item.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Footer hint
            Divider()
            HStack(spacing: 16) {
                Label("移動", systemImage: "arrow.up.arrow.down")
                Label("復元", systemImage: "return")
                Label("閉じる", systemImage: "escape")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Shortcut bar: query が空かつショートカットアイテムがある場合のみ表示
            // Why: query 非空時は検索モードのため非表示。空の場合のみバーを表示する設計
            if viewModel.query.isEmpty && !viewModel.shortcutBarItems.isEmpty {
                Divider()
                ShortcutBarView(
                    items: viewModel.shortcutBarItems,
                    directNumberKeys: viewModel.appSettings?.directNumberKeys ?? true,
                    fontSize: viewModel.listFontSize,
                    fontName: viewModel.fontName,
                    onActivate: { item in
                        if let target = viewModel.activationTarget(for: item) {
                            panel?.close()
                            DispatchQueue.main.async {
                                target.activate()
                            }
                        }
                    }
                )
            }
        }
        .onChange(of: viewModel.isActive) { active in
            if active {
                isSearchFieldFocused = true
            }
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

