import SwiftUI

struct PracticeView: View {
    @ObservedObject var appState: AppState
    @FocusState private var isFocused: Bool
    @FocusState private var isNotesFocused: Bool
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

                // Open in Notion button
                Button {
                    appState.openCurrentPracticeItemInNotion()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o", modifiers: .command)
                .help("Open in Notion")

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
                    .opacity(appState.isTimerRunning ? 1 : 0.4)

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

                    // Notes card (current + history)
                    NotesCard(
                        notesText: $notesText,
                        isNotesFocused: $isNotesFocused,
                        previousNotes: appState.currentItemNotesHistory,
                        isLoadingHistory: appState.isLoadingNotesHistory,
                        onSave: {
                            let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                            appState.updateNotes(at: appState.practiceItemIndex, notes: trimmed.isEmpty ? nil : trimmed)
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
                PracticeKeyHint(key: "⌘O", action: "notion")
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
            // Reset notes text when switching items
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

struct NotesCard: View {
    @Binding var notesText: String
    var isNotesFocused: FocusState<Bool>.Binding
    let previousNotes: [HistoricalNote]
    let isLoadingHistory: Bool
    let onSave: () -> Void

    @State private var isEditing: Bool = false
    @State private var originalText: String = ""

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                // Current note (editable, yellow accent)
                NoteRow(
                    label: "TODAY",
                    content: notesText.isEmpty ? "Click to add note..." : notesText,
                    accentColor: .yellow,
                    isPlaceholder: notesText.isEmpty,
                    isEditing: isEditing,
                    editText: $notesText,
                    isNotesFocused: isNotesFocused,
                    onTap: {
                        originalText = notesText
                        isEditing = true
                        isNotesFocused.wrappedValue = true
                    },
                    onSave: {
                        onSave()
                        isEditing = false
                    },
                    onCancel: {
                        notesText = originalText
                        isEditing = false
                    }
                )

                // Previous notes (read-only, gray accent)
                ForEach(previousNotes) { note in
                    NoteRow(
                        label: dateFormatter.string(from: note.date).uppercased(),
                        content: note.notes,
                        accentColor: .gray,
                        isPlaceholder: false,
                        isEditing: false,
                        editText: .constant(""),
                        isNotesFocused: isNotesFocused,
                        onTap: {},
                        onSave: {},
                        onCancel: {}
                    )
                }

                // Loading indicator
                if isLoadingHistory {
                    HStack {
                        Spacer()
                        Text("Loading history...")
                            .font(.custom("SF Mono", size: 11))
                            .foregroundColor(.gray.opacity(0.4))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 380)
    }
}

struct NoteRow: View {
    let label: String
    let content: String
    let accentColor: Color
    let isPlaceholder: Bool
    let isEditing: Bool
    @Binding var editText: String
    var isNotesFocused: FocusState<Bool>.Binding
    let onTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(accentColor.opacity(0.6))
                .frame(width: 3)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.custom("SF Mono", size: 10))
                        .fontWeight(.medium)
                        .foregroundColor(accentColor.opacity(0.7))
                        .tracking(0.5)

                    Spacer()

                    if isEditing {
                        Button {
                            onSave()
                        } label: {
                            Text("Save")
                                .font(.custom("SF Mono", size: 11))
                                .foregroundColor(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isEditing {
                    TextEditor(text: $editText)
                        .font(.custom("SF Mono", size: 13))
                        .scrollContentBackground(.hidden)
                        .focused(isNotesFocused)
                        .frame(minHeight: 40, maxHeight: 100)
                        .onKeyPress(.return, phases: .down) { keyPress in
                            if keyPress.modifiers.contains(.shift) {
                                onSave()
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.escape) {
                            onCancel()
                            return .handled
                        }
                } else {
                    Text(content)
                        .font(.custom("SF Mono", size: 13))
                        .foregroundColor(isPlaceholder ? .gray.opacity(0.4) : .white.opacity(accentColor == .yellow ? 0.9 : 0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(accentColor.opacity(0.05))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing && accentColor == .yellow {
                onTap()
            }
        }
    }
}
