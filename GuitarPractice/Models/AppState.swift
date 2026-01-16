import SwiftUI
import SwiftData
import AppKit
import UserNotifications

// MARK: - Sort Options

enum SortOption: String, CaseIterable {
    case name = "Name"
    case lastPracticed = "Last Practiced"
    case timesPracticed = "Times Practiced"
}

// MARK: - Session View Mode

enum SessionViewMode {
    case viewing  // Read-only, for past sessions
    case editing  // Full edit capabilities
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
    @Published var isRefreshing: Bool = false
    @Published var sessionError: Error? = nil

    // Track items that were removed (need to delete from Notion)
    @Published var deletedLogIds: Set<String> = []

    @Published var needsAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var isCalendarPresented: Bool = false
    @Published var isShowingStats: Bool = false
    @Published var practiceStats: PracticeStats?

    // Calendar navigation state
    @Published var selectedDate: Date = Date()  // Date selected in calendar
    @Published var sessionViewMode: SessionViewMode = .editing
    @Published var displayedMonth: Date = Date()  // Month shown in calendar

    // MARK: - Practice State

    @Published var isPracticing: Bool = false
    @Published var practiceItemIndex: Int = 0
    @Published var practiceElapsedSeconds: Double = 0
    @Published var isTimerRunning: Bool = false
    private var timerTask: Task<Void, Never>?
    private var hasTriggeredOvertimeAlert: Bool = false

    // Notes history for current item (loaded on practice start/switch)
    @Published var currentItemNotesHistory: [HistoricalNote] = []
    @Published var isLoadingNotesHistory: Bool = false

    // MARK: - Search, Filter, Sort State

    @Published var searchText: String = ""
    @Published var typeFilter: ItemType? = nil  // nil = all types
    @Published var showRecentOnly: Bool = false  // Show only items practiced in last 7 days
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

        // Filter by recent (practiced in last 7 days)
        if showRecentOnly {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            items = items.filter { item in
                guard let lastPracticed = item.lastPracticed else { return false }
                return lastPracticed >= sevenDaysAgo
            }
        }

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

    var currentSessionGoal: Int {
        currentSession?.goalMinutes ?? Config.Defaults.dailyGoalMinutes
    }

    var goalProgress: Double {
        guard currentSessionGoal > 0 else { return 0 }
        return min(1.0, totalActualMinutes / Double(currentSessionGoal))
    }

    var isGoalMet: Bool {
        totalActualMinutes >= Double(currentSessionGoal)
    }

    /// Percentage of sessions where actual time met the goal (0-100)
    var goalAchievementRate: Int {
        guard let cache = cacheService else { return 0 }

        var metGoalCount = 0
        var totalWithGoal = 0

        for session in sessions {
            guard let goal = session.goalMinutes, goal > 0 else { continue }
            totalWithGoal += 1

            let logs = cache.loadLogs(forSession: session.id)
            let actualMinutes = logs.compactMap(\.actualMinutes).reduce(0, +)
            if actualMinutes >= Double(goal) {
                metGoalCount += 1
            }
        }

        guard totalWithGoal > 0 else { return 0 }
        return Int(Double(metGoalCount) / Double(totalWithGoal) * 100)
    }

    var currentPracticeItem: SelectedItem? {
        guard isPracticing, practiceItemIndex < selectedItems.count else { return nil }
        return selectedItems[practiceItemIndex]
    }

    var practiceProgress: String {
        "\(practiceItemIndex + 1) of \(selectedItems.count)"
    }

