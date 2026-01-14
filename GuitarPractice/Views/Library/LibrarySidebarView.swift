import SwiftUI

struct LibrarySidebarView: View {
    @ObservedObject var appState: AppState
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            // Search and filters bar
            FilterBarView(appState: appState, isSearchFocused: isSearchFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Library list
            LibraryListView(appState: appState)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
    }
}
