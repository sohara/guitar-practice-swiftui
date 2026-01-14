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
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
        } detail: {
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
            .navigationSplitViewColumnWidth(min: 280, ideal: 350)
        }
        .navigationSplitViewStyle(.balanced)
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
