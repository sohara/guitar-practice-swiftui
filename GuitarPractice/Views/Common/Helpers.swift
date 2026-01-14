import Foundation

/// Formats decimal minutes as MM:SS (e.g., 2.5 -> "2:30")
func formatMinutesAsTime(_ minutes: Double) -> String {
    let totalSeconds = Int(minutes * 60)
    let mins = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%d:%02d", mins, secs)
}
