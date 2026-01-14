import SwiftUI

struct LibraryItemRow: View {
    let item: LibraryItem
    let isSelected: Bool
    let isFocused: Bool
    let onFocus: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onFocus) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .green : .gray.opacity(0.4))

                // Type icon
                Image(systemName: item.type?.icon ?? "questionmark")
                    .font(.system(size: 14))
                    .foregroundColor(typeColor(item.type))
                    .frame(width: 20)

                // Name
                Text(item.name)
                    .font(.custom("SF Mono", size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Artist (if song)
                if let artist = item.artist {
                    Text("— \(artist)")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Stats
                if let lastPracticed = item.lastPracticed {
                    Text(formatRelativeDate(lastPracticed))
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.gray.opacity(0.5))
                }

                if item.timesPracticed > 0 {
                    Text("×\(item.timesPracticed)")
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.cyan.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isFocused {
                        Color.orange.opacity(0.15)
                    } else if isSelected {
                        Color.green.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                isFocused ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        .padding(.horizontal, 4)
                    : nil
            )
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            onToggle()
        }
        .onTapGesture(count: 1) {
            onFocus()
        }
    }

    private func typeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "1d ago" }
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }
}
