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

### Phase 7: Enhancements (Ordered Implementation Plan)

**Implementation order rationale**: Start with a quick win (Timer Alert), then build the foundational data cache (SwiftData) that enables efficient queries for Calendar and Stats features. Finish with UI polish.

#### 7.1 Timer Alert ✅
- [x] Sound chime + macOS notification when practice time elapses
- [x] Especially useful when app is backgrounded / viewing menu bar only
- [ ] Consider a setting to toggle on/off (future)
- [x] Uses `NSSound` for sound, `UserNotifications` for system alerts

#### 7.2 Local Cache (SwiftData) ✅
- [x] Cache Notion data locally for performance
- [x] Instant app launch with cached data, background refresh
- [x] Fewer API calls to Notion
- [x] Sync strategy: cache-first, then refresh from Notion
- [x] SwiftData `@Model` classes mirroring existing types
- [x] Enables efficient `@Query` predicates for calendar/stats
- [ ] Future: potential offline support (queue writes, sync when online)

#### 7.3 Calendar View ✅
- [x] Visual calendar showing practice history
- [x] Click to view/load past sessions
- [x] See streaks, sessions this month
- [x] **Converted to main view** - Calendar now embedded in right panel
- [x] **Session summary** - Shows items count, planned/actual time per day
- [x] **View/Edit modes** - Past sessions open read-only, today/future in edit mode
- [ ] Leverages SwiftData for efficient date-range queries

**Future Calendar Enhancements:**
- [ ] Day cell stats: Show actual/planned time on each day (e.g., "45m" or "45/60m")
- [ ] Day cell item count: Number of items practiced (e.g., "3 items")
- [ ] Heat map intensity: Color gradient based on practice duration
- [ ] Tooltip/hover: Show quick summary on hover before clicking
- [ ] Week view: More compact horizontal layout option
- [ ] Collapsible calendar: Toggle to hide/show calendar section

#### App Icon ✅
- [x] Create custom app icon for macOS
- [x] AI-generated dark guitar with green neon accents (Google Gemini)
- [x] Applied macOS Big Sur rounded corner mask via `fix_corners.swift`
- [x] Generated all required sizes (16-1024px)

#### 7.4 Stats Dashboard ✅
- [x] Practice analytics with aggregated data
- [x] Most practiced items (by time and count)
- [x] Time trends over weeks/months (8-week chart)
- [x] Current and longest streaks
- [x] Leverages SwiftData for efficient aggregation queries
- [x] Type breakdown (Song/Exercise/Course Lesson)
- [x] Recent 7-day activity bar chart
- [x] Toggle button in header to switch views

#### 7.5 UI Polish
- [ ] **Flexible Split View**: Improve two-pane layout
  - Default to 50/50 split instead of current fixed widths
  - User-adjustable divider position
  - Minimum 20% width for either pane
  - Persist user's preferred split ratio
- [ ] **Typography Improvements**: Increase text sizes for readability
  - Footer text too small - increase by at least 2px (currently 10-11pt)
  - Consider bumping main/regular text sizes throughout
  - OK to increase footer height if needed
- [ ] **Hover Labels**: Add tooltip labels to icon-only buttons
  - Stats toggle, Open in Notion, Settings, Refresh buttons
  - Use `.help()` modifier for native macOS tooltips

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
