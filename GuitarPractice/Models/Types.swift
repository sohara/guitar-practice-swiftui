import Foundation

// MARK: - Item Types

enum ItemType: String, CaseIterable, Codable {
    case song = "Song"
    case exercise = "Exercise"
    case courseLesson = "Course Lesson"

    var icon: String {
        switch self {
        case .song: return "music.note"
        case .exercise: return "figure.walk"
        case .courseLesson: return "book"
        }
    }
}

// MARK: - Practice Library Item

struct LibraryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let type: ItemType?
    let artist: String?
    let tags: [String]
    let lastPracticed: Date?
    let timesPracticed: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LibraryItem, rhs: LibraryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Practice Session

struct PracticeSession: Identifiable {
    let id: String
    let name: String
    let date: Date
}

// MARK: - Practice Log (junction table entry)

struct PracticeLog: Identifiable {
    let id: String
    let name: String
    let itemId: String
    let sessionId: String
    let plannedMinutes: Int
    let actualMinutes: Double?
    let order: Int
}

// MARK: - Selected Item (UI state)

struct SelectedItem: Identifiable {
    let id: String  // logId if saved, otherwise generated UUID
    let item: LibraryItem
    var plannedMinutes: Int
    var actualMinutes: Double?
    var logId: String?  // nil if not yet saved to Notion
    var isDirty: Bool = false  // Track if needs sync

    init(item: LibraryItem, plannedMinutes: Int = 5) {
        self.id = UUID().uuidString
        self.item = item
        self.plannedMinutes = plannedMinutes
        self.actualMinutes = nil
        self.logId = nil
        self.isDirty = true
    }

    init(from log: PracticeLog, item: LibraryItem) {
        self.id = log.id
        self.item = item
        self.plannedMinutes = log.plannedMinutes
        self.actualMinutes = log.actualMinutes
        self.logId = log.id
        self.isDirty = false
    }
}

// MARK: - New Entry Types (for creation)

struct NewPracticeSession {
    let name: String
    let date: String  // ISO date: YYYY-MM-DD
}

struct NewPracticeLog {
    let name: String
    let itemId: String
    let sessionId: String
    let plannedMinutes: Int
    let order: Int
}

// MARK: - App State

enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var error: Error? {
        if case .error(let e) = self { return e }
        return nil
    }
}
