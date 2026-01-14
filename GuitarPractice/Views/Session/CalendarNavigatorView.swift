import SwiftUI

struct CalendarNavigatorView: View {
    @ObservedObject var appState: AppState

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: -1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.custom("SF Mono", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation {
                        appState.displayedMonth = calendar.date(byAdding: .month, value: 1, to: appState.displayedMonth) ?? appState.displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
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

            // Calendar grid (compact)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        CalendarNavigatorDayView(
                            date: date,
                            hasSession: appState.sessionForDate(date) != nil,
                            isToday: calendar.isDateInToday(date),
                            isSelected: calendar.isDate(date, inSameDayAs: appState.selectedDate)
                        ) {
                            Task {
                                await appState.selectDate(date)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }

            // Mini stats row
            HStack(spacing: 16) {
                MiniStatView(icon: "flame", value: "\(currentStreak)", label: "streak", color: .orange)
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
        appState.sessions.filter { session in
            calendar.isDate(session.date, equalTo: appState.displayedMonth, toGranularity: .month)
        }.count
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
    let hasSession: Bool
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderColor, lineWidth: isToday ? 1.5 : 0)
                    )

                VStack(spacing: 1) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.custom("SF Mono", size: 11))
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundColor(textColor)

                    // Practice indicator dot
                    if hasSession {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 28)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .cyan.opacity(0.3)
        } else if hasSession {
            return .green.opacity(0.1)
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
}

struct MiniStatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
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
