# Guitar Practice - SwiftUI Mac App

A native macOS app for managing guitar practice sessions, backed by Notion databases.

## Overview

This is a SwiftUI port of the [guitar-tui](../guitar-tui/) terminal app. The goal is to provide the same functionality with a better UX and native Mac features like a menu bar timer.

## Notion Integration

The app integrates with three Notion databases:

| Database | Purpose | Data Source ID |
|----------|---------|----------------|
| Practice Library | Master list of songs/exercises | `2d709433-8b1b-804c-897c-000b76c9e481` |
| Practice Sessions | Date-based session containers | `f4658dc0-2eb2-43fe-b268-1bba231c0156` |
| Practice Logs | Junction: items ↔ sessions with time tracking | `2d709433-8b1b-809b-bae2-000b1343e18f` |

## Architecture

```
GuitarPractice/
├── App/
│   ├── GuitarPracticeApp.swift      # Main entry, window + menu bar
│   └── ContentView.swift            # Root view with navigation
├── Features/
│   ├── Library/                     # Browse practice items
│   ├── Sessions/                    # Manage practice sessions
│   ├── Selected/                    # Current session items
│   └── Practice/                    # Timer + menu bar widget
├── Services/
│   ├── NotionClient.swift           # API calls
│   └── KeychainService.swift        # Secure API key storage
└── Models/
    └── Types.swift                  # Data models
```

## Development Phases

### Phase 1: Core Data Layer ✅
- [x] Create data models (LibraryItem, PracticeSession, PracticeLog, SelectedItem)
- [x] Implement NotionClient with async/await
  - [x] Fetch Practice Library items
  - [x] Fetch Practice Sessions
  - [x] Fetch Practice Logs for a session
  - [x] Create new Practice Log entries
  - [x] Update Practice Log (actual time, order)
- [x] Store API key in Keychain (not hardcoded)
- [x] Add error handling and loading states

### Phase 2: Library View ✅
- [x] Split view layout (NavigationSplitView)
- [x] Library list with item rows showing:
  - [x] Name, type icon, artist (if song)
  - [x] Last practiced date
  - [x] Times practiced count
- [x] Search with live filtering
- [x] Filter by type (Song/Exercise/Course Lesson)
- [x] Sort options (name, last practiced, times practiced)
- [x] Reverse sort toggle
- [x] Keyboard navigation (j/k or arrows)

### Phase 3: Session Management
- [ ] Session picker (sidebar or dropdown)
- [ ] Create new session (auto-named by date)
- [ ] Selected items pane showing:
  - Item name and planned time
  - Actual time (if practiced)
  - Completion status indicator
- [ ] Add items from library (double-click or space)
- [ ] Remove items from session
- [ ] Adjust planned time (+/- buttons or direct input)
- [ ] Reorder items (drag and drop)
- [ ] Delta save (only sync changed items to Notion)

### Phase 4: Practice Timer
- [ ] Full-window practice mode
- [ ] Large timer display (MM:SS)
- [ ] Current item name prominent
- [ ] Start/pause/resume controls
- [ ] Finish with confirmation dialog
- [ ] Track actual time (stored as decimal minutes)
- [ ] Resume from previous actual time if re-practicing
- [ ] Keyboard shortcuts (space = pause, enter = finish)

### Phase 5: Menu Bar Integration
- [ ] MenuBarExtra showing timer when practicing
- [ ] Display current item name
- [ ] Pause/resume/finish controls in dropdown
- [ ] Timer continues when main window closed
- [ ] Click to bring main window to front

### Phase 6: Polish ✅
- [x] Refresh data command (⌘R)
- [x] Open item in Notion (⌘O) - uses notion:// protocol
- [x] Format actual time as MM:SS instead of decimal minutes
- [x] Ctrl-F/Ctrl-B for page up/down in library list
- [x] Loading skeletons with shimmer animation
- [x] Auto-select today's session on launch
- [x] Settings view (API key configuration)
- [x] Error states and retry UI
- [x] Empty states for lists

### Phase 7: Future Enhancements (Ideas)
- [ ] **Timer Alert**: Sound chime + macOS notification when practice time elapses
  - Especially useful when app is backgrounded / viewing menu bar only
  - Consider a setting to toggle on/off
- [ ] **Calendar View**: Visual calendar showing practice history
  - Heat map or day-by-day view of sessions
  - Click to view/load past sessions
  - See streaks, total time per day/week/month
- [ ] **Stats Dashboard**: Practice analytics
  - Most practiced items
  - Time trends over weeks/months
  - Goals and streaks
- [ ] **Local Cache**: Cache Notion data locally for performance
  - Instant app launch with cached data, background refresh
  - Fewer API calls to Notion
  - Sync strategy: cache-first, then refresh; or periodic sync
  - Potential for offline support (queue writes, sync when online)
  - **Recommended approach: SwiftData**
    - Available on macOS 14+ (already our target)
    - Simple Swift-native API with `@Model` macro
    - Enables efficient queries for calendar/stats features
    - Alternative: Simple JSON file to `~/Library/Application Support/` if we just need fast launch

*Note: This app is evolving to be the primary UI, with Notion serving as the backend for editing practice library items.*

## Data Models

```swift
struct LibraryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let type: ItemType?
    let artist: String?
    let tags: [String]
    let lastPracticed: Date?
    let timesPracticed: Int

    enum ItemType: String, CaseIterable {
        case song = "Song"
        case exercise = "Exercise"
        case courseLesson = "Course Lesson"
    }
}

struct PracticeSession: Identifiable {
    let id: String
    let name: String
    let date: Date
    let logIds: [String]
}

struct PracticeLog: Identifiable {
    let id: String
    let itemId: String
    let sessionId: String
    let plannedMinutes: Int
    let actualMinutes: Double?
    let order: Int
}

struct SelectedItem: Identifiable {
    let id: String  // Use logId if saved, otherwise UUID
    let item: LibraryItem
    var plannedMinutes: Int
    var actualMinutes: Double?
    var logId: String?  // nil if not yet saved to Notion
    var isDirty: Bool   // Track if needs sync
}
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Navigate list | ↑/↓ or j/k |
| Select/toggle item | Space |
| Search | ⌘F or / |
| Save session | ⌘S |
| Refresh data | ⌘R |
| Open in Notion | ⌘O |
| Adjust time up | + or = |
| Adjust time down | - |
| Remove item | Delete or ⌘⌫ |
| Start practice | Enter or ⌘P |

## Technical Notes

- **Notion API**: Use URLSession with async/await. API version `2022-06-28`.
- **Database IDs**: REST API uses database IDs (from URLs) for queries. The TUI's SDK uses "data source IDs" but those don't work with raw REST API.
- **Time Format**: Actual time stored as decimal minutes (e.g., 5.5 = 5m 30s).
- **Delta Saves**: Track dirty items and only sync changes to reduce API calls.
- **Keychain**: Use Security framework to store API key securely.

## References

- [SwiftUI Handoff Doc](../guitar-tui/docs/SWIFTUI_HANDOFF.md)
- [Architecture Sketch](../guitar-tui/docs/NATIVE_MAC_APP.md)
- [TUI Source Code](../guitar-tui/src/)
