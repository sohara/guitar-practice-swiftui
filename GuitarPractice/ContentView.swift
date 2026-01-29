import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if appState.needsAPIKey {
                APIKeySetupView(appState: appState)
            } else if appState.isPracticing {
                PracticeView(appState: appState, timerState: appState.timerState)
            } else {
                MainContentView(appState: appState)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsView(appState: appState)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(appState: AppState())
}
