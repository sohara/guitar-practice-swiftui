import SwiftUI

// MARK: - Sort Options

enum SortOption: String, CaseIterable {
    case name = "Name"
    case lastPracticed = "Last Practiced"
    case timesPracticed = "Times Practiced"
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Published State

    @Published var libraryState: LoadingState<[LibraryItem]> = .idle
    @Published var sessionsState: LoadingState<[PracticeSession]> = .idle
    @Published var selectedItems: [SelectedItem] = []
    @Published var currentSession: PracticeSession? = nil
    @Published var isLoadingSession: Bool = false
    @Published var isSavingSession: Bool = false
    @Published var sessionError: Error? = nil

    // Track items that were removed (need to delete from Notion)
    @Published var deletedLogIds: Set<String> = []

    @Published var needsAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false

    // MARK: - Search, Filter, Sort State

    @Published var searchText: String = ""
    @Published var typeFilter: ItemType? = nil  // nil = all types
    @Published var sortOption: SortOption = .name
    @Published var sortAscending: Bool = true
    @Published var focusedItemIndex: Int? = nil
    @Published var focusedSelectedIndex: Int? = nil
    @Published var focusedPanel: FocusedPanel = .library

    enum FocusedPanel {
        case library
        case selectedItems
    }

    // MARK: - Computed Properties

    var library: [LibraryItem] {
        libraryState.value ?? []
    }

    var filteredLibrary: [LibraryItem] {
        var items = library

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                item.name.lowercased().contains(query) ||
                (item.artist?.lowercased().contains(query) ?? false) ||
                item.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Filter by type
        if let typeFilter = typeFilter {
            items = items.filter { $0.type == typeFilter }
        }

        // Sort
        items.sort { a, b in
            let result: Bool
            switch sortOption {
            case .name:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .lastPracticed:
                let aDate = a.lastPracticed ?? .distantPast
                let bDate = b.lastPracticed ?? .distantPast
                result = aDate > bDate  // More recent first by default
            case .timesPracticed:
                result = a.timesPracticed > b.timesPracticed  // Higher count first by default
            }
            return sortAscending ? result : !result
        }

        return items
    }

    var sessions: [PracticeSession] {
        sessionsState.value ?? []
    }

    var isLoading: Bool {
        libraryState.isLoading || sessionsState.isLoading
    }

    var hasUnsavedChanges: Bool {
        !deletedLogIds.isEmpty || selectedItems.contains { $0.isDirty }
    }

    var totalPlannedMinutes: Int {
        selectedItems.reduce(0) { $0 + $1.plannedMinutes }
    }

    var totalActualMinutes: Double {
        selectedItems.reduce(0.0) { $0 + ($1.actualMinutes ?? 0) }
    }

    // MARK: - Private

    private var notionClient: NotionClient?

    // MARK: - Initialization

    init() {
        setupClient()
    }

    private func setupClient() {
        if let apiKey = try? KeychainService.getAPIKey() {
            notionClient = NotionClient(apiKey: apiKey)
            needsAPIKey = false
        } else {
            needsAPIKey = true
        }
    }

    // MARK: - API Key Management

    func setAPIKey(_ key: String) throws {
        try KeychainService.saveAPIKey(key)
        setupClient()
    }

    func clearAPIKey() throws {
        try KeychainService.deleteAPIKey()
        notionClient = nil
        needsAPIKey = true
        libraryState = .idle
        sessionsState = .idle
    }

    // MARK: - Data Fetching

