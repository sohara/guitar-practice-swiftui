import SwiftUI

struct HeaderView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guitar Practice")
                    .font(.custom("SF Mono", size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Practice Library")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.gray)
                    .tracking(2)
                    .textCase(.uppercase)
            }

            Spacer()

            // Stats
            HStack(spacing: 20) {
                StatBadge(
                    icon: "music.note.list",
                    value: "\(appState.filteredLibrary.count)",
                    total: appState.library.count,
                    color: .cyan
                )
                .help("Library Items")
                StatBadge(
                    icon: "clock",
                    value: "\(appState.sessions.count)",
                    color: .orange
                )
                .help("Practice Sessions")
                StatBadge(
                    icon: "checkmark.circle",
                    value: "\(appState.selectedItems.count)",
                    color: .green
                )
                .help("Items in Session")
            }

            Spacer()
                .frame(width: 20)

            // Stats toggle button
            Button {
                appState.toggleStatsView()
            } label: {
                Image(systemName: appState.isShowingStats ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 16))
                    .foregroundColor(appState.isShowingStats ? .cyan : .gray)
            }
            .buttonStyle(.plain)
            .help(appState.isShowingStats ? "Hide Stats" : "Show Stats")

            // Open in Notion button
            Button {
                appState.openFocusedItemInNotion()
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .help("Open in Notion")

            // Settings button
            Button {
                appState.isSettingsPresented = true
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")

            // Refresh button
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: appState.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(appState.isLoading ? 360 : 0))
                    .animation(appState.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isLoading)
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoading)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh Data")
        }
    }
}
