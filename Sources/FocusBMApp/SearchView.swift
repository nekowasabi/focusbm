import SwiftUI
import FocusBMLib

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isPromptFieldFocused: Bool
    weak var panel: SearchPanel?

    private func bookmarkRow(
        index: Int,
        pair: (item: SearchItem, label: String?),
        columns: TableColumns
    ) -> some View {
        BookmarkRow(
            searchItem: pair.item,
            isSelected: index == viewModel.selectedIndex,
            shortcutLabel: pair.label,
            columns: columns,
            directNumberKeys: viewModel.appSettings?.directNumberKeys ?? true,
            fontSize: viewModel.listFontSize,
            fontName: viewModel.fontName,
            prLabel: viewModel.prLabel(for: pair.item)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TableColumns.horizontalPadding)
        .padding(.vertical, 7)
        .background(
            Rectangle()
                .fill(index == viewModel.selectedIndex
                    ? Color.accentColor.opacity(
                        viewModel.isAutoExecuteHighlighted && viewModel.mainListAssignments.count == 1
                            ? 0.5 : 0.2)
                    : Color.clear)
        )
        .overlay(alignment: .leading) {
            if index == viewModel.selectedIndex {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
        .id(pair.item.id)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                viewModel.hoveredIndex = index
            } else if viewModel.hoveredIndex == index {
                viewModel.hoveredIndex = nil
            }
        }
        .onTapGesture {
            viewModel.selectedIndex = index
            panel?.executeItem(pair.item)
        }
    }

    private func tableHeader(columns: TableColumns) -> some View {
        HStack(spacing: 0) {
            Text("キー").frame(width: columns.key, alignment: .center)
            Text("状態").frame(width: columns.status, alignment: .leading)
            Text("名前").frame(width: columns.name, alignment: .leading)
            Text("アプリ／端末").frame(width: columns.detail, alignment: .leading)
            Text("PR／URL").frame(width: columns.pr, alignment: .leading)
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundColor(.secondary)
        .lineLimit(1)
        .padding(.horizontal, TableColumns.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack {
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
                        if let item = viewModel.selectedItem() {
                            panel?.executeItem(item)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            GeometryReader { geo in
                let columns = TableColumns(totalWidth: geo.size.width)
                VStack(spacing: 0) {
                    tableHeader(columns: columns)
                    Divider()

                    // Item list
                    if viewModel.mainListAssignments.isEmpty {
                        Text("No bookmarks found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(viewModel.mainListAssignments.enumerated()), id: \.element.item.id) { index, pair in
                                        bookmarkRow(index: index, pair: pair, columns: columns)
                                    }
                                }
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
                        panel?.executeItem(item)
                    }
                )
            }
        }
        if let preview = viewModel.screenPreview {
            GeometryReader { geo in
                let card = PreviewLayout.sizeOnMonitor(
                    monitorWidth: geo.size.width,
                    monitorHeight: geo.size.height,
                    previewWidth: viewModel.previewWidth,
                    previewHeight: viewModel.previewHeight,
                    fillMonitor: preview.isTiled
                )
                AgentScreenPreviewOverlay(
                    state: preview,
                    cardSize: CGSize(width: card.width, height: card.height),
                    fontSize: viewModel.previewFontSize,
                    fontName: viewModel.previewFontName ?? viewModel.fontName,
                    promptText: $viewModel.promptDraft,
                    promptTargetIndex: viewModel.promptTargetIndex,
                    promptTargetKeyLabel: viewModel.promptTargetFlags == .control ? "Ctrl" : "Cmd",
                    promptError: viewModel.promptError,
                    isPromptFocused: $isPromptFieldFocused,
                    onSubmitPrompt: { viewModel.sendPromptToPreview() }
                ) {
                    _ = viewModel.dismissScreenPreview()
                    panel?.applyPreviewWindowLayout(visible: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        }
        .onChange(of: viewModel.isActive) { active in
            if active {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: viewModel.screenPreview != nil) { showing in
            panel?.applyPreviewWindowLayout(visible: showing)
            if !showing { isSearchFieldFocused = true }
        }
        // Why: The VM owns prompt focus so SearchPanel's key monitor can read and change it.
        //      Async because the prompt field is inserted in the same update that requests focus.
        .onChange(of: viewModel.isPromptFieldFocused) { focused in
            DispatchQueue.main.async { isPromptFieldFocused = focused }
        }
        .onChange(of: isPromptFieldFocused) { focused in
            viewModel.isPromptFieldFocused = focused
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

