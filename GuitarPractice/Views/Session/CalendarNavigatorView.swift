import SwiftUI

struct CalendarNavigatorView: View {
    @ObservedObject var appState: AppState

    /// Tracks navigation direction for slide animation
    @State private var navigatingForward = true

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    /// Cached day summaries for the displayed month
    private var daySummaries: [Date: DaySummary] {
        appState.daySummaries(for: appState.displayedMonth)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    navigatingForward = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: -1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.custom("SF Mono", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    navigatingForward = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: 1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        let startOfDay = calendar.startOfDay(for: date)
                        CalendarNavigatorDayView(
                            date: date,
                            summary: daySummaries[startOfDay],
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: appState.selectedDate)
                        ) {
                            Task {
                                await appState.selectDate(date)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .id(appState.displayedMonth)
            .transition(.asymmetric(
                insertion: .move(edge: navigatingForward ? .trailing : .leading),
                removal: .move(edge: navigatingForward ? .leading : .trailing)
            ))
            .clipped()

            // Mini stats row
            HStack(spacing: 16) {
                MiniStatView(icon: "flame", value: "\(currentStreak)", label: "streak", color: .orange)
                MiniStatView(icon: "🎯", value: "\(appState.goalAchievementRate)%", label: "goals", color: .green, useEmoji: true)
                MiniStatView(icon: "calendar", value: "\(sessionsThisMonth)", label: "this month", color: .cyan)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: appState.displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: appState.displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        // Generate 6 weeks worth of days (max needed for any month)
        for _ in 0..<42 {
            if calendar.isDate(currentDate, equalTo: appState.displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if days.isEmpty || calendar.compare(currentDate, to: monthInterval.start, toGranularity: .month) == .orderedAscending {
                days.append(nil) // Padding before month starts
            } else {
                days.append(nil) // Padding after month ends
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Trim trailing empty rows
        while days.count > 7 && days.suffix(7).allSatisfy({ $0 == nil }) {
            days.removeLast(7)
        }

        return days
    }

    private var sessionsThisMonth: Int {
        // Only count sessions with actual practice time
        let summaries = appState.daySummaries(for: appState.displayedMonth)
        return summaries.values.filter { $0.actualMinutes > 0 }.count
    }

    private var currentStreak: Int {
        let sortedSessions = appState.sessions.sorted { $0.date > $1.date }
        guard !sortedSessions.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if practiced today
        if let mostRecent = sortedSessions.first,
           calendar.isDate(mostRecent.date, inSameDayAs: checkDate) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        } else {
            // If not practiced today, start checking from yesterday
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Count consecutive days
        for session in sortedSessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            if calendar.isDate(sessionDay, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if sessionDay < checkDate {
                break // Gap in streak
            }
        }

        return streak
    }
}

struct CalendarNavigatorDayView: View {
    let date: Date
    let summary: DaySummary?
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var hasSession: Bool {
        summary != nil
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background with heat map intensity
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                    )

                VStack(spacing: 2) {
                    // Day number
                    Text("\(calendar.component(.day, from: date))")
                        .font(.custom("SF Mono", size: 13))
                        .fontWeight(isToday ? .bold : .medium)
                        .foregroundColor(textColor)

                    // Time label (e.g., "45m") or item count
                    if let summary = summary {
                        if let timeLabel = summary.timeLabel {
                            Text(timeLabel)
                                .font(.custom("SF Mono", size: 10))
                                .foregroundColor(statColor)
                        } else if summary.itemCount > 0 {
                            // Show item count if no actual time yet
                            Text("\(summary.itemCount)")
                                .font(.custom("SF Mono", size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltipText)
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        if isSelected {
            return .cyan.opacity(0.3)
        } else if let summary = summary, summary.actualMinutes > 0 {
            // Heat map: intensity based on practice time (green gradient)
            let intensity = summary.intensity
            // Range from 0.1 (light) to 0.4 (dark) opacity
            return .green.opacity(0.1 + (intensity * 0.3))
        } else if hasSession {
            // Has session but no actual time yet
            return .green.opacity(0.05)
        }
        return .clear
    }

    private var borderColor: Color {
        isToday ? .cyan : .clear
    }

    private var textColor: Color {
        if isSelected || hasSession {
            return .white
        }
        return .gray.opacity(0.5)
    }

    private var statColor: Color {
        if isSelected {
            return .white.opacity(0.9)
        }
        // Brighter green for more practice time
        if let summary = summary {
            let intensity = summary.intensity
            return Color(
                red: 0.3 + (intensity * 0.2),
                green: 0.8 + (intensity * 0.2),
                blue: 0.3 + (intensity * 0.2)
            )
        }
        return .green.opacity(0.8)
    }

    private var tooltipText: String {
        guard let summary = summary else {
            return dateFormatter.string(from: date)
        }

        var lines: [String] = [dateFormatter.string(from: date)]

        if summary.itemCount > 0 {
            let itemText = summary.itemCount == 1 ? "1 item" : "\(summary.itemCount) items"
            lines.append(itemText)
        }

        if summary.actualMinutes > 0 {
            let minutes = Int(summary.actualMinutes)
            let planned = summary.plannedMinutes
            lines.append("\(minutes)m practiced of \(planned)m planned")
        } else if summary.plannedMinutes > 0 {
            lines.append("\(summary.plannedMinutes)m planned")
        }

        return lines.joined(separator: "\n")
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
}

struct MiniStatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var useEmoji: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if useEmoji {
                Text(icon)
                    .font(.system(size: 9))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.custom("SF Mono", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(label)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray)
        }
    }
}
