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
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Date + actions
            HStack {
                Text(dateFormatter.string(from: appState.selectedDate))
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.white)

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

            if appState.currentSession != nil {
                // Session info: items (planned)
                HStack(spacing: 4) {
                    Text("\(appState.selectedItems.count) items")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray)

                    if appState.totalPlannedMinutes > 0 {
                        Text("(\(appState.totalPlannedMinutes)m planned)")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }

                // Goal progress row
                GoalProgressView(appState: appState)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GoalProgressView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Goal icon and progress text
                Text("🎯")
                    .font(.system(size: 10))

                Text("\(Int(appState.totalActualMinutes))m")
                    .font(.custom("SF Mono", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(appState.isGoalMet ? .green : .white)

                Text("/")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray)

                // Goal value with stepper (only in editing mode)
                if appState.sessionViewMode == .editing {
                    HStack(spacing: 4) {
                        Button {
                            Task {
                                let newGoal = max(5, appState.currentSessionGoal - 5)
                                await appState.updateSessionGoal(newGoal)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text("\(appState.currentSessionGoal)m")
                            .font(.custom("SF Mono", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .frame(minWidth: 30)

                        Button {
                            Task {
                                let newGoal = appState.currentSessionGoal + 5
                                await appState.updateSessionGoal(newGoal)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("goal")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray)
                } else {
                    Text("\(appState.currentSessionGoal)m goal")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.orange)
                }

                Spacer()

                // Percentage
                Text("\(Int(appState.goalProgress * 100))%")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(appState.isGoalMet ? .green : .gray)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(appState.isGoalMet ? Color.green : Color.orange)
                        .frame(width: geometry.size.width * appState.goalProgress, height: 6)
                }
            }
            .frame(height: 6)
        }
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
