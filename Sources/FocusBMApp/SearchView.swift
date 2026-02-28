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
                        if viewModel.restoreSelected() {
                            panel?.close()
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Item list
            if viewModel.searchItems.isEmpty {
                Text("No bookmarks found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(viewModel.searchItems.enumerated()), id: \.element.id) { index, item in
                                BookmarkRow(
                                    searchItem: item,
                                    isSelected: index == viewModel.selectedIndex,
                                    shortcutIndex: index < 9 ? index : nil,
                                    fontSize: viewModel.listFontSize
                                )
                                .id(item.id)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(index == viewModel.selectedIndex
                                            ? Color.accentColor.opacity(0.2)
                                            : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedIndex = index
                                    if viewModel.restoreSelected() {
                                        panel?.close()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        if let item = viewModel.searchItems[safe: newIndex] {
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

