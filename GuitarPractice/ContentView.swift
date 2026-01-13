import SwiftUI

struct ContentView: View {
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

            VStack(spacing: 24) {
                // Header
                Text("Guitar Practice")
                    .font(.custom("SF Mono", size: 32))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Session Manager")
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.gray)
                    .tracking(4)
                    .textCase(.uppercase)

                Spacer()
                    .frame(height: 40)

                // Status indicators
                HStack(spacing: 40) {
                    StatusCard(
                        icon: "music.note.list",
                        label: "Library",
                        value: "--",
                        color: .cyan
                    )
                    StatusCard(
                        icon: "clock",
                        label: "Sessions",
                        value: "--",
                        color: .orange
                    )
                    StatusCard(
                        icon: "checkmark.circle",
                        label: "Practiced",
                        value: "--",
                        color: .green
                    )
                }

                Spacer()

                // Footer
                Text("Connecting to Notion...")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray.opacity(0.6))

                // Keyboard hint
                HStack(spacing: 16) {
                    KeyHint(key: "j/k", action: "navigate")
                    KeyHint(key: "space", action: "select")
                    KeyHint(key: "/", action: "search")
                    KeyHint(key: "p", action: "practice")
                }
                .padding(.bottom, 20)
            }
            .padding(40)
        }
        .preferredColorScheme(.dark)
    }
}

struct StatusCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)

            Text(value)
                .font(.custom("SF Mono", size: 36))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(label)
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.gray)
                .tracking(2)
                .textCase(.uppercase)
        }
        .frame(width: 140, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct KeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.custom("SF Mono", size: 10))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}

#Preview {
    ContentView()
}
