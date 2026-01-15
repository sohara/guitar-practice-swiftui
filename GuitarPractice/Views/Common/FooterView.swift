import SwiftUI

struct FooterView: View {
    var body: some View {
        HStack(spacing: 12) {
            KeyHint(key: "tab", action: "switch panel")
            KeyHint(key: "↑↓", action: "navigate")
            KeyHint(key: "^F/B", action: "page")
            KeyHint(key: "T", action: "today")
            KeyHint(key: "enter", action: "add/remove")
            KeyHint(key: "+/-", action: "time")
            KeyHint(key: "⌫", action: "remove")
            KeyHint(key: "⌘O", action: "notion")
            KeyHint(key: "⌘P", action: "practice")
            KeyHint(key: "⌘S", action: "save")

            Spacer()

            Text("Guitar Practice")
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

struct KeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.custom("SF Mono", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 12))
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}
