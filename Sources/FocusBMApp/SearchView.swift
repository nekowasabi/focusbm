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

            // Bookmark list
            if viewModel.filtered.isEmpty {
                Text("No bookmarks found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(viewModel.filtered.enumerated()), id: \.element.id) { index, bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            isSelected: index == viewModel.selectedIndex
                        )
                        .id(bookmark.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedIndex = index
                            if viewModel.restoreSelected() {
                                panel?.close()
                            }
                        }
                        .listRowBackground(
                            index == viewModel.selectedIndex
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        if let bm = viewModel.filtered[safe: newIndex] {
                            proxy.scrollTo(bm.id)
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
        .background(KeyEventHandling(viewModel: viewModel, panel: panel))
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

// Handle keyboard events (up/down/enter/escape)
struct KeyEventHandling: NSViewRepresentable {
    let viewModel: SearchViewModel
    weak var panel: SearchPanel?

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.viewModel = viewModel
        view.panel = panel
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.viewModel = viewModel
        nsView.panel = panel
    }
}

class KeyEventView: NSView {
    var viewModel: SearchViewModel?
    var panel: SearchPanel?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            viewModel?.moveUp()
        case 125: // Down arrow
            viewModel?.moveDown()
        case 36: // Return/Enter
            if viewModel?.restoreSelected() == true {
                panel?.close()
            }
        case 53: // Escape
            panel?.close()
        default:
            super.keyDown(with: event)
        }
    }
}
