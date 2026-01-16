import Foundation
import SwiftData

/// Service for caching Notion data locally using SwiftData
@MainActor
final class CacheService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Library Items

    func loadLibraryItems() -> [LibraryItem] {
        let descriptor = FetchDescriptor<CachedLibraryItem>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let cached = try modelContext.fetch(descriptor)
            return cached.map { $0.toLibraryItem() }
        } catch {
            print("Failed to load cached library items: \(error)")
            return []
        }
    }

    func saveLibraryItems(_ items: [LibraryItem]) {
        // Get existing cached items
        let descriptor = FetchDescriptor<CachedLibraryItem>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        // Track which IDs we've seen for deletion of stale items
        var seenIds = Set<String>()

        for item in items {
            seenIds.insert(item.id)

            if let cached = existingById[item.id] {
                // Update existing
                cached.update(from: item)
            } else {
                // Insert new
                let cached = CachedLibraryItem(
                    id: item.id,
                    name: item.name,
                    type: item.type,
                    artist: item.artist,
                    tags: item.tags,
                    lastPracticed: item.lastPracticed,
                    timesPracticed: item.timesPracticed
                )
                modelContext.insert(cached)
            }
        }

        // Delete items that no longer exist in Notion
        for cached in existing where !seenIds.contains(cached.id) {
            modelContext.delete(cached)
        }

        updateMetadata(key: "library")
        saveContext()
    }

    // MARK: - Practice Sessions

    func loadSessions() -> [PracticeSession] {
        let descriptor = FetchDescriptor<CachedPracticeSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            let cached = try modelContext.fetch(descriptor)
            return cached.map { $0.toPracticeSession() }
        } catch {
            print("Failed to load cached sessions: \(error)")
            return []
        }
    }

    func saveSessions(_ sessions: [PracticeSession]) {
        let descriptor = FetchDescriptor<CachedPracticeSession>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var seenIds = Set<String>()

        for session in sessions {
            seenIds.insert(session.id)

            if let cached = existingById[session.id] {
                cached.update(from: session)
            } else {
                let cached = CachedPracticeSession(
                    id: session.id,
                    name: session.name,
                    date: session.date,
                    goalMinutes: session.goalMinutes
                )
                modelContext.insert(cached)
            }
        }

        for cached in existing where !seenIds.contains(cached.id) {
            modelContext.delete(cached)
        }

        updateMetadata(key: "sessions")
        saveContext()
    }

    // MARK: - Practice Logs

    func loadLogs(forSession sessionId: String) -> [PracticeLog] {
        let descriptor = FetchDescriptor<CachedPracticeLog>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.order)]
        )
        do {
            let cached = try modelContext.fetch(descriptor)
            return cached.map { $0.toPracticeLog() }
        } catch {
            print("Failed to load cached logs: \(error)")
            return []
        }
    }

    /// Load all practice logs (for stats aggregation)
    func loadAllLogs() -> [PracticeLog] {
        let descriptor = FetchDescriptor<CachedPracticeLog>()
        do {
            let cached = try modelContext.fetch(descriptor)
            return cached.map { $0.toPracticeLog() }
        } catch {
            print("Failed to load all cached logs: \(error)")
            return []
        }
    }

    func saveLogs(_ logs: [PracticeLog], forSession sessionId: String) {
        // Get existing logs for this session
        let descriptor = FetchDescriptor<CachedPracticeLog>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var seenIds = Set<String>()

        for log in logs {
            seenIds.insert(log.id)

            if let cached = existingById[log.id] {
                cached.update(from: log)
            } else {
                let cached = CachedPracticeLog(
                    id: log.id,
                    name: log.name,
                    itemId: log.itemId,
                    sessionId: log.sessionId,
                    plannedMinutes: log.plannedMinutes,
                    actualMinutes: log.actualMinutes,
                    order: log.order,
                    notes: log.notes
                )
                modelContext.insert(cached)
            }
        }

        for cached in existing where !seenIds.contains(cached.id) {
            modelContext.delete(cached)
        }

        saveContext()
    }

    /// Update a single practice log in the cache (for real-time updates during practice)
    func updateLog(logId: String, plannedMinutes: Int, actualMinutes: Double?, order: Int, notes: String?) {
        let descriptor = FetchDescriptor<CachedPracticeLog>(
            predicate: #Predicate { $0.id == logId }
        )

        if let cached = try? modelContext.fetch(descriptor).first {
            cached.plannedMinutes = plannedMinutes
            cached.actualMinutes = actualMinutes
            cached.order = order
            cached.notes = notes
            saveContext()
        }
    }

    // MARK: - Metadata

    func lastUpdated(for key: String) -> Date? {
        let descriptor = FetchDescriptor<CacheMetadata>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first?.lastUpdated
    }

    private func updateMetadata(key: String) {
        let descriptor = FetchDescriptor<CacheMetadata>(
            predicate: #Predicate { $0.key == key }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastUpdated = Date()
        } else {
            let metadata = CacheMetadata(key: key)
            modelContext.insert(metadata)
        }
    }

    // MARK: - Helpers

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save cache: \(error)")
        }
    }

    /// Check if cache has data (for initial load decision)
    var hasLibraryCache: Bool {
        let descriptor = FetchDescriptor<CachedLibraryItem>()
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    var hasSessionsCache: Bool {
        let descriptor = FetchDescriptor<CachedPracticeSession>()
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }
}
