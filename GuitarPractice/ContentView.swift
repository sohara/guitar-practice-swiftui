import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if appState.needsAPIKey {
                APIKeySetupView(appState: appState)
            } else {
                MainContentView(appState: appState)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsView(appState: appState)
        }
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @ObservedObject var appState: AppState
    @FocusState private var isSearchFocused: Bool

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
            if appState.isLoading && appState.library.isEmpty {
                LoadingView()
            } else if let error = appState.libraryState.error {
                ErrorView(error: error) {
                    Task { await appState.refresh() }
                }
            } else {
                NavigationSplitView {
                    // Left: Library with search/filter
                    LibrarySidebarView(appState: appState, isSearchFocused: $isSearchFocused)
                        .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                } detail: {
                    // Right: Selected items
                    SelectedItemsView(appState: appState)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 350)
                }
                .navigationSplitViewStyle(.balanced)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Footer with keyboard hints
            FooterView()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .task {
            await appState.loadData()
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
        .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
            isSearchFocused = true
            return .handled
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guitar Practice")
                    .font(.custom("SF Mono", size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Practice Library")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray)
                    .tracking(2)
                    .textCase(.uppercase)
            }

            Spacer()

            // Stats
            HStack(spacing: 20) {
                StatBadge(
                    icon: "music.note.list",
                    value: "\(appState.filteredLibrary.count)",
                    total: appState.library.count,
                    color: .cyan
                )
                StatBadge(
                    icon: "clock",
                    value: "\(appState.sessions.count)",
                    color: .orange
                )
                StatBadge(
                    icon: "checkmark.circle",
                    value: "\(appState.selectedItems.count)",
                    color: .green
                )
            }

            Spacer()
                .frame(width: 20)

            // Settings button
            Button {
                appState.isSettingsPresented = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            // Refresh button
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: appState.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(appState.isLoading ? 360 : 0))
                    .animation(appState.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoading)
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    var total: Int? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            if let total = total, value != "\(total)" {
                Text("\(value)/\(total)")
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else {
                Text(value)
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Library Sidebar

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

// MARK: - Filter Bar

struct FilterBarView: View {
    @ObservedObject var appState: AppState
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 10) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextField("Search...", text: $appState.searchText)
                    .font(.custom("SF Mono", size: 13))
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)
                    .onSubmit {
                        isSearchFocused.wrappedValue = false
                    }

                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // Filter and sort row
            HStack(spacing: 12) {
                // Type filter
                Menu {
                    Button("All Types") {
                        appState.typeFilter = nil
                    }
                    Divider()
                    ForEach(ItemType.allCases, id: \.self) { type in
                        Button {
                            appState.typeFilter = type
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.typeFilter?.icon ?? "line.3.horizontal.decrease")
                            .font(.system(size: 10))
                        Text(appState.typeFilter?.rawValue ?? "All")
                            .font(.custom("SF Mono", size: 11))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .menuStyle(.borderlessButton)

                // Sort option
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            if appState.sortOption == option {
                                appState.sortAscending.toggle()
                            } else {
                                appState.sortOption = option
                                appState.sortAscending = true
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if appState.sortOption == option {
                                    Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text(appState.sortOption.rawValue)
                            .font(.custom("SF Mono", size: 11))
                        Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .menuStyle(.borderlessButton)

                Spacer()
            }
        }
    }
}

// MARK: - Library List

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
                            isFocused: appState.focusedItemIndex == index
                        ) {
                            appState.toggleSelection(item)
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

struct LibraryItemRow: View {
    let item: LibraryItem
    let isSelected: Bool
    let isFocused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .green : .gray.opacity(0.4))

                // Type icon
                Image(systemName: item.type?.icon ?? "questionmark")
                    .font(.system(size: 14))
                    .foregroundColor(typeColor(item.type))
                    .frame(width: 20)

                // Name
                Text(item.name)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Artist (if song)
                if let artist = item.artist {
                    Text("— \(artist)")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Stats
                if let lastPracticed = item.lastPracticed {
                    Text(formatRelativeDate(lastPracticed))
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }

                if item.timesPracticed > 0 {
                    Text("×\(item.timesPracticed)")
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.cyan.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isFocused {
                        Color.orange.opacity(0.15)
                    } else if isSelected {
                        Color.green.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                isFocused ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        .padding(.horizontal, 4)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    private func typeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "1d ago" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }
}

// MARK: - Selected Items View

struct SelectedItemsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Selected Items")
                    .font(.custom("SF Mono", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                if !appState.selectedItems.isEmpty {
                    let totalMinutes = appState.selectedItems.reduce(0) { $0 + $1.plannedMinutes }
                    Text("\(totalMinutes) min")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.orange)

                    Button {
                        appState.clearSelection()
                    } label: {
                        Text("Clear")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(Color.white.opacity(0.1))

            if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No items selected")
                        .font(.custom("SF Mono", size: 13))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Click items in the library or press Space")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.3))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(appState.selectedItems.enumerated()), id: \.element.id) { index, selected in
                            SelectedItemRow(
                                selected: selected,
                                onRemove: {
                                    appState.removeSelectedItem(at: index)
                                },
                                onAdjustTime: { delta in
                                    appState.updatePlannedTime(at: index, minutes: selected.plannedMinutes + delta)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

struct SelectedItemRow: View {
    let selected: SelectedItem
    let onRemove: () -> Void
    let onAdjustTime: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: selected.item.type?.icon ?? "questionmark")
                .font(.system(size: 14))
                .foregroundColor(typeColor(selected.item.type))
                .frame(width: 20)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(selected.item.name)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = selected.item.artist {
                    Text(artist)
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.gray.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time adjustment
            HStack(spacing: 4) {
                Button {
                    onAdjustTime(-1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Text("\(selected.plannedMinutes)m")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.orange)
                    .frame(width: 36)

                Button {
                    onAdjustTime(1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.6))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func typeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    var body: some View {
        HStack(spacing: 16) {
            KeyHint(key: "↑↓", action: "navigate")
            KeyHint(key: "j/k", action: "navigate")
            KeyHint(key: "space", action: "select")
            KeyHint(key: "/", action: "search")
            KeyHint(key: "⌘R", action: "refresh")
            KeyHint(key: "⌘,", action: "settings")

            Spacer()

            Text("Phase 2: Library View")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

struct KeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.custom("SF Mono", size: 10))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)

            Text("Loading from Notion...")
                .font(.custom("SF Mono", size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Failed to load data")
                .font(.custom("SF Mono", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(error.localizedDescription)
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - API Key Setup View

struct APIKeySetupView: View {
    @ObservedObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Notion API Key Required")
                .font(.custom("SF Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Enter your Notion integration API key to connect.")
                .font(.custom("SF Mono", size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                SecureField("ntn_...", text: $apiKey)
                    .font(.custom("SF Mono", size: 14))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .frame(width: 400)

                if let error = errorMessage {
                    Text(error)
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.red)
                }
            }

            Button("Connect to Notion") {
                saveAPIKey()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(apiKey.isEmpty)

            Spacer()

            Text("Your API key is stored securely in Keychain")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 20)
        }
        .padding(40)
    }

    private func saveAPIKey() {
        do {
            try appState.setAPIKey(apiKey)
            Task { await appState.loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.custom("SF Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                Text("NOTION CONNECTION")
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray)
                    .tracking(2)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected")
                        .font(.custom("SF Mono", size: 14))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Disconnect") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
            }
            .frame(maxWidth: 400)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
        .padding(24)
        .frame(width: 500, height: 300)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .confirmationDialog(
            "Disconnect from Notion?",
            isPresented: $showingClearConfirmation
        ) {
            Button("Disconnect", role: .destructive) {
                try? appState.clearAPIKey()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your API key from Keychain.")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
