import SwiftUI

struct SessionEditingModeView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Session is empty")
                        .font(.custom("SF Mono", size: 13))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Add items from the library")
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.gray.opacity(0.3))
                    Spacer()
                }
            } else {
                // Editable items list with drag and drop
                List {
                    ForEach(Array(appState.selectedItems.enumerated()), id: \.element.id) { index, selected in
                        SelectedItemRow(
                            selected: selected,
                            isFocused: appState.focusedPanel == .selectedItems && appState.focusedSelectedIndex == index,
                            onFocus: {
                                appState.focusedPanel = .selectedItems
                                appState.focusedSelectedIndex = index
                            },
                            onRemove: {
                                appState.removeSelectedItem(at: index)
                            },
                            onAdjustTime: { delta in
                                appState.updatePlannedTime(at: index, minutes: selected.plannedMinutes + delta)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                    .onMove { source, destination in
                        appState.moveSelectedItem(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer with save/practice buttons
            SessionEditingFooterView(appState: appState)
        }
    }
}

struct SessionEditingFooterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack {
                // Error message
                if let error = appState.sessionError {
                    Text(error.localizedDescription)
                        .font(.custom("SF Mono", size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                Spacer()

                // Clear button
                if !appState.selectedItems.isEmpty {
                    Button {
                        appState.clearSelection()
                    } label: {
                        Text("Clear")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }

                // Practice button
                Button {
                    appState.startPractice()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Practice")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedItems.isEmpty)
                .keyboardShortcut("p", modifiers: .command)

                // Save button
                Button {
                    Task {
                        await appState.saveSession()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if appState.isSavingSession {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        Text("Save")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.hasUnsavedChanges ? Color.orange : Color.gray.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.isSavingSession || !appState.hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

struct SelectedItemRow: View {
    let selected: SelectedItem
    let isFocused: Bool
    let onFocus: () -> Void
    let onRemove: () -> Void
    let onAdjustTime: (Int) -> Void

    var isCompleted: Bool {
        selected.actualMinutes != nil && selected.actualMinutes! > 0
    }

    var body: some View {
        HStack(spacing: 10) {
            // Completion indicator / drag handle
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundColor(isCompleted ? .green : .gray.opacity(0.4))
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

            // Actual time (if practiced)
            if let actual = selected.actualMinutes, actual > 0 {
                Text(formatMinutesAsTime(actual))
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.green.opacity(0.7))
            }

            // Time adjustment
            HStack(spacing: 3) {
                Button {
                    onAdjustTime(-1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)

                Text("\(selected.plannedMinutes)m")
                    .font(.custom("SF Mono", size: 11))
                    .foregroundColor(.orange)
                    .frame(width: 28)

                Button {
                    onAdjustTime(1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.5))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isFocused ? Color.cyan.opacity(0.15) : (isCompleted ? Color.green.opacity(0.05) : Color.clear))
        )
        .overlay(
            isFocused ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
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
}
