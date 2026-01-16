import SwiftUI
import SwiftData
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions for timer alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Bring window to front on launch
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show window when clicking dock icon
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

@main
struct GuitarPracticeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                CachedLibraryItem.self,
                CachedPracticeSession.self,
                CachedPracticeLog.self,
                CacheMetadata.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .modelContainer(modelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        // Menu bar extra - always visible, content changes based on practice state
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            if appState.isPracticing {
                // Show timer countdown when practicing
                HStack(spacing: 4) {
                    Image(systemName: "guitars.fill")
                    Text(appState.practiceRemainingFormatted)
                        .monospacedDigit()
                }
            } else {
                Image(systemName: "guitars")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if appState.isPracticing {
            practicingMenu
        } else {
            idleMenu
        }
    }

    var idleMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Show Window", systemImage: "macwindow")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    var practicingMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pause/Resume at top for quick access
            Button {
                appState.toggleTimer()
            } label: {
                Label(
                    appState.isTimerRunning ? "Pause" : "Resume",
                    systemImage: appState.isTimerRunning ? "pause.fill" : "play.fill"
                )
            }

            // Timer display
            if let _ = appState.currentPracticeItem {
                HStack {
                    if appState.isPracticeOvertime {
                        Text("Overtime: +\(appState.practiceElapsedFormatted)")
                            .foregroundColor(.orange)
                    } else {
                        Text("Remaining: \(appState.practiceRemainingFormatted)")
                    }
                    Spacer()
                    Text("(\(appState.practiceProgress))")
                        .foregroundColor(.secondary)
                }
                .font(.system(.body, design: .monospaced))

                Divider()

                // Current item info
                Text(appState.currentPracticeItem!.item.name)
                    .font(.headline)
                    .lineLimit(1)

                if let artist = appState.currentPracticeItem!.item.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()
            }

            if appState.practiceItemIndex < appState.selectedItems.count - 1 {
                Button {
                    Task {
                        await appState.finishAndNextItem()
                    }
                } label: {
                    Label("Save & Next", systemImage: "arrow.right")
                }
            }

            Button {
                Task {
                    await appState.finishCurrentItem()
                }
            } label: {
                Label("Finish & Exit", systemImage: "checkmark")
            }

            Divider()

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Show Window", systemImage: "macwindow")
            }

            Button {
                appState.endPractice()
            } label: {
                Label("Exit Practice", systemImage: "xmark")
            }
        }
    }
}
