import SwiftUI

@MainActor
class AppState: ObservableObject {
    // MARK: - Published State

    @Published var libraryState: LoadingState<[LibraryItem]> = .idle
    @Published var sessionsState: LoadingState<[PracticeSession]> = .idle
    @Published var selectedItems: [SelectedItem] = []
    @Published var currentSession: PracticeSession? = nil

    @Published var needsAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false

    // MARK: - Computed Properties

    var library: [LibraryItem] {
        libraryState.value ?? []
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
}
