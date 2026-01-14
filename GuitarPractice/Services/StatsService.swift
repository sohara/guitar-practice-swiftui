import Foundation

// MARK: - Practice Statistics

struct PracticeStats {
    // Overview
    let totalPracticeMinutes: Double
    let totalSessions: Int
    let totalItemsPracticed: Int
    let averageSessionMinutes: Double

    // Streaks
    let currentStreak: Int
    let longestStreak: Int

    // Time period summaries
    let thisWeekMinutes: Double
    let thisMonthMinutes: Double
    let last30DaysMinutes: Double

    // Most practiced items
    let topItemsByTime: [(item: LibraryItem, minutes: Double)]
    let topItemsByCount: [(item: LibraryItem, count: Int)]

    // Type breakdown
    let minutesByType: [ItemType: Double]

    // Weekly trend (last 8 weeks)
    let weeklyTrend: [(weekStart: Date, minutes: Double)]

    // Recent activity (last 7 days)
    let recentDays: [(date: Date, minutes: Double, itemCount: Int)]
}

// MARK: - Stats Service

@MainActor
final class StatsService {
    private let calendar = Calendar.current

    /// Compute comprehensive practice statistics
    func computeStats(
        sessions: [PracticeSession],
        logs: [PracticeLog],
        library: [LibraryItem]
    ) -> PracticeStats {
        let libraryById = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })

        // Total practice time
        let totalMinutes = logs.compactMap(\.actualMinutes).reduce(0, +)

        // Average session time
        let sessionMinutes = computeSessionMinutes(sessions: sessions, logs: logs)
        let avgSessionMinutes = sessions.isEmpty ? 0 : sessionMinutes.values.reduce(0, +) / Double(sessions.count)

        // Unique items practiced
        let uniqueItems = Set(logs.map(\.itemId))

        // Streaks
        let (currentStreak, longestStreak) = computeStreaks(sessions: sessions)

        // Time periods
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let thisWeekMinutes = computeMinutesInRange(
            logs: logs,
            sessions: sessions,
            from: startOfWeek,
            to: now
        )
        let thisMonthMinutes = computeMinutesInRange(
            logs: logs,
            sessions: sessions,
            from: startOfMonth,
            to: now
        )
        let last30DaysMinutes = computeMinutesInRange(
            logs: logs,
            sessions: sessions,
            from: thirtyDaysAgo,
            to: now
        )

        // Top items by time
        let topByTime = computeTopItemsByTime(logs: logs, libraryById: libraryById)

        // Top items by count
        let topByCount = computeTopItemsByCount(logs: logs, libraryById: libraryById)

        // Minutes by type
        let minutesByType = computeMinutesByType(logs: logs, libraryById: libraryById)

        // Weekly trend
        let weeklyTrend = computeWeeklyTrend(sessions: sessions, logs: logs)

        // Recent days
        let recentDays = computeRecentDays(sessions: sessions, logs: logs)

        return PracticeStats(
            totalPracticeMinutes: totalMinutes,
            totalSessions: sessions.count,
            totalItemsPracticed: uniqueItems.count,
            averageSessionMinutes: avgSessionMinutes,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            thisWeekMinutes: thisWeekMinutes,
            thisMonthMinutes: thisMonthMinutes,
            last30DaysMinutes: last30DaysMinutes,
            topItemsByTime: topByTime,
            topItemsByCount: topByCount,
            minutesByType: minutesByType,
            weeklyTrend: weeklyTrend,
            recentDays: recentDays
        )
    }

    // MARK: - Private Helpers

    private func computeSessionMinutes(sessions: [PracticeSession], logs: [PracticeLog]) -> [String: Double] {
        var result: [String: Double] = [:]
        for session in sessions {
            let sessionLogs = logs.filter { $0.sessionId == session.id }
            let minutes = sessionLogs.compactMap(\.actualMinutes).reduce(0, +)
            result[session.id] = minutes
        }
        return result
    }

    private func computeStreaks(sessions: [PracticeSession]) -> (current: Int, longest: Int) {
        guard !sessions.isEmpty else { return (0, 0) }

        let sortedDates = sessions
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)
        let uniqueDates = Array(Set(sortedDates)).sorted(by: >)

        guard !uniqueDates.isEmpty else { return (0, 0) }

        // Current streak
        var currentStreak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // If no session today, check if yesterday starts the streak
        if !uniqueDates.contains(checkDate) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if uniqueDates.contains(yesterday) {
                checkDate = yesterday
            } else {
                // No recent streak
                currentStreak = 0
            }
        }

        if uniqueDates.contains(checkDate) {
            currentStreak = 1
            var prevDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            while uniqueDates.contains(prevDate) {
                currentStreak += 1
                prevDate = calendar.date(byAdding: .day, value: -1, to: prevDate)!
            }
        }

        // Longest streak
        var longestStreak = 0
        var streak = 1
        for i in 0..<(uniqueDates.count - 1) {
            let current = uniqueDates[i]
            let next = uniqueDates[i + 1]
            let daysDiff = calendar.dateComponents([.day], from: next, to: current).day ?? 0

            if daysDiff == 1 {
                streak += 1
            } else {
                longestStreak = max(longestStreak, streak)
                streak = 1
            }
        }
        longestStreak = max(longestStreak, streak)

        return (currentStreak, longestStreak)
    }

    private func computeMinutesInRange(
        logs: [PracticeLog],
        sessions: [PracticeSession],
        from startDate: Date,
        to endDate: Date
    ) -> Double {
        let sessionIdsInRange = Set(sessions.filter { session in
            session.date >= startDate && session.date <= endDate
        }.map(\.id))

        return logs
            .filter { sessionIdsInRange.contains($0.sessionId) }
            .compactMap(\.actualMinutes)
            .reduce(0, +)
    }

    private func computeTopItemsByTime(
        logs: [PracticeLog],
        libraryById: [String: LibraryItem]
    ) -> [(item: LibraryItem, minutes: Double)] {
        var minutesByItem: [String: Double] = [:]
        for log in logs {
            if let actual = log.actualMinutes {
                minutesByItem[log.itemId, default: 0] += actual
            }
        }

        return minutesByItem
            .sorted { $0.value > $1.value }
            .prefix(10)
            .compactMap { itemId, minutes in
                guard let item = libraryById[itemId] else { return nil }
                return (item: item, minutes: minutes)
            }
    }

    private func computeTopItemsByCount(
        logs: [PracticeLog],
        libraryById: [String: LibraryItem]
    ) -> [(item: LibraryItem, count: Int)] {
        var countByItem: [String: Int] = [:]
        for log in logs where log.actualMinutes != nil && log.actualMinutes! > 0 {
            countByItem[log.itemId, default: 0] += 1
        }

        return countByItem
            .sorted { $0.value > $1.value }
            .prefix(10)
            .compactMap { itemId, count in
                guard let item = libraryById[itemId] else { return nil }
                return (item: item, count: count)
            }
    }

    private func computeMinutesByType(
        logs: [PracticeLog],
        libraryById: [String: LibraryItem]
    ) -> [ItemType: Double] {
        var result: [ItemType: Double] = [:]
        for log in logs {
            if let actual = log.actualMinutes,
               let item = libraryById[log.itemId],
               let type = item.type {
                result[type, default: 0] += actual
            }
        }
        return result
    }

    private func computeWeeklyTrend(
        sessions: [PracticeSession],
        logs: [PracticeLog]
    ) -> [(weekStart: Date, minutes: Double)] {
        let now = Date()
        var result: [(weekStart: Date, minutes: Double)] = []

        for weekOffset in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
            else { continue }

            let minutes = computeMinutesInRange(
                logs: logs,
                sessions: sessions,
                from: weekInterval.start,
                to: weekInterval.end
            )
            result.append((weekStart: weekInterval.start, minutes: minutes))
        }

        return result
    }

    private func computeRecentDays(
        sessions: [PracticeSession],
        logs: [PracticeLog]
    ) -> [(date: Date, minutes: Double, itemCount: Int)] {
        let now = Date()
        var result: [(date: Date, minutes: Double, itemCount: Int)] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            let sessionsOnDay = sessions.filter {
                calendar.isDate($0.date, inSameDayAs: dayStart)
            }
            let sessionIds = Set(sessionsOnDay.map(\.id))
            let dayLogs = logs.filter { sessionIds.contains($0.sessionId) }

            let minutes = dayLogs.compactMap(\.actualMinutes).reduce(0, +)
            let itemCount = dayLogs.filter { $0.actualMinutes != nil && $0.actualMinutes! > 0 }.count

            result.append((date: dayStart, minutes: minutes, itemCount: itemCount))
        }

        return result
    }
}
