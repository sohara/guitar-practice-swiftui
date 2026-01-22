import SwiftUI

struct SessionPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Calendar navigator at top
            CalendarNavigatorView(appState: appState)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Session detail below
            SessionDetailView(appState: appState)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                // Clear session item focus when tapping anywhere in panel
                // Child handlers (buttons, rows) will set their own focus after this
                appState.focusedSelectedIndex = nil
            }
        )
    }
}