    func loadData() async {
        guard let client = notionClient else {
            needsAPIKey = true
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchLibrary(client: client) }
            group.addTask { await self.fetchSessions(client: client) }
        }
    }

    func refresh() async {
        await loadData()
    }

    private func fetchLibrary(client: NotionClient) async {
        libraryState = .loading
        do {
            let items = try await client.fetchLibrary()
            libraryState = .loaded(items)
        } catch {
            libraryState = .error(error)
        }
    }

    private func fetchSessions(client: NotionClient) async {
        sessionsState = .loading
        do {
            let sessions = try await client.fetchSessions()
            sessionsState = .loaded(sessions)
        } catch {
            sessionsState = .error(error)
        }
    }

    // MARK: - Selection Management

    func toggleSelection(_ item: LibraryItem) {
        if let index = selectedItems.firstIndex(where: { $0.item.id == item.id }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(SelectedItem(item: item))
        }
    }

    func isSelected(_ item: LibraryItem) -> Bool {
        selectedItems.contains { $0.item.id == item.id }
    }

    func removeSelectedItem(at index: Int) {
        guard index < selectedItems.count else { return }
        let item = selectedItems[index]
        // Track for deletion if it exists in Notion
        if let logId = item.logId {
            deletedLogIds.insert(logId)
        }
        selectedItems.remove(at: index)
    }

    func updatePlannedTime(at index: Int, minutes: Int) {
        guard index < selectedItems.count else { return }
        selectedItems[index].plannedMinutes = max(1, minutes)
        selectedItems[index].isDirty = true
    }

    func moveSelectedItem(from source: IndexSet, to destination: Int) {
        selectedItems.move(fromOffsets: source, toOffset: destination)
        // Mark all items as dirty since order changed
        for i in selectedItems.indices {
            selectedItems[i].isDirty = true
        }
    }

    func clearSelection() {
        selectedItems.removeAll()
        deletedLogIds.removeAll()
        currentSession = nil
        sessionError = nil
    }

    // MARK: - Session Management

    func selectSession(_ session: PracticeSession?) async {
        guard let session = session else {
            clearSelection()
            return
        }

        guard let client = notionClient else { return }

        currentSession = session
        isLoadingSession = true
        sessionError = nil
        selectedItems.removeAll()
        deletedLogIds.removeAll()

        do {
            let logs = try await client.fetchLogs(forSession: session.id)

            // Convert logs to SelectedItems, matching with library items
            var items: [SelectedItem] = []
            for log in logs.sorted(by: { $0.order < $1.order }) {
                if let libraryItem = library.first(where: { $0.id == log.itemId }) {
                    items.append(SelectedItem(from: log, item: libraryItem))
                }
            }
            selectedItems = items
            isLoadingSession = false
        } catch {
            sessionError = error
            isLoadingSession = false
        }
    }

    func createNewSession() async -> PracticeSession? {
        guard let client = notionClient else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"
        let name = displayFormatter.string(from: Date())

        let newSession = NewPracticeSession(name: name, date: dateString)

        do {
            let session = try await client.createSession(newSession)
            // Refresh sessions list
            await fetchSessions(client: client)
            return session
        } catch {
            sessionError = error
            return nil
        }
    }

    func saveSession() async {
        guard let client = notionClient,
              let session = currentSession else { return }

        isSavingSession = true
        sessionError = nil

        do {
            // Delete removed items
            for logId in deletedLogIds {
                try await client.deleteLog(logId: logId)
            }
            deletedLogIds.removeAll()

            // Save new and updated items
            for (index, item) in selectedItems.enumerated() {
                if item.logId == nil {
                    // Create new log
                    let newLog = NewPracticeLog(
                        name: item.item.name,
                        itemId: item.item.id,
                        sessionId: session.id,
                        plannedMinutes: item.plannedMinutes,
                        order: index
                    )
                    let logId = try await client.createLog(newLog)
                    selectedItems[index].logId = logId
                    selectedItems[index].isDirty = false
                } else if item.isDirty {
                    // Update existing log
                    try await client.updateLog(
                        logId: item.logId!,
                        plannedMinutes: item.plannedMinutes,
                        actualMinutes: item.actualMinutes,
                        order: index
                    )
                    selectedItems[index].isDirty = false
                }
            }

            isSavingSession = false
        } catch {
            sessionError = error
            isSavingSession = false
        }
    }

    // MARK: - Panel Focus

    func toggleFocusedPanel() {
        switch focusedPanel {
        case .library:
            focusedPanel = .selectedItems
            // Initialize focus if needed
            if focusedSelectedIndex == nil && !selectedItems.isEmpty {
                focusedSelectedIndex = 0
            }
        case .selectedItems:
            focusedPanel = .library
            // Initialize focus if needed
            if focusedItemIndex == nil && !filteredLibrary.isEmpty {
                focusedItemIndex = 0
            }
        }
    }

    // MARK: - Keyboard Navigation

    func moveFocusUp() {
        switch focusedPanel {
        case .library:
            moveLibraryFocusUp()
        case .selectedItems:
            moveFocusedSelectedUp()
        }
    }

    func moveFocusDown() {
        switch focusedPanel {
        case .library:
            moveLibraryFocusDown()
        case .selectedItems:
            moveFocusedSelectedDown()
        }
    }

    private func moveLibraryFocusUp() {
        let items = filteredLibrary
        guard !items.isEmpty else { return }

        if let current = focusedItemIndex {
            focusedItemIndex = max(0, current - 1)
        } else {
            focusedItemIndex = items.count - 1
        }
    }

    private func moveLibraryFocusDown() {
        let items = filteredLibrary
        guard !items.isEmpty else { return }

        if let current = focusedItemIndex {
            focusedItemIndex = min(items.count - 1, current + 1)
        } else {
            focusedItemIndex = 0
        }
    }

    func toggleFocusedItem() {
        let items = filteredLibrary
        guard let index = focusedItemIndex, index < items.count else { return }
        toggleSelection(items[index])
    }

    var focusedItem: LibraryItem? {
        guard let index = focusedItemIndex else { return nil }
        let items = filteredLibrary
        guard index < items.count else { return nil }
        return items[index]
    }

    // MARK: - Selected Items Navigation

    func moveFocusedSelectedUp() {
        guard !selectedItems.isEmpty else { return }
        if let current = focusedSelectedIndex {
            focusedSelectedIndex = max(0, current - 1)
        } else {
            focusedSelectedIndex = selectedItems.count - 1
        }
    }

    func moveFocusedSelectedDown() {
        guard !selectedItems.isEmpty else { return }
        if let current = focusedSelectedIndex {
            focusedSelectedIndex = min(selectedItems.count - 1, current + 1)
        } else {
            focusedSelectedIndex = 0
        }
    }

    func adjustFocusedSelectedTime(delta: Int) {
        guard let index = focusedSelectedIndex, index < selectedItems.count else { return }
        updatePlannedTime(at: index, minutes: selectedItems[index].plannedMinutes + delta)
    }

    func removeFocusedSelected() {
        guard let index = focusedSelectedIndex, index < selectedItems.count else { return }
        removeSelectedItem(at: index)
        // Adjust focus after removal
        if selectedItems.isEmpty {
            focusedSelectedIndex = nil
        } else if index >= selectedItems.count {
            focusedSelectedIndex = selectedItems.count - 1
        }
    }
}
