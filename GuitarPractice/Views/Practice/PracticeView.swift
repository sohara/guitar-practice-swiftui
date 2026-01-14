import SwiftUI

struct PracticeView: View {
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @State private var isNotesExpanded: Bool = false
    @State private var notesText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with exit button
            HStack {
                Button {
                    appState.endPractice()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                        Text("Exit")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                // Progress indicator
                Text(appState.practiceProgress)
                    .font(.custom("SF Mono", size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Spacer()

            // Main practice content
            if let item = appState.currentPracticeItem {
                VStack(spacing: 24) {
                    // Item type icon
                    Image(systemName: item.item.type?.icon ?? "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(practiceTypeColor(item.item.type))

                    // Item name
                    Text(item.item.name)
                        .font(.custom("SF Mono", size: 32))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Artist (if song)
                    if let artist = item.item.artist {
                        Text(artist)
                            .font(.custom("SF Mono", size: 18))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                        .frame(height: 20)

                    // Timer display
                    VStack(spacing: 8) {
                        // Remaining time (or overtime indicator)
                        if appState.isPracticeOvertime {
                            Text("OVERTIME")
                                .font(.custom("SF Mono", size: 14))
                                .foregroundColor(.orange)
                                .tracking(2)

                            Text("+\(appState.practiceElapsedFormatted)")
                                .font(.custom("SF Mono", size: 72))
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        } else {
                            Text("REMAINING")
                                .font(.custom("SF Mono", size: 14))
                                .foregroundColor(.gray)
                                .tracking(2)

                            Text(appState.practiceRemainingFormatted)
                                .font(.custom("SF Mono", size: 72))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }

                        // Elapsed time (smaller)
                        HStack(spacing: 4) {
                            Text("Elapsed:")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                            Text(appState.practiceElapsedFormatted)
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.cyan)
                                .monospacedDigit()
                            Text("/")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("\(item.plannedMinutes):00")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                                .monospacedDigit()
                        }
                    }

                    // Timer status
                    if !appState.isTimerRunning {
                        Text("PAUSED")
                            .font(.custom("SF Mono", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                    }

                    Spacer()
                        .frame(height: 40)

                    // Control buttons
                    HStack(spacing: 16) {
                        // Pause/Resume button
                        Button {
                            appState.toggleTimer()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: appState.isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16))
                                Text(appState.isTimerRunning ? "Pause" : "Resume")
                                    .font(.custom("SF Mono", size: 14))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)

                        // Next button (save and continue)
                        if appState.practiceItemIndex < appState.selectedItems.count - 1 {
                            Button {
                                Task {
                                    await appState.finishAndNextItem()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14))
                                    Text("Next")
                                        .font(.custom("SF Mono", size: 14))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.cyan.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Finish button (save and exit)
                        Button {
                            Task {
                                await appState.finishCurrentItem()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14))
                                Text("Finish")
                                    .font(.custom("SF Mono", size: 14))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        // Skip button (no save, just move on)
                        Button {
                            appState.skipToNextItem()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                Text("Skip")
                                    .font(.custom("SF Mono", size: 12))
                            }
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                        .frame(height: 24)

                    // Notes section
                    PracticeNotesSection(
                        isExpanded: $isNotesExpanded,
                        notesText: $notesText,
                        isNotesFocused: $isNotesFocused,
                        hasExistingNotes: item.notes != nil && !item.notes!.isEmpty,
                        onSave: {
                            let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                            appState.updateNotes(at: appState.practiceItemIndex, notes: trimmed.isEmpty ? nil : trimmed)
                            isNotesExpanded = false
                            isFocused = true
                        },
                        onCancel: {
                            isNotesExpanded = false
                            isFocused = true
                        }
                    )
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            // Footer with keyboard hints
            HStack(spacing: 16) {
                PracticeKeyHint(key: "space", action: "pause/resume")
                PracticeKeyHint(key: "enter", action: "finish & exit")
                PracticeKeyHint(key: "n", action: "save & next")
                PracticeKeyHint(key: "s", action: "skip")
                PracticeKeyHint(key: "esc", action: "exit")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.03, green: 0.03, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.space) {
            guard !isNotesFocused else { return .ignored }
            appState.toggleTimer()
            return .handled
        }
        .onKeyPress(.return) {
            guard !isNotesFocused else { return .ignored }
            Task {
                await appState.finishCurrentItem()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "nN")) { _ in
            guard !isNotesFocused else { return .ignored }
            Task {
                await appState.finishAndNextItem()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { _ in
            guard !isNotesFocused else { return .ignored }
            appState.skipToNextItem()
            return .handled
        }
        .onChange(of: appState.practiceItemIndex) { _, _ in
            // Reset notes state when switching items
            isNotesExpanded = false
            if let item = appState.currentPracticeItem {
                notesText = item.notes ?? ""
            }
        }
        .onAppear {
            // Initialize notes text from current item
            if let item = appState.currentPracticeItem {
                notesText = item.notes ?? ""
            }
        }
    }

    private func practiceTypeColor(_ type: ItemType?) -> Color {
        switch type {
        case .song: return .pink
        case .exercise: return .cyan
        case .courseLesson: return .orange
        case nil: return .gray
        }
    }
}

struct PracticeKeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.custom("SF Mono", size: 11))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                )

            Text(action)
                .font(.custom("SF Mono", size: 11))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

struct PracticeNotesSection: View {
    @Binding var isExpanded: Bool
    @Binding var notesText: String
    var isNotesFocused: FocusState<Bool>.Binding
    let hasExistingNotes: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Expanded notes editor
                VStack(spacing: 8) {
                    TextField("Add a note (e.g., 'Got to 80bpm', 'Work on bridge')", text: $notesText)
                        .font(.custom("SF Mono", size: 14))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .focused(isNotesFocused)
                        .onSubmit {
                            onSave()
                        }

                    HStack(spacing: 12) {
                        Button(action: onSave) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11))
                                Text("Save Note")
                                    .font(.custom("SF Mono", size: 12))
                            }
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.custom("SF Mono", size: 12))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 400)
            } else {
                // Collapsed state - show button to expand
                Button {
                    isExpanded = true
                    isNotesFocused.wrappedValue = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasExistingNotes ? "note.text" : "note.text.badge.plus")
                            .font(.system(size: 12))
                        Text(hasExistingNotes ? "Edit Note" : "Add Note")
                            .font(.custom("SF Mono", size: 12))
                    }
                    .foregroundColor(hasExistingNotes ? .yellow : .gray.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(hasExistingNotes ? Color.yellow.opacity(0.1) : Color.white.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)

                // Show existing note preview if collapsed
                if hasExistingNotes {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.yellow.opacity(0.6))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Note")
                                .font(.custom("SF Mono", size: 10))
                                .foregroundColor(.yellow.opacity(0.5))
                                .textCase(.uppercase)
                            Text(notesText)
                                .font(.custom("SF Mono", size: 13))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.yellow.opacity(0.08))
                    )
                    .frame(maxWidth: 350)
                }
            }
        }
    }
}
