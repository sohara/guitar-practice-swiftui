import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

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
            } else if appState.isPracticing {
                PracticeView(appState: appState)
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
    @Environment(\.modelContext) private var modelContext
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
                HSplitView {
                    // Left: Library with search/filter
                    LibrarySidebarView(appState: appState, isSearchFocused: $isSearchFocused)
                        .frame(minWidth: 300, idealWidth: 450)

                    // Right: Stats or Calendar + Session detail
                    if appState.isShowingStats {
                        StatsDashboardView(appState: appState)
                            .frame(minWidth: 280, idealWidth: 450)
                    } else {
                        SessionPanelView(appState: appState)
                            .frame(minWidth: 280, idealWidth: 450)
                    }
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
                .help("Library Items")
                StatBadge(
                    icon: "clock",
                    value: "\(appState.sessions.count)",
                    color: .orange
                )
                .help("Practice Sessions")
                StatBadge(
                    icon: "checkmark.circle",
                    value: "\(appState.selectedItems.count)",
                    color: .green
                )
                .help("Items in Session")
            }

            Spacer()
                .frame(width: 20)

            // Stats toggle button
            Button {
                appState.toggleStatsView()
            } label: {
                Image(systemName: appState.isShowingStats ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 16))
                    .foregroundColor(appState.isShowingStats ? .cyan : .gray)
            }
            .buttonStyle(.plain)
            .help(appState.isShowingStats ? "Hide Stats" : "Show Stats")

            // Open in Notion button
            Button {
                appState.openFocusedItemInNotion()
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .help("Open in Notion")

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
            .help("Settings")

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
            .help("Refresh Data")
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
                            isFocused: appState.focusedPanel == .library && appState.focusedItemIndex == index,
                            onFocus: {
                                appState.focusedPanel = .library
                                appState.focusedItemIndex = index
                            },
                            onToggle: {
                                appState.toggleSelection(item)
                            }
                        )
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
    let onFocus: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onFocus) {
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
        .onTapGesture(count: 2) {
            onToggle()
        }
        .onTapGesture(count: 1) {
            onFocus()
        }
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
            // Session picker header
            SessionHeaderView(appState: appState)

            Divider()
                .background(Color.white.opacity(0.1))

            // Items list or empty state
            if appState.isLoadingSession {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.orange)
                    Text("Loading session...")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if appState.currentSession == nil {
                EmptySessionView(appState: appState)
            } else if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Session is empty")
                        .font(.custom("SF Mono", size: 13))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Add items from the library")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.3))
                    Spacer()
                }
            } else {
                // Items list with drag and drop
                List {
                    ForEach(Array(appState.selectedItems.enumerated()), id: \.element.id) { index, selected in
                        SelectedItemRow(
                            selected: selected,
                            isFocused: appState.focusedPanel == .selectedItems && appState.focusedSelectedIndex == index,
                            onFocus: {
                                appState.focusedPanel = .selectedItems
                                appState.focusedSelectedIndex = index
                            },
                            onRemove: {
                                appState.removeSelectedItem(at: index)
                            },
                            onAdjustTime: { delta in
                                appState.updatePlannedTime(at: index, minutes: selected.plannedMinutes + delta)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                    .onMove { source, destination in
                        appState.moveSelectedItem(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer with save button
            if appState.currentSession != nil {
                SessionFooterView(appState: appState)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

struct SessionHeaderView: View {
    @ObservedObject var appState: AppState

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private func formatSessionLabel(_ session: PracticeSession) -> String {
        dateFormatter.string(from: session.date)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Session picker
                Menu {
                    Button("New Session...") {
                        Task {
                            if let session = await appState.createNewSession() {
                                await appState.selectSession(session)
                            }
                        }
                    }

                    if !appState.sessions.isEmpty {
                        Divider()

                        ForEach(appState.sessions) { session in
                            Button {
                                Task {
                                    await appState.selectSession(session)
                                }
                            } label: {
                                HStack {
                                    Text(formatSessionLabel(session))
                                    if appState.currentSession?.id == session.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(appState.currentSession.map { formatSessionLabel($0) } ?? "Select Session")
                            .font(.custom("SF Mono", size: 14))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(appState.currentSession != nil ? .white : .gray)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Unsaved indicator
                if appState.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }

                // Clear button
                if !appState.selectedItems.isEmpty {
                    Button {
                        appState.clearSelection()
                    } label: {
                        Text("Clear")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Time summary
            if !appState.selectedItems.isEmpty {
                HStack {
                    // Planned time
                    Label("\(appState.totalPlannedMinutes)m planned", systemImage: "clock")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.orange.opacity(0.8))

                    Spacer()

                    // Actual time (if any)
                    if appState.totalActualMinutes > 0 {
                        Label("\(formatMinutesAsTime(appState.totalActualMinutes)) actual", systemImage: "checkmark.circle")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.green.opacity(0.8))
                    }

                    // Item count
                    Text("\(appState.selectedItems.count) items")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EmptySessionView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.3))

            Text("No session selected")
                .font(.custom("SF Mono", size: 14))
                .foregroundColor(.gray.opacity(0.6))

            Text("Select an existing session or create a new one")
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.gray.opacity(0.4))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    if let session = await appState.createNewSession() {
                        await appState.selectSession(session)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Session")
                }
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }
}

struct SessionFooterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack {
                // Error message
                if let error = appState.sessionError {
                    Text(error.localizedDescription)
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Spacer()

                // Practice button
                Button {
                    appState.startPractice()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Practice")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedItems.isEmpty)
                .keyboardShortcut("p", modifiers: .command)

                // Save button
                Button {
                    Task {
                        await appState.saveSession()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if appState.isSavingSession {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        Text("Save")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.hasUnsavedChanges ? Color.orange : Color.gray.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.isSavingSession || !appState.hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

struct SelectedItemRow: View {
    let selected: SelectedItem
    let isFocused: Bool
    let onFocus: () -> Void
    let onRemove: () -> Void
    let onAdjustTime: (Int) -> Void

    var isCompleted: Bool {
        selected.actualMinutes != nil && selected.actualMinutes! > 0
    }

    var body: some View {
        HStack(spacing: 10) {
            // Completion indicator / drag handle
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundColor(isCompleted ? .green : .gray.opacity(0.4))
                .frame(width: 16)

            // Type icon
            Image(systemName: selected.item.type?.icon ?? "questionmark")
                .font(.system(size: 12))
                .foregroundColor(typeColor(selected.item.type))
                .frame(width: 16)

            // Name and artist
            VStack(alignment: .leading, spacing: 1) {
                Text(selected.item.name)
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = selected.item.artist {
                    Text(artist)
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actual time (if practiced)
            if let actual = selected.actualMinutes, actual > 0 {
                Text(formatMinutesAsTime(actual))
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.green.opacity(0.7))
            }

            // Time adjustment
            HStack(spacing: 3) {
                Button {
                    onAdjustTime(-1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)

                Text("\(selected.plannedMinutes)m")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.orange)
                    .frame(width: 28)

                Button {
                    onAdjustTime(1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.5))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isFocused ? Color.cyan.opacity(0.15) : (isCompleted ? Color.green.opacity(0.05) : Color.clear))
        )
        .overlay(
            isFocused ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
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
        HStack(spacing: 12) {
            KeyHint(key: "tab", action: "switch panel")
            KeyHint(key: "↑↓", action: "navigate")
            KeyHint(key: "^F/B", action: "page")
            KeyHint(key: "enter", action: "add/remove")
            KeyHint(key: "+/-", action: "time")
            KeyHint(key: "⌫", action: "remove")
            KeyHint(key: "⌘O", action: "notion")
            KeyHint(key: "⌘P", action: "practice")
            KeyHint(key: "⌘S", action: "save")

            Spacer()

            Text("Guitar Practice")
                .font(.custom("SF Mono", size: 12))
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
                .font(.custom("SF Mono", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        HSplitView {
            // Left: Skeleton library
            VStack(spacing: 0) {
                // Fake filter bar
                SkeletonFilterBar()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Skeleton rows
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { _ in
                            SkeletonLibraryRow()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.09))
            .frame(minWidth: 300, idealWidth: 450)

            // Right: Skeleton selected items
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.orange)
                Text("Loading from Notion...")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.07, blue: 0.10))
            .frame(minWidth: 280, idealWidth: 450)
        }
    }
}

struct SkeletonFilterBar: View {
    var body: some View {
        VStack(spacing: 10) {
            // Search field skeleton
            ShimmerView()
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Filter buttons skeleton
            HStack(spacing: 12) {
                ShimmerView()
                    .frame(width: 60, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                ShimmerView()
                    .frame(width: 100, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
        }
    }
}

struct SkeletonLibraryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Circle placeholder
            ShimmerView()
                .frame(width: 16, height: 16)
                .clipShape(Circle())

            // Icon placeholder
            ShimmerView()
                .frame(width: 20, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Name placeholder
            ShimmerView()
                .frame(width: CGFloat.random(in: 100...200), height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Artist placeholder (sometimes)
            if Bool.random() {
                ShimmerView()
                    .frame(width: CGFloat.random(in: 60...120), height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            Spacer()

            // Date placeholder
            ShimmerView()
                .frame(width: 50, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            Color.white.opacity(0.05)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.6)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
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

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Practice History")
                    .font(.custom("SF Mono", size: 20))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.custom("SF Mono", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            session: sessionForDate(date),
                            isToday: calendar.isDateInToday(date),
                            isSelected: isSelectedDate(date)
                        ) {
                            selectSession(for: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal)

            Divider()
                .padding(.top, 16)

            // Stats footer
            HStack(spacing: 24) {
                CalendarStatView(
                    label: "This Month",
                    value: "\(sessionsThisMonth)",
                    icon: "calendar",
                    color: .cyan
                )
                CalendarStatView(
                    label: "Total Time",
                    value: formatTotalTime(totalMinutesThisMonth),
                    icon: "clock",
                    color: .orange
                )
                CalendarStatView(
                    label: "Current Streak",
                    value: "\(currentStreak) days",
                    icon: "flame",
                    color: .pink
                )
            }
            .padding()
        }
        .frame(width: 420, height: 520)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        // Generate 6 weeks worth of days (max needed for any month)
        for _ in 0..<42 {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if days.isEmpty || calendar.compare(currentDate, to: monthInterval.start, toGranularity: .month) == .orderedAscending {
                days.append(nil) // Padding before month starts
            } else {
                days.append(nil) // Padding after month ends
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Trim trailing empty rows
        while days.count > 7 && days.suffix(7).allSatisfy({ $0 == nil }) {
            days.removeLast(7)
        }

        return days
    }

    private var sessionsByDate: [Date: PracticeSession] {
        var dict: [Date: PracticeSession] = [:]
        for session in appState.sessions {
            let startOfDay = calendar.startOfDay(for: session.date)
            dict[startOfDay] = session
        }
        return dict
    }

    private var sessionsThisMonth: Int {
        appState.sessions.filter { session in
            calendar.isDate(session.date, equalTo: displayedMonth, toGranularity: .month)
        }.count
    }

    private var totalMinutesThisMonth: Double {
        // For now, just count sessions * estimated average
        // In future, we could query actual practice logs
        Double(sessionsThisMonth) * 30.0
    }

    private var currentStreak: Int {
        let sortedSessions = appState.sessions.sorted { $0.date > $1.date }
        guard !sortedSessions.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if practiced today
        if let mostRecent = sortedSessions.first,
           calendar.isDate(mostRecent.date, inSameDayAs: checkDate) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count consecutive days
        for session in sortedSessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            if calendar.isDate(sessionDay, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if sessionDay < checkDate {
                break // Gap in streak
            }
        }

        return streak
    }

    // MARK: - Helper Methods

    private func sessionForDate(_ date: Date) -> PracticeSession? {
        let startOfDay = calendar.startOfDay(for: date)
        return sessionsByDate[startOfDay]
    }

    private func isSelectedDate(_ date: Date) -> Bool {
        guard let currentSession = appState.currentSession else { return false }
        return calendar.isDate(date, inSameDayAs: currentSession.date)
    }

    private func selectSession(for date: Date) {
        if let session = sessionForDate(date) {
            Task {
                await appState.selectSession(session)
            }
            dismiss()
        }
    }

    private func formatTotalTime(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

struct CalendarDayView: View {
    let date: Date
    let session: PracticeSession?
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                    )

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.custom("SF Mono", size: 14))
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundColor(textColor)

                    // Practice indicator
                    if session != nil {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(session == nil)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .cyan.opacity(0.3)
        } else if session != nil {
            return .green.opacity(0.15)
        }
        return .clear
    }

    private var borderColor: Color {
        isToday ? .cyan : .clear
    }

    private var textColor: Color {
        if session != nil {
            return .white
        }
        return .gray.opacity(0.5)
    }
}

struct CalendarStatView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.custom("SF Mono", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Calendar Navigator (Embedded in Right Panel)

struct CalendarNavigatorView: View {
    @ObservedObject var appState: AppState

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: -1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.custom("SF Mono", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: 1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid (compact)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarNavigatorDayView(
                            date: date,
                            hasSession: appState.sessionForDate(date) != nil,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: appState.selectedDate)
                        ) {
                            Task {
                                await appState.selectDate(date)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }

            // Mini stats row
            HStack(spacing: 16) {
                MiniStatView(icon: "flame", value: "\(currentStreak)", label: "streak", color: .orange)
                MiniStatView(icon: "calendar", value: "\(sessionsThisMonth)", label: "this month", color: .cyan)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: appState.displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: appState.displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        // Generate 6 weeks worth of days (max needed for any month)
        for _ in 0..<42 {
            if calendar.isDate(currentDate, equalTo: appState.displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if days.isEmpty || calendar.compare(currentDate, to: monthInterval.start, toGranularity: .month) == .orderedAscending {
                days.append(nil) // Padding before month starts
            } else {
                days.append(nil) // Padding after month ends
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Trim trailing empty rows
        while days.count > 7 && days.suffix(7).allSatisfy({ $0 == nil }) {
            days.removeLast(7)
        }

        return days
    }

    private var sessionsThisMonth: Int {
        appState.sessions.filter { session in
            calendar.isDate(session.date, equalTo: appState.displayedMonth, toGranularity: .month)
        }.count
    }

    private var currentStreak: Int {
        let sortedSessions = appState.sessions.sorted { $0.date > $1.date }
        guard !sortedSessions.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if practiced today
        if let mostRecent = sortedSessions.first,
           calendar.isDate(mostRecent.date, inSameDayAs: checkDate) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count consecutive days
        for session in sortedSessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            if calendar.isDate(sessionDay, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if sessionDay < checkDate {
                break // Gap in streak
            }
        }

        return streak
    }
}

struct CalendarNavigatorDayView: View {
    let date: Date
    let hasSession: Bool
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderColor, lineWidth: isToday ? 1.5 : 0)
                    )

                VStack(spacing: 1) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.custom("SF Mono", size: 11))
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundColor(textColor)

                    // Practice indicator dot
                    if hasSession {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 28)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .cyan.opacity(0.3)
        } else if hasSession {
            return .green.opacity(0.1)
        }
        return .clear
    }

    private var borderColor: Color {
        isToday ? .cyan : .clear
    }

    private var textColor: Color {
        if isSelected || hasSession {
            return .white
        }
        return .gray.opacity(0.5)
    }
}

struct MiniStatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.custom("SF Mono", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(label)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Session Panel (Calendar + Detail)

struct SessionPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Calendar navigator at top
            CalendarNavigatorView(appState: appState)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Session detail below
            SessionDetailView(appState: appState)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    @ObservedObject var appState: AppState

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Session header with date
            SessionDetailHeaderView(appState: appState, dateFormatter: dateFormatter)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content based on state
            if appState.isLoadingSession {
                LoadingSessionView()
            } else if appState.currentSession == nil {
                // No session for this date
                NoSessionView(appState: appState, dateFormatter: dateFormatter)
            } else if appState.sessionViewMode == .viewing {
                // Read-only view for past sessions
                SessionViewingModeView(appState: appState)
            } else {
                // Edit mode - existing selected items functionality
                SessionEditingModeView(appState: appState)
            }
        }
    }
}

struct SessionDetailHeaderView: View {
    @ObservedObject var appState: AppState
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: appState.selectedDate))
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                if appState.currentSession != nil {
                    HStack(spacing: 8) {
                        Label("\(appState.selectedItems.count) items", systemImage: "list.bullet")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.gray)

                        if appState.totalActualMinutes > 0 {
                            Label(formatMinutesAsTime(appState.totalActualMinutes), systemImage: "clock.fill")
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.green.opacity(0.8))
                        } else if appState.totalPlannedMinutes > 0 {
                            Label("\(appState.totalPlannedMinutes)m planned", systemImage: "clock")
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Unsaved indicator
            if appState.hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }

            // Mode indicator / switch button
            if appState.currentSession != nil && appState.sessionViewMode == .viewing {
                Button {
                    appState.switchToEditMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Edit")
                            .font(.custom("SF Mono", size: 11))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.cyan.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct LoadingSessionView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(.orange)
            Text("Loading session...")
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }
}

struct NoSessionView: View {
    @ObservedObject var appState: AppState
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if appState.isSelectedDatePast {
                // Past date with no session
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.3))

                Text("No practice recorded")
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No session exists for this date")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray.opacity(0.3))
            } else {
                // Today or future date
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.3))

                Text(appState.isSelectedDateToday ? "Ready to practice?" : "Plan ahead")
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.gray.opacity(0.6))

                Button {
                    Task {
                        _ = await appState.createSessionForSelectedDate()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(appState.isSelectedDateToday ? "Start Session" : "Create Session")
                    }
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding()
    }
}

struct SessionViewingModeView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Session was empty")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                }
            } else {
                // Read-only list of practiced items
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(appState.selectedItems) { selected in
                            SessionItemReadOnlyRow(selected: selected)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Footer with "Edit" option
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))

                HStack {
                    Text("Viewing past session")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.5))

                    Spacer()

                    Button {
                        appState.switchToEditMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                            Text("Edit Session")
                                .font(.custom("SF Mono", size: 12))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.cyan.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

struct SessionItemReadOnlyRow: View {
    let selected: SelectedItem

    var body: some View {
        HStack(spacing: 10) {
            // Completion indicator
            Image(systemName: selected.actualMinutes != nil && selected.actualMinutes! > 0 ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(selected.actualMinutes != nil && selected.actualMinutes! > 0 ? .green : .gray.opacity(0.4))
                .frame(width: 16)

            // Type icon
            Image(systemName: selected.item.type?.icon ?? "questionmark")
                .font(.system(size: 12))
                .foregroundColor(typeColor(selected.item.type))
                .frame(width: 16)

            // Name and artist
            VStack(alignment: .leading, spacing: 1) {
                Text(selected.item.name)
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = selected.item.artist {
                    Text(artist)
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Times
            VStack(alignment: .trailing, spacing: 1) {
                if let actual = selected.actualMinutes, actual > 0 {
                    Text(formatMinutesAsTime(actual))
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.green.opacity(0.8))
                }
                Text("\(selected.plannedMinutes)m planned")
                    .font(.custom("SF Mono", size: 9))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            selected.actualMinutes != nil && selected.actualMinutes! > 0
                ? Color.green.opacity(0.05)
                : Color.clear
        )
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

struct SessionEditingModeView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Session is empty")
                        .font(.custom("SF Mono", size: 13))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Add items from the library")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.3))
                    Spacer()
                }
            } else {
                // Editable items list with drag and drop
                List {
                    ForEach(Array(appState.selectedItems.enumerated()), id: \.element.id) { index, selected in
                        SelectedItemRow(
                            selected: selected,
                            isFocused: appState.focusedPanel == .selectedItems && appState.focusedSelectedIndex == index,
                            onFocus: {
                                appState.focusedPanel = .selectedItems
                                appState.focusedSelectedIndex = index
                            },
                            onRemove: {
                                appState.removeSelectedItem(at: index)
                            },
                            onAdjustTime: { delta in
                                appState.updatePlannedTime(at: index, minutes: selected.plannedMinutes + delta)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                    .onMove { source, destination in
                        appState.moveSelectedItem(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer with save/practice buttons
            SessionEditingFooterView(appState: appState)
        }
    }
}

struct SessionEditingFooterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack {
                // Error message
                if let error = appState.sessionError {
                    Text(error.localizedDescription)
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Spacer()

                // Clear button
                if !appState.selectedItems.isEmpty {
                    Button {
                        appState.clearSelection()
                    } label: {
                        Text("Clear")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }

                // Practice button
                Button {
                    appState.startPractice()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Practice")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedItems.isEmpty)
                .keyboardShortcut("p", modifiers: .command)

                // Save button
                Button {
                    Task {
                        await appState.saveSession()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if appState.isSavingSession {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        Text("Save")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.hasUnsavedChanges ? Color.orange : Color.gray.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.isSavingSession || !appState.hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Stats Dashboard View

struct StatsDashboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let stats = appState.practiceStats {
                    // Overview cards
                    StatsOverviewSection(stats: stats)

                    // Recent activity
                    RecentActivitySection(stats: stats)

                    // Time breakdown by type
                    TypeBreakdownSection(stats: stats)

                    // Top items
                    TopItemsSection(stats: stats)

                    // Weekly trend
                    WeeklyTrendSection(stats: stats)
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.cyan)
                        Text("Loading statistics...")
                            .font(.custom("SF Mono", size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .onAppear {
            if appState.practiceStats == nil {
                appState.refreshStats()
            }
        }
    }
}

struct StatsOverviewSection: View {
    let stats: PracticeStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OVERVIEW")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .tracking(2)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    icon: "clock.fill",
                    title: "Total Time",
                    value: formatTotalTime(stats.totalPracticeMinutes),
                    color: .cyan
                )
                StatCard(
                    icon: "calendar",
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    color: .green
                )
                StatCard(
                    icon: "music.note.list",
                    title: "Items Practiced",
                    value: "\(stats.totalItemsPracticed)",
                    color: .orange
                )
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Avg Session",
                    value: formatMinutes(stats.averageSessionMinutes),
                    color: .pink
                )
            }

            // Streak row
            HStack(spacing: 16) {
                StreakCard(
                    icon: "flame.fill",
                    title: "Current Streak",
                    value: "\(stats.currentStreak)",
                    suffix: stats.currentStreak == 1 ? "day" : "days",
                    color: .orange
                )
                StreakCard(
                    icon: "trophy.fill",
                    title: "Longest Streak",
                    value: "\(stats.longestStreak)",
                    suffix: stats.longestStreak == 1 ? "day" : "days",
                    color: .yellow
                )
            }
        }
    }

    private func formatTotalTime(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private func formatMinutes(_ minutes: Double) -> String {
        return "\(Int(minutes))m"
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.custom("SF Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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

struct StreakCard: View {
    let icon: String
    let title: String
    let value: String
    let suffix: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.custom("SF Mono", size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(suffix)
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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

struct RecentActivitySection: View {
    let stats: PracticeStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 7 DAYS")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .tracking(2)

            HStack(spacing: 4) {
                ForEach(stats.recentDays, id: \.date) { day in
                    RecentDayBar(
                        date: day.date,
                        minutes: day.minutes,
                        itemCount: day.itemCount,
                        maxMinutes: stats.recentDays.map(\.minutes).max() ?? 1
                    )
                }
            }
            .frame(height: 80)
            .padding(.vertical, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct RecentDayBar: View {
    let date: Date
    let minutes: Double
    let itemCount: Int
    let maxMinutes: Double

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(minutes > 0 ? Color.green : Color.gray.opacity(0.2))
                    .frame(height: barHeight)
            }
            .frame(height: 50)

            // Day label
            Text(dayFormatter.string(from: date).prefix(1))
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(calendar.isDateInToday(date) ? .cyan : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var barHeight: CGFloat {
        guard maxMinutes > 0, minutes > 0 else { return 4 }
        return max(4, CGFloat(minutes / maxMinutes) * 50)
    }
}

struct TypeBreakdownSection: View {
    let stats: PracticeStats

    private var typeData: [(type: ItemType, minutes: Double, percentage: Double)] {
        let total = stats.minutesByType.values.reduce(0, +)
        guard total > 0 else { return [] }

        return stats.minutesByType
            .sorted { $0.value > $1.value }
            .map { (type: $0.key, minutes: $0.value, percentage: $0.value / total * 100) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME BY TYPE")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .tracking(2)

            if typeData.isEmpty {
                Text("No data yet")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(typeData, id: \.type) { data in
                        TypeBreakdownRow(
                            type: data.type,
                            minutes: data.minutes,
                            percentage: data.percentage
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct TypeBreakdownRow: View {
    let type: ItemType
    let minutes: Double
    let percentage: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
                .foregroundColor(typeColor)
                .frame(width: 16)

            Text(type.rawValue)
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.white)

            Spacer()

            Text(formatMinutes(minutes))
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(typeColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(width: 60, height: 6)

            Text("\(Int(percentage))%")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var typeColor: Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

struct TopItemsSection: View {
    let stats: PracticeStats
    @State private var showByTime = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TOP ITEMS")
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray)
                    .tracking(2)

                Spacer()

                // Toggle between time and count
                HStack(spacing: 0) {
                    Button {
                        showByTime = true
                    } label: {
                        Text("Time")
                            .font(.custom("SF Mono", size: 10))
                            .foregroundColor(showByTime ? .white : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showByTime ? Color.cyan.opacity(0.3) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showByTime = false
                    } label: {
                        Text("Count")
                            .font(.custom("SF Mono", size: 10))
                            .foregroundColor(!showByTime ? .white : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(!showByTime ? Color.cyan.opacity(0.3) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
            }

            if showByTime {
                if stats.topItemsByTime.isEmpty {
                    EmptyTopItemsView()
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(stats.topItemsByTime.prefix(5).enumerated()), id: \.element.item.id) { index, data in
                            TopItemRow(
                                rank: index + 1,
                                item: data.item,
                                value: formatMinutes(data.minutes)
                            )
                        }
                    }
                }
            } else {
                if stats.topItemsByCount.isEmpty {
                    EmptyTopItemsView()
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(stats.topItemsByCount.prefix(5).enumerated()), id: \.element.item.id) { index, data in
                            TopItemRow(
                                rank: index + 1,
                                item: data.item,
                                value: "\(data.count)x"
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

struct EmptyTopItemsView: View {
    var body: some View {
        Text("No data yet")
            .font(.custom("SF Mono", size: 12))
            .foregroundColor(.gray.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
}

struct TopItemRow: View {
    let rank: Int
    let item: LibraryItem
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            // Rank
            Text("\(rank)")
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.gray)
                .frame(width: 16)

            // Type icon
            Image(systemName: item.type?.icon ?? "questionmark")
                .font(.system(size: 11))
                .foregroundColor(typeColor(item.type))
                .frame(width: 14)

            // Name
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let artist = item.artist {
                    Text(artist)
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Value
            Text(value)
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.cyan)
        }
        .padding(.vertical, 4)
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

struct WeeklyTrendSection: View {
    let stats: PracticeStats

    private let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY TREND")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .tracking(2)

            if stats.weeklyTrend.isEmpty {
                Text("No data yet")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(stats.weeklyTrend, id: \.weekStart) { week in
                        WeeklyTrendBar(
                            weekStart: week.weekStart,
                            minutes: week.minutes,
                            maxMinutes: stats.weeklyTrend.map(\.minutes).max() ?? 1,
                            weekFormatter: weekFormatter
                        )
                    }
                }
                .frame(height: 100)
                .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct WeeklyTrendBar: View {
    let weekStart: Date
    let minutes: Double
    let maxMinutes: Double
    let weekFormatter: DateFormatter

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            // Minutes label
            if minutes > 0 {
                Text(formatMinutes(minutes))
                    .font(.custom("SF Mono", size: 8))
                    .foregroundColor(.gray)
            }

            // Bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(isCurrentWeek ? Color.cyan : Color.green)
                    .frame(height: barHeight)
            }
            .frame(height: 60)

            // Week label
            Text(weekFormatter.string(from: weekStart))
                .font(.custom("SF Mono", size: 9))
                .foregroundColor(isCurrentWeek ? .cyan : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var barHeight: CGFloat {
        guard maxMinutes > 0, minutes > 0 else { return 4 }
        return max(4, CGFloat(minutes / maxMinutes) * 60)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
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

// MARK: - Practice View

struct PracticeView: View {
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with exit button
            HStack {
                Button {
                    appState.endPractice()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                        Text("Exit")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                // Progress indicator
                Text(appState.practiceProgress)
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Spacer()

            // Main practice content
            if let item = appState.currentPracticeItem {
                VStack(spacing: 24) {
                    // Item type icon
                    Image(systemName: item.item.type?.icon ?? "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(practiceTypeColor(item.item.type))

                    // Item name
                    Text(item.item.name)
                        .font(.custom("SF Mono", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Artist (if song)
                    if let artist = item.item.artist {
                        Text(artist)
                            .font(.custom("SF Mono", size: 18))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                        .frame(height: 20)

                    // Timer display
                    VStack(spacing: 8) {
                        // Remaining time (or overtime indicator)
                        if appState.isPracticeOvertime {
                            Text("OVERTIME")
                                .font(.custom("SF Mono", size: 14))
                                .foregroundColor(.orange)
                                .tracking(2)

                            Text("+\(appState.practiceElapsedFormatted)")
                                .font(.custom("SF Mono", size: 72))
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        } else {
                            Text("REMAINING")
                                .font(.custom("SF Mono", size: 14))
                                .foregroundColor(.gray)
                                .tracking(2)

                            Text(appState.practiceRemainingFormatted)
                                .font(.custom("SF Mono", size: 72))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }

                        // Elapsed time (smaller)
                        HStack(spacing: 4) {
                            Text("Elapsed:")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                            Text(appState.practiceElapsedFormatted)
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.cyan)
                                .monospacedDigit()
                            Text("/")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("\(item.plannedMinutes):00")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                                .monospacedDigit()
                        }
                    }

                    // Timer status
                    if !appState.isTimerRunning {
                        Text("PAUSED")
                            .font(.custom("SF Mono", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                    }

                    Spacer()
                        .frame(height: 40)

                    // Control buttons
                    HStack(spacing: 16) {
                        // Pause/Resume button
                        Button {
                            appState.toggleTimer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: appState.isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16))
                                Text(appState.isTimerRunning ? "Pause" : "Resume")
                                    .font(.custom("SF Mono", size: 14))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)

                        // Next button (save and continue)
                        if appState.practiceItemIndex < appState.selectedItems.count - 1 {
                            Button {
                                Task {
                                    await appState.finishAndNextItem()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14))
                                    Text("Next")
                                        .font(.custom("SF Mono", size: 14))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.cyan.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Finish button (save and exit)
                        Button {
                            Task {
                                await appState.finishCurrentItem()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14))
                                Text("Finish")
                                    .font(.custom("SF Mono", size: 14))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        // Skip button (no save, just move on)
                        Button {
                            appState.skipToNextItem()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                Text("Skip")
                                    .font(.custom("SF Mono", size: 12))
                            }
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            // Footer with keyboard hints
            HStack(spacing: 16) {
                PracticeKeyHint(key: "space", action: "pause/resume")
                PracticeKeyHint(key: "enter", action: "finish & exit")
                PracticeKeyHint(key: "n", action: "save & next")
                PracticeKeyHint(key: "s", action: "skip")
                PracticeKeyHint(key: "esc", action: "exit")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.03, green: 0.03, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.space) {
            appState.toggleTimer()
            return .handled
        }
        .onKeyPress(.return) {
            Task {
                await appState.finishCurrentItem()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "nN")) { _ in
            Task {
                await appState.finishAndNextItem()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { _ in
            appState.skipToNextItem()
            return .handled
        }
    }

    private func practiceTypeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }
}

struct PracticeKeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.custom("SF Mono", size: 11))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - Helpers

/// Formats decimal minutes as MM:SS (e.g., 2.5 -> "2:30")
func formatMinutesAsTime(_ minutes: Double) -> String {
    let totalSeconds = Int(minutes * 60)
    let mins = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%d:%02d", mins, secs)
}

// MARK: - Preview

#Preview {
    ContentView(appState: AppState())
}