    var practiceElapsedFormatted: String {
        let totalSeconds = Int(practiceElapsedSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var practiceRemainingSeconds: Double {
        guard let item = currentPracticeItem else { return 0 }
        let plannedSeconds = Double(item.plannedMinutes * 60)
        return max(0, plannedSeconds - practiceElapsedSeconds)
    }

    var practiceRemainingFormatted: String {
        let totalSeconds = Int(practiceRemainingSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isPracticeOvertime: Bool {
        practiceRemainingSeconds <= 0
    }

    // MARK: - Private

    private var notionClient: NotionClient?
    private var cacheService: CacheService?
    private let statsService = StatsService()

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

    // MARK: - Cache Setup

    func setupCache(modelContext: ModelContext) {
        guard cacheService == nil else { return }
        cacheService = CacheService(modelContext: modelContext)
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

    /// Load data only if not already loaded (for initial app launch)
    /// Uses cache-first strategy: show cached data instantly, then refresh from Notion
    func loadDataIfNeeded() async {
        // Skip if we already have data loaded
        if case .loaded = libraryState, case .loaded = sessionsState {
            return
        }

        // Try to load from cache first for instant display
        if let cache = cacheService {
            let cachedLibrary = cache.loadLibraryItems()
            let cachedSessions = cache.loadSessions()

            if !cachedLibrary.isEmpty {
                libraryState = .loaded(cachedLibrary)
            }
            if !cachedSessions.isEmpty {
                sessionsState = .loaded(cachedSessions)
            }

            // Auto-select today's session from cache
            if currentSession == nil && !cachedSessions.isEmpty {
                await selectTodaysSessionIfExists()
            }
        }

        // Then refresh from Notion in background
        await loadData()

        // Auto-select today's session if not already selected
        if currentSession == nil {
            await selectTodaysSessionIfExists()
        }
    }

    /// Select today's date (and session if one exists)
    private func selectTodaysSessionIfExists() async {
        await selectDate(Date())
    }

    func refresh() async {
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }

    private func fetchLibrary(client: NotionClient) async {
        // Only show loading if we don't have cached data
        if case .loaded = libraryState {
            // Already showing cached data, fetch silently
        } else {
            libraryState = .loading
        }

        do {
            let items = try await client.fetchLibrary()
            libraryState = .loaded(items)

            // Save to cache
            cacheService?.saveLibraryItems(items)
        } catch {
            // Only set error if we don't have cached data to show
            if case .loaded = libraryState {
                // Keep showing cached data, log error
                print("Failed to refresh library from Notion: \(error)")
            } else {
                libraryState = .error(error)
            }
        }
    }

    private func fetchSessions(client: NotionClient) async {
        // Only show loading if we don't have cached data
        if case .loaded = sessionsState {
            // Already showing cached data, fetch silently
        } else {
            sessionsState = .loading
        }

        do {
            let sessions = try await client.fetchSessions()
            sessionsState = .loaded(sessions)

            // Save to cache
            cacheService?.saveSessions(sessions)
        } catch {
            // Only set error if we don't have cached data to show
            if case .loaded = sessionsState {
                // Keep showing cached data, log error
                print("Failed to refresh sessions from Notion: \(error)")
            } else {
                sessionsState = .error(error)
            }
        }
    }

    // MARK: - Statistics

    func refreshStats() {
        guard let cache = cacheService else { return }

        let allLogs = cache.loadAllLogs()
        practiceStats = statsService.computeStats(
            sessions: sessions,
            logs: allLogs,
            library: library
        )
    }

    func toggleStatsView() {
        isShowingStats.toggle()
        if isShowingStats && practiceStats == nil {
            refreshStats()
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

    func updateNotes(at index: Int, notes: String?) {
        guard index < selectedItems.count else { return }
        selectedItems[index].notes = notes
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

        currentSession = session
        sessionError = nil
        selectedItems.removeAll()
        deletedLogIds.removeAll()

        // Try to load from cache first for instant display
        if let cache = cacheService {
            let cachedLogs = cache.loadLogs(forSession: session.id)
            if !cachedLogs.isEmpty {
                var items: [SelectedItem] = []
                for log in cachedLogs.sorted(by: { $0.order < $1.order }) {
                    if let libraryItem = library.first(where: { $0.id == log.itemId }) {
                        items.append(SelectedItem(from: log, item: libraryItem))
                    }
                }
                selectedItems = items
            }
        }

        // Show loading only if we don't have cached data
        if selectedItems.isEmpty {
            isLoadingSession = true
        }

        // Then fetch from Notion
        guard let client = notionClient else {
            isLoadingSession = false
            return
        }

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

            // Save to cache
            cacheService?.saveLogs(logs, forSession: session.id)
        } catch {
            // Only set error if we don't have cached data
            if selectedItems.isEmpty {
                sessionError = error
            } else {
                print("Failed to refresh session logs from Notion: \(error)")
            }
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
                        order: index,
                        notes: item.notes
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
                        order: index,
                        notes: item.notes
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

    // MARK: - Calendar Navigation

    /// Select a date in the calendar and load any associated session
    func selectDate(_ date: Date) async {
        let calendar = Calendar.current
        selectedDate = date

        // Find session for this date
        let startOfDay = calendar.startOfDay(for: date)
        if let session = sessions.first(where: { calendar.startOfDay(for: $0.date) == startOfDay }) {
            // Determine view mode based on whether date is today or past
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()
            sessionViewMode = (isToday || isFuture) ? .editing : .viewing

            await selectSession(session)
        } else {
            // No session for this date
            currentSession = nil
            selectedItems.removeAll()
            deletedLogIds.removeAll()

            // For today or future dates, go to edit mode (ready to create)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()
            sessionViewMode = (isToday || isFuture) ? .editing : .viewing
        }
    }

    /// Switch from viewing mode to editing mode (for past sessions)
    func switchToEditMode() {
        sessionViewMode = .editing
    }

    /// Jump to today's date in the calendar
    func jumpToToday() async {
        displayedMonth = Date()
        await selectDate(Date())
    }

    /// Get session for a specific date (if exists)
    func sessionForDate(_ date: Date) -> PracticeSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return sessions.first { calendar.startOfDay(for: $0.date) == startOfDay }
    }

    /// Check if selected date is today
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Check if selected date is in the past
    var isSelectedDatePast: Bool {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfSelected = calendar.startOfDay(for: selectedDate)
        return startOfSelected < startOfToday
    }

    /// Create a new session for the selected date
    func createSessionForSelectedDate() async -> PracticeSession? {
        guard let client = notionClient else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"
        let name = displayFormatter.string(from: selectedDate)

        let newSession = NewPracticeSession(name: name, date: dateString)

        do {
            let session = try await client.createSession(newSession)
            // Refresh sessions list
            await fetchSessions(client: client)
            // Select the new session
            await selectDate(selectedDate)
            return session
        } catch {
            sessionError = error
            return nil
        }
    }

    /// Update the goal for the current session
    func updateSessionGoal(_ newGoal: Int) async {
        guard let session = currentSession, let client = notionClient else { return }

        do {
            try await client.updateSessionGoal(sessionId: session.id, goalMinutes: newGoal)

            // Update local state
            let updatedSession = PracticeSession(
                id: session.id,
                name: session.name,
                date: session.date,
                goalMinutes: newGoal
            )
            currentSession = updatedSession

            // Update in sessions list
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                var updatedSessions = sessions
                updatedSessions[index] = updatedSession
                sessionsState = .loaded(updatedSessions)
            }

            // Update cache
            cacheService?.saveSessions(sessions)
        } catch {
            sessionError = error
        }
    }

    // MARK: - Calendar Day Summaries

    /// Compute day summaries for sessions in a given month
    func daySummaries(for month: Date) -> [Date: DaySummary] {
        guard let cache = cacheService else { return [:] }

        let calendar = Calendar.current
        var summaries: [Date: DaySummary] = [:]

        // Get sessions for this month
        let monthSessions = sessions.filter { session in
            calendar.isDate(session.date, equalTo: month, toGranularity: .month)
        }

        // Compute summary for each session
        for session in monthSessions {
            let startOfDay = calendar.startOfDay(for: session.date)
            let logs = cache.loadLogs(forSession: session.id)

            let itemCount = logs.count
            let plannedMinutes = logs.reduce(0) { $0 + $1.plannedMinutes }
            let actualMinutes = logs.reduce(0.0) { $0 + ($1.actualMinutes ?? 0) }

            summaries[startOfDay] = DaySummary(
                date: startOfDay,
                itemCount: itemCount,
                plannedMinutes: plannedMinutes,
                actualMinutes: actualMinutes
            )
        }

        return summaries
    }

    /// Get summary for a specific date (convenience method)
    func daySummary(for date: Date) -> DaySummary? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let summaries = daySummaries(for: date)
        return summaries[startOfDay]
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

    func clampFocusedItemIndex() {
        let count = filteredLibrary.count
        if let index = focusedItemIndex, index >= count {
            focusedItemIndex = count > 0 ? count - 1 : nil
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

    func pageUp() {
        let items = filteredLibrary
        guard !items.isEmpty else { return }
        let pageSize = 10

        if let current = focusedItemIndex {
            focusedItemIndex = max(0, current - pageSize)
        } else {
            focusedItemIndex = 0
        }
    }

    func pageDown() {
        let items = filteredLibrary
        guard !items.isEmpty else { return }
        let pageSize = 10

        if let current = focusedItemIndex {
            focusedItemIndex = min(items.count - 1, current + pageSize)
        } else {
            focusedItemIndex = min(items.count - 1, pageSize - 1)
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

    func openFocusedItemInNotion() {
        // Determine which item to open based on focused panel
        let itemId: String?
        switch focusedPanel {
        case .library:
            itemId = focusedItem?.id
        case .selectedItems:
            if let index = focusedSelectedIndex, index < selectedItems.count {
                itemId = selectedItems[index].item.id
            } else {
                itemId = nil
            }
        }

        guard let id = itemId else { return }

        // Remove dashes from UUID for Notion URL
        let cleanId = id.replacingOccurrences(of: "-", with: "")
        // Use notion:// protocol to open in Notion app instead of browser
        if let url = URL(string: "notion://notion.so/\(cleanId)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCurrentPracticeItemInNotion() {
        guard let item = currentPracticeItem?.item else { return }

        let cleanId = item.id.replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "notion://notion.so/\(cleanId)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openItemInNotion(id: String) {
        let cleanId = id.replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "notion://notion.so/\(cleanId)") {
            NSWorkspace.shared.open(url)
        }
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

    // MARK: - Notes History

    /// Fetch notes history for the current practice item
    func fetchNotesHistoryForCurrentItem() async {
        guard let item = currentPracticeItem,
              let client = notionClient else {
            currentItemNotesHistory = []
            return
        }

        isLoadingNotesHistory = true
        currentItemNotesHistory = []

        do {
            let logs = try await client.fetchLogsForItem(itemId: item.item.id)

            // Build historical notes list:
            // - Only include logs with non-empty notes
            // - Exclude current session's log
            // - Join with sessions to get dates
            var notes: [HistoricalNote] = []
            let currentSessionId = currentSession?.id

            for log in logs {
                // Skip if no notes
                guard let logNotes = log.notes, !logNotes.isEmpty else { continue }

                // Skip if this is the current session's log
                if let currentId = currentSessionId, log.sessionId == currentId {
                    continue
                }

                // Find session date
                if let session = sessions.first(where: { $0.id == log.sessionId }) {
                    notes.append(HistoricalNote(
                        id: log.id,
                        date: session.date,
                        notes: logNotes
                    ))
                }
            }

            // Sort by date descending (most recent first)
            notes.sort { $0.date > $1.date }

            currentItemNotesHistory = notes
        } catch {
            print("Failed to fetch notes history: \(error)")
            currentItemNotesHistory = []
        }

        isLoadingNotesHistory = false
    }

    // MARK: - Practice Mode

    func startPractice() {
        guard !selectedItems.isEmpty else { return }

        isPracticing = true

        // Start from focused item if one is selected
        if let focused = focusedSelectedIndex {
            practiceItemIndex = focused
        } else {
            // Otherwise, find the first item that hasn't been played yet
            practiceItemIndex = selectedItems.firstIndex { $0.actualMinutes == nil } ?? 0
        }

        hasTriggeredOvertimeAlert = false

        // Resume from previous actual time if exists
        if let existingTime = selectedItems[practiceItemIndex].actualMinutes {
            practiceElapsedSeconds = existingTime * 60
            // If resuming in overtime, don't re-trigger alert
            if isPracticeOvertime {
                hasTriggeredOvertimeAlert = true
            }
        } else {
            practiceElapsedSeconds = 0
        }

        // Fetch notes history for current item
        Task {
            await fetchNotesHistoryForCurrentItem()
        }

        resumeTimer()
    }

    func pauseTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func resumeTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self = self else { return }

                    let wasNotOvertime = !self.isPracticeOvertime
                    self.practiceElapsedSeconds += 0.1
                    let isNowOvertime = self.isPracticeOvertime

                    // Trigger alert when crossing into overtime
                    if wasNotOvertime && isNowOvertime && !self.hasTriggeredOvertimeAlert {
                        self.hasTriggeredOvertimeAlert = true
                        self.triggerOvertimeAlert()
                    }
                }
            }
        }
    }

    private func triggerOvertimeAlert() {
        // Play system sound
        NSSound.beep()

        // Also play a more distinct sound if available
        if let sound = NSSound(named: "Glass") {
            sound.play()
        }

        // Show notification
        let content = UNMutableNotificationContent()
        content.title = "Practice Time Complete"
        if let item = currentPracticeItem {
            content.body = "\(item.item.name) - Time's up!"
        } else {
            content.body = "Your practice time has elapsed."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }

    func toggleTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            resumeTimer()
        }
    }

    func finishCurrentItem() async {
        guard practiceItemIndex < selectedItems.count else { return }

        // Save actual time (convert seconds to minutes)
        let actualMinutes = practiceElapsedSeconds / 60.0
        selectedItems[practiceItemIndex].actualMinutes = actualMinutes

        // Save to Notion immediately
        await saveCurrentItemToNotion()

        // Exit practice mode
        endPractice()
    }

    func finishAndNextItem() async {
        guard practiceItemIndex < selectedItems.count else { return }

        // Save actual time (convert seconds to minutes)
        let actualMinutes = practiceElapsedSeconds / 60.0
        selectedItems[practiceItemIndex].actualMinutes = actualMinutes

        // Save to Notion immediately
        await saveCurrentItemToNotion()

        // Move to next item or end practice
        if practiceItemIndex < selectedItems.count - 1 {
            moveToNextPracticeItem()
        } else {
            endPractice()
        }
    }

    private func saveCurrentItemToNotion() async {
        guard let client = notionClient else { return }
        let index = practiceItemIndex
        guard index < selectedItems.count else { return }

        let item = selectedItems[index]

        do {
            if let logId = item.logId {
                // Update existing log
                try await client.updateLog(
                    logId: logId,
                    plannedMinutes: item.plannedMinutes,
                    actualMinutes: item.actualMinutes,
                    order: index,
                    notes: item.notes
                )
                selectedItems[index].isDirty = false

                // Update local cache so calendar view reflects changes immediately
                cacheService?.updateLog(
                    logId: logId,
                    plannedMinutes: item.plannedMinutes,
                    actualMinutes: item.actualMinutes,
                    order: index,
                    notes: item.notes
                )
            }
            // If no logId, the item hasn't been saved to session yet
            // User will need to save the session first
        } catch {
            sessionError = error
        }
    }

    func skipToNextItem() {
        if practiceItemIndex < selectedItems.count - 1 {
            moveToNextPracticeItem()
        } else {
            endPractice()
        }
    }

    private func moveToNextPracticeItem() {
        practiceItemIndex += 1
        hasTriggeredOvertimeAlert = false

        // Resume from previous actual time if exists
        if let existingTime = selectedItems[practiceItemIndex].actualMinutes {
            practiceElapsedSeconds = existingTime * 60
            // If resuming in overtime, don't re-trigger alert
            if isPracticeOvertime {
                hasTriggeredOvertimeAlert = true
            }
        } else {
            practiceElapsedSeconds = 0
        }

        // Fetch notes history for new item
        Task {
            await fetchNotesHistoryForCurrentItem()
        }

        // Keep timer running
        if !isTimerRunning {
            resumeTimer()
        }
    }

    func endPractice() {
        pauseTimer()
        isPracticing = false
        practiceItemIndex = 0
        practiceElapsedSeconds = 0
        currentItemNotesHistory = []
    }
}
