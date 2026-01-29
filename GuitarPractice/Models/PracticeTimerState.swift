import SwiftUI
import AppKit
import UserNotifications

@MainActor
class PracticeTimerState: ObservableObject {
    @Published var elapsedSeconds: Double = 0
    @Published var isRunning: Bool = false

    private var timerTask: Task<Void, Never>?
    var hasTriggeredOvertimeAlert: Bool = false

    /// Callback invoked on every tick so AppState can check overtime
    var onTick: (() -> Void)?

    func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func resume() {
        guard !isRunning else { return }
        isRunning = true

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self = self else { return }
                    self.elapsedSeconds += 0.1
                    self.onTick?()
                }
            }
        }
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            resume()
        }
    }

    func reset() {
        pause()
        elapsedSeconds = 0
        hasTriggeredOvertimeAlert = false
    }
}
