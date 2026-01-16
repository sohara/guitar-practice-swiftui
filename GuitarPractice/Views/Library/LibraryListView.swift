import SwiftUI

struct LibraryListView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(appState.filteredLibrary.enumerated()), id: \.element.id) { index, item in
                        LibraryItemRow(
                            item: item,
                            isSelected: appState.isSelected(item),
                            isFocused: appState.focusedPanel == .library && appState.focusedItemIndex == index,
                            onFocus: {
                                appState.focusedPanel = .library
                                appState.focusedItemIndex = index
                            },
                            onToggle: {
                                appState.toggleSelection(item)
                            }
                        )
                        .contextMenu {
                            Button {
                                appState.openItemInNotion(id: item.id)
                            } label: {
                                Label("Open in Notion", systemImage: "arrow.up.right.square")
                            }
                        }
                        .id(item.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: appState.focusedItemIndex) { _, newIndex in
                if let index = newIndex, index < appState.filteredLibrary.count {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(appState.filteredLibrary[index].id, anchor: .center)
                    }
                }
            }
        }
    }
}
