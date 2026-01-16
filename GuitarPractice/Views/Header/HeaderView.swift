import SwiftUI

struct HeaderView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
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

            Spacer()

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
            let isRefreshActive = appState.isLoading || appState.isRefreshing
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: isRefreshActive ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isRefreshActive ? 360 : 0))
                    .animation(isRefreshActive ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshActive)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshActive)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh Data")
        }
    }
}
