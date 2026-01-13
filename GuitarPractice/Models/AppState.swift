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

    @Published var needsAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false

    // MARK: - Search, Filter, Sort State

    @Published var searchText: String = ""
    @Published var typeFilter: ItemType? = nil  // nil = all types
    @Published var sortOption: SortOption = .name
    @Published var sortAscending: Bool = true
    @Published var focusedItemIndex: Int? = nil

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
        selectedItems.remove(at: index)
    }

    func updatePlannedTime(at index: Int, minutes: Int) {
        guard index < selectedItems.count else { return }
        selectedItems[index].plannedMinutes = max(1, minutes)
        selectedItems[index].isDirty = true
    }

    func clearSelection() {
        selectedItems.removeAll()
        currentSession = nil
    }

    // MARK: - Keyboard Navigation

    func moveFocusUp() {
        let items = filteredLibrary
        guard !items.isEmpty else { return }

        if let current = focusedItemIndex {
            focusedItemIndex = max(0, current - 1)
        } else {
            focusedItemIndex = items.count - 1
        }
    }

    func moveFocusDown() {
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
}
