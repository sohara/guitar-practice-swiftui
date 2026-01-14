import SwiftUI

struct SessionDetailView: View {
    @ObservedObject var appState: AppState

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Session header with date
            SessionDetailHeaderView(appState: appState, dateFormatter: dateFormatter)

            Divider()
                .background(Color.white.opacity(0.1))

            // Content based on state
            if appState.isLoadingSession {
                LoadingSessionView()
            } else if appState.currentSession == nil {
                // No session for this date
                NoSessionView(appState: appState, dateFormatter: dateFormatter)
            } else if appState.sessionViewMode == .viewing {
                // Read-only view for past sessions
                SessionViewingModeView(appState: appState)
            } else {
                // Edit mode - existing selected items functionality
                SessionEditingModeView(appState: appState)
            }
        }
    }
}

struct SessionDetailHeaderView: View {
    @ObservedObject var appState: AppState
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: appState.selectedDate))
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                if appState.currentSession != nil {
                    HStack(spacing: 8) {
                        Label("\(appState.selectedItems.count) items", systemImage: "list.bullet")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.gray)

                        if appState.totalActualMinutes > 0 {
                            Label(formatMinutesAsTime(appState.totalActualMinutes), systemImage: "clock.fill")
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.green.opacity(0.8))
                        } else if appState.totalPlannedMinutes > 0 {
                            Label("\(appState.totalPlannedMinutes)m planned", systemImage: "clock")
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }
            }

            Spacer()

            // Unsaved indicator
            if appState.hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            }

            // Mode indicator / switch button
            if appState.currentSession != nil && appState.sessionViewMode == .viewing {
                Button {
                    appState.switchToEditMode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Edit")
                            .font(.custom("SF Mono", size: 11))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.cyan.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct LoadingSessionView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(.orange)
            Text("Loading session...")
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }
}

struct NoSessionView: View {
    @ObservedObject var appState: AppState
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if appState.isSelectedDatePast {
                // Past date with no session
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.3))

                Text("No practice recorded")
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.gray.opacity(0.5))

                Text("No session exists for this date")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray.opacity(0.3))
            } else {
                // Today or future date
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.3))

                Text(appState.isSelectedDateToday ? "Ready to practice?" : "Plan ahead")
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.gray.opacity(0.6))

                Button {
                    Task {
                        _ = await appState.createSessionForSelectedDate()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(appState.isSelectedDateToday ? "Start Session" : "Create Session")
                    }
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding()
    }
}
