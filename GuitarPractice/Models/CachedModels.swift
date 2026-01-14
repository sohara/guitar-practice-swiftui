import Foundation
import SwiftData

// MARK: - Cached Library Item

@Model
final class CachedLibraryItem {
    @Attribute(.unique) var id: String
    var name: String
    var typeRaw: String?
    var artist: String?
    var tagsData: Data?  // JSON encoded [String]
    var lastPracticed: Date?
    var timesPracticed: Int

    init(
        id: String,
        name: String,
        type: ItemType?,
        artist: String?,
        tags: [String],
        lastPracticed: Date?,
        timesPracticed: Int
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type?.rawValue
        self.artist = artist
        self.tagsData = try? JSONEncoder().encode(tags)
        self.lastPracticed = lastPracticed
        self.timesPracticed = timesPracticed
    }

    var type: ItemType? {
        guard let raw = typeRaw else { return nil }
        return ItemType(rawValue: raw)
    }

    var tags: [String] {
        guard let data = tagsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func toLibraryItem() -> LibraryItem {
        LibraryItem(
            id: id,
            name: name,
            type: type,
            artist: artist,
            tags: tags,
            lastPracticed: lastPracticed,
            timesPracticed: timesPracticed
        )
    }

    func update(from item: LibraryItem) {
        name = item.name
        typeRaw = item.type?.rawValue
        artist = item.artist
        tagsData = try? JSONEncoder().encode(item.tags)
        lastPracticed = item.lastPracticed
        timesPracticed = item.timesPracticed
    }
}

// MARK: - Cached Practice Session

@Model
final class CachedPracticeSession {
    @Attribute(.unique) var id: String
    var name: String
    var date: Date

    init(id: String, name: String, date: Date) {
        self.id = id
        self.name = name
        self.date = date
    }

    func toPracticeSession() -> PracticeSession {
        PracticeSession(id: id, name: name, date: date)
    }

    func update(from session: PracticeSession) {
        name = session.name
        date = session.date
    }
}

// MARK: - Cached Practice Log

@Model
final class CachedPracticeLog {
    @Attribute(.unique) var id: String
    var name: String
    var itemId: String
    var sessionId: String
    var plannedMinutes: Int
    var actualMinutes: Double?
    var order: Int

    init(
        id: String,
        name: String,
        itemId: String,
        sessionId: String,
        plannedMinutes: Int,
        actualMinutes: Double?,
        order: Int
    ) {
        self.id = id
        self.name = name
        self.itemId = itemId
        self.sessionId = sessionId
        self.plannedMinutes = plannedMinutes
        self.actualMinutes = actualMinutes
        self.order = order
    }

    func toPracticeLog() -> PracticeLog {
        PracticeLog(
            id: id,
            name: name,
            itemId: itemId,
            sessionId: sessionId,
            plannedMinutes: plannedMinutes,
            actualMinutes: actualMinutes,
            order: order
        )
    }

    func update(from log: PracticeLog) {
        name = log.name
        itemId = log.itemId
        sessionId = log.sessionId
        plannedMinutes = log.plannedMinutes
        actualMinutes = log.actualMinutes
        order = log.order
    }
}

// MARK: - Cache Metadata

@Model
final class CacheMetadata {
    @Attribute(.unique) var key: String
    var lastUpdated: Date

    init(key: String, lastUpdated: Date = Date()) {
        self.key = key
        self.lastUpdated = lastUpdated
    }
}
