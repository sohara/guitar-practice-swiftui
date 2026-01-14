import SwiftUI

struct SessionViewingModeView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Session was empty")
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                }
            } else {
                // Read-only list of practiced items
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(appState.selectedItems) { selected in
                            SessionItemReadOnlyRow(selected: selected)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Footer with "Edit" option
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))

                HStack {
                    Text("Viewing past session")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.5))

                    Spacer()

                    Button {
                        appState.switchToEditMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                            Text("Edit Session")
                                .font(.custom("SF Mono", size: 12))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.cyan.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

struct SessionItemReadOnlyRow: View {
    let selected: SelectedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Completion indicator
                Image(systemName: selected.actualMinutes != nil && selected.actualMinutes! > 0 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(selected.actualMinutes != nil && selected.actualMinutes! > 0 ? .green : .gray.opacity(0.4))
                    .frame(width: 16)

                // Type icon
                Image(systemName: selected.item.type?.icon ?? "questionmark")
                    .font(.system(size: 12))
                    .foregroundColor(typeColor(selected.item.type))
                    .frame(width: 16)

                // Name and artist
                VStack(alignment: .leading, spacing: 1) {
                    Text(selected.item.name)
                        .font(.custom("SF Mono", size: 12))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let artist = selected.item.artist {
                        Text(artist)
                            .font(.custom("SF Mono", size: 9))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Times
                VStack(alignment: .trailing, spacing: 1) {
                    if let actual = selected.actualMinutes, actual > 0 {
                        Text(formatMinutesAsTime(actual))
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    Text("\(selected.plannedMinutes)m planned")
                        .font(.custom("SF Mono", size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }

            // Display notes if present
            if let notes = selected.notes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text(notes)
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(.top, 4)
                .padding(.leading, 42)  // Align with name
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            selected.actualMinutes != nil && selected.actualMinutes! > 0
                ? Color.green.opacity(0.05)
                : Color.clear
        )
    }

    private func typeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }
}
