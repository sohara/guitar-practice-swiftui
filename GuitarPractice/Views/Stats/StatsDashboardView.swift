import SwiftUI

struct StatsDashboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let stats = appState.practiceStats {
                    // Overview cards
                    StatsOverviewSection(stats: stats)

                    // Goal achievement
                    GoalAchievementSection(stats: stats)

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
            // Always refresh stats when view appears to show latest data
            appState.refreshStats()
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

struct GoalAchievementSection: View {
    let stats: PracticeStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOAL ACHIEVEMENT")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
                .tracking(2)

            // This Month vs All Time
            HStack(spacing: 16) {
                GoalRateCard(
                    title: "This Month",
                    met: stats.goalsMetThisMonth.met,
                    total: stats.goalsMetThisMonth.total,
                    color: .green
                )
                GoalRateCard(
                    title: "All Time",
                    met: stats.goalsMetAllTime.met,
                    total: stats.goalsMetAllTime.total,
                    color: .cyan
                )
            }

            // Recent 7 days goal progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Progress")
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray.opacity(0.7))

                HStack(spacing: 8) {
                    ForEach(stats.recentGoalProgress, id: \.date) { day in
                        GoalDayIndicator(
                            date: day.date,
                            metGoal: day.metGoal,
                            percentAchieved: day.percentAchieved
                        )
                    }
                }
            }
            .padding(.top, 4)
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

struct GoalRateCard: View {
    let title: String
    let met: Int
    let total: Int
    let color: Color

    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(Double(met) / Double(total) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(percentage)%")
                    .font(.custom("SF Mono", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text("\(met)/\(total)")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray)
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

struct GoalDayIndicator: View {
    let date: Date
    let metGoal: Bool?
    let percentAchieved: Double

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    var body: some View {
        VStack(spacing: 4) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 28, height: 28)

                if let met = metGoal {
                    Image(systemName: met ? "checkmark" : "circle")
                        .font(.system(size: met ? 12 : 8, weight: .bold))
                        .foregroundColor(met ? .green : .orange)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Day label
            Text(dayFormatter.string(from: date).prefix(1))
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(calendar.isDateInToday(date) ? .cyan : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        guard let met = metGoal else {
            return Color.gray.opacity(0.1)
        }
        if met {
            return Color.green.opacity(0.2)
        } else {
            // Partial progress - show orange tint based on percentage
            return Color.orange.opacity(0.1 + percentAchieved * 0.15)
        }
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
            .frame(height: 90)
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
            // Minutes label (consistent with WeeklyTrendBar)
            if minutes > 0 {
                Text(formatMinutes(minutes))
                    .font(.custom("SF Mono", size: 8))
                    .foregroundColor(.gray)
            }

            // Bar
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(height: barHeight)
            }
            .frame(height: 50)

            // Day label
            Text(dayFormatter.string(from: date).prefix(1))
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(isToday ? .cyan : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var barColor: Color {
        guard minutes > 0 else { return Color.gray.opacity(0.2) }
        return isToday ? .cyan : .green
    }

    private var barHeight: CGFloat {
        guard maxMinutes > 0, minutes > 0 else { return 4 }
        return max(4, CGFloat(minutes / maxMinutes) * 50)
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
