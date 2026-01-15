import SwiftUI
import SwiftData

struct MainContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isMainFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(appState: appState)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Main split view content
            if appState.isRefreshing || (appState.isLoading && appState.library.isEmpty) {
                LoadingView()
            } else if let error = appState.libraryState.error {
                ErrorView(error: error) {
                    Task { await appState.refresh() }
                }
            } else {
                HSplitView {
                    // Left: Library with search/filter
                    LibrarySidebarView(appState: appState, isSearchFocused: $isSearchFocused)
                        .frame(minWidth: 300, idealWidth: 450)

                    // Right: Stats or Calendar + Session detail
                    // Using ZStack with opacity to preserve HSplitView divider position
                    ZStack {
                        SessionPanelView(appState: appState)
                            .opacity(appState.isShowingStats ? 0 : 1)

                        StatsDashboardView(appState: appState)
                            .opacity(appState.isShowingStats ? 1 : 0)
                    }
                    .frame(minWidth: 280, idealWidth: 450)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer with keyboard hints
            FooterView()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .task {
            appState.setupCache(modelContext: modelContext)
            await appState.loadDataIfNeeded()
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isMainFocused)
        .onAppear {
            isMainFocused = true
        }
        .onChange(of: appState.focusedPanel) { _, _ in
            // Refocus main view when panel changes (e.g., clicking on items)
            if !isSearchFocused {
                isMainFocused = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            // Refocus main view when exiting search
            if !focused {
                isMainFocused = true
            }
        }
        .onChange(of: appState.searchText) { _, _ in
            // Clamp focus index when filters change
            appState.clampFocusedItemIndex()
        }
        .onChange(of: appState.typeFilter) { _, _ in
            appState.clampFocusedItemIndex()
        }
        .onChange(of: appState.showRecentOnly) { _, _ in
            appState.clampFocusedItemIndex()
        }
        .onKeyPress(.upArrow) {
            appState.moveFocusUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            appState.moveFocusDown()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in
            if !isSearchFocused {
                appState.moveFocusDown()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in
            if !isSearchFocused {
                appState.moveFocusUp()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            if !isSearchFocused {
                appState.toggleFocusedItem()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if appState.focusedPanel == .library {
                appState.toggleFocusedItem()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
            isSearchFocused = true
            return .handled
        }
        .onKeyPress(.tab) {
            appState.toggleFocusedPanel()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "=+")) { _ in
            if appState.focusedPanel == .selectedItems {
                appState.adjustFocusedSelectedTime(delta: 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "-_")) { _ in
            if appState.focusedPanel == .selectedItems {
                appState.adjustFocusedSelectedTime(delta: -1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            if appState.focusedPanel == .selectedItems {
                appState.removeFocusedSelected()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [KeyEquivalent("f")], phases: .down) { press in
            if press.modifiers.contains(.control) && appState.focusedPanel == .library && !isSearchFocused {
                appState.pageDown()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [KeyEquivalent("b")], phases: .down) { press in
            if press.modifiers.contains(.control) && appState.focusedPanel == .library && !isSearchFocused {
                appState.pageUp()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "tT")) { _ in
            if !isSearchFocused {
                Task {
                    await appState.jumpToToday()
                }
                return .handled
            }
            return .ignored
        }
    }
}
