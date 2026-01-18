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

### Phase 3: Session Management ✅
- [x] Session picker (sidebar or dropdown)
- [x] Create new session (auto-named by date)
- [x] Selected items pane showing:
  - Item name and planned time
  - Actual time (if practiced)
  - Completion status indicator
- [x] Add items from library (double-click or space)
- [x] Remove items from session
- [x] Adjust planned time (+/- buttons or direct input)
- [x] Reorder items (drag and drop)
- [x] Delta save (only sync changed items to Notion)

### Phase 4: Practice Timer ✅
- [x] Full-window practice mode
- [x] Large timer display (MM:SS)
- [x] Current item name prominent
- [x] Start/pause/resume controls
- [x] Finish with confirmation dialog
- [x] Track actual time (stored as decimal minutes)
- [x] Resume from previous actual time if re-practicing
- [x] Keyboard shortcuts (space = pause, enter = finish)

### Phase 5: Menu Bar Integration ✅
- [x] MenuBarExtra showing timer when practicing
- [x] Display current item name
- [x] Pause/resume/finish controls in dropdown
- [x] Timer continues when main window closed
- [x] Click to bring main window to front

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
- [x] Day cell stats: Show actual practice time on each day (e.g., "45m" or "1h")
- [x] Day cell item count: Falls back to item count if no actual time yet
- [x] Heat map intensity: Green gradient based on practice duration (0-60min scale)
- [x] Tooltip/hover: Shows date, item count, and practiced/planned time on hover
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

#### 7.5 UI Polish ✅
- [x] **Flexible Split View**: Improve two-pane layout
  - Replaced NavigationSplitView with HSplitView for native draggable divider
  - Default to ~50/50 split (equal ideal widths)
  - User-adjustable divider position
  - Minimum widths: 300pt library, 280pt session/stats
- [x] **Typography Improvements**: Increase text sizes for readability
  - Footer text increased from 10pt to 12pt
  - KeyHint labels and action text now more readable
- [x] **Hover Labels**: Add tooltip labels to icon-only buttons
  - Settings button: "Settings"
  - Refresh button: "Refresh Data"
  - (Stats toggle and Open in Notion already had tooltips)

### Phase 8: Code Organization

#### 8.1 Refactor ContentView.swift ✅
ContentView.swift was 1500+ lines and has been split into separate files for maintainability.

**Target structure:**
```
GuitarPractice/
├── Views/
│   ├── ContentView.swift           # Root only (~30 lines)
│   ├── MainContentView.swift       # Split view layout + key handlers
│   ├── Header/
│   │   └── HeaderView.swift
│   ├── Library/
│   │   ├── LibrarySidebarView.swift
│   │   ├── FilterBarView.swift
│   │   ├── LibraryListView.swift
│   │   └── LibraryRowView.swift
│   ├── Session/
│   │   ├── SessionPanelView.swift
│   │   ├── CalendarNavigatorView.swift
│   │   ├── SessionDetailView.swift
│   │   ├── SessionEditingModeView.swift
│   │   └── SessionViewingModeView.swift
│   ├── Practice/
│   │   └── PracticeView.swift
│   ├── Stats/
│   │   └── StatsDashboardView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── APIKeySetupView.swift
│   └── Common/
│       ├── FooterView.swift
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       └── Skeletons.swift
```

**Notes:**
- No code changes needed - just moving structs to new files
- Swift doesn't require imports for types in the same module
- Update Xcode project file to include new files

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

## Phase 9: Future Enhancements

### 9.1 Recent Items Filter ✅
Add a dedicated filter to show only items practiced in the last 7 days.

- **Rationale**: While "Sort by Last Practiced" shows recent items first, a filter reduces the list from 100+ items to just 10-15, making it faster to rebuild similar sessions
- **UI**: Toggle button with clock icon next to type filter (cyan highlight when active)
- **Implementation**: Filter `filteredLibrary` by `lastPracticed` within 7 days

### 9.2 Practice Log Notes ✅ (partial)
Add notes field to Practice Logs for tracking progress over time.

- **Rationale**: Users want to record observations like "got to 80bpm" tied to specific practice sessions, not just global item notes
- **Data model**: ✅ `notes: String?` field added to Practice Logs database in Notion
- **Backend**: ✅ `PracticeLog`, `CachedPracticeLog`, `NotionClient`, `CacheService` updated
- **UI - Timer View**: ✅ Add/Edit note while practicing (collapsed card with yellow accent)
- **UI - Session List**: ✅ Yellow note icon indicator (read-only)
- **UI - View Mode**: ✅ Notes displayed with yellow icon

### 9.3 Notes History ✅
Show historical notes for the current item in the timer view.

- **Rationale**: When practicing, it's helpful to see what you noted last time
- **Data requirement**: ✅ Fetch all PracticeLogs for current LibraryItem via `fetchLogsForItem(itemId:)`
- **UI - Timer View**: ✅ Unified `NotesCard` component with scrollable list
- **Visual design**: ✅ Each note is a `NoteRow` with identical styling, differentiated by accent color:
  - Current note: Yellow accent bar, yellow label ("TODAY"), editable
  - Previous notes: Gray accent bar, gray label (date), read-only
- **Implementation**:
  1. ✅ Added `fetchLogsForItem(itemId:)` to NotionClient
  2. ✅ Fetch on practice start and when switching items (state in AppState)
  3. ✅ Unified `NotesCard` with max height (180px) and scrolling
  4. ✅ Click to edit current note, Enter to save, Escape to cancel/revert

### 9.4 ✅ Header Reorganization (Complete)
Moved contextual stats from global header to their respective views.

**Changes made**:
1. **Library Items count** → Added to FilterBarView (shows "X/Y" when filtered, "N items" otherwise)
2. **Items in Session** → Removed from header (already shown in SessionDetailHeaderView)
3. **Practice Sessions count** → Added "total" stat to CalendarNavigatorView mini stats (alongside streak and "this month")
4. **Header simplified**: App title (left) + global actions (Stats toggle, Open in Notion, Settings, Refresh)
5. **StatBadge.swift deleted** → No longer needed

### 9.5 Other Ideas (Unprioritized)
- **Jump to Today**: ✅ Press `T` to return to today's date in calendar
- **Practice Goals**: ✅ Daily goal per session (default 60 min), progress bar in header, goal achievement stats
- **Session Templates**: Save/load sets of items for quick session creation (see Copy Session below - probably a better approach)
- **Copy Session to Today**: ✅ Duplicate a past session as today's session for quick setup
- **Per-Item Progress Chart**: Visualize practice time trends for specific items

### 9.6 Copy Session to Today ✅

Copy an existing session's items to today's session, providing a quick way to recreate a similar practice routine without abstract template management.

**Rationale**: More practical than session templates because:
- No separate template CRUD UI needed
- Concrete action: "copy last Tuesday's session" vs abstract "load Template X"
- Source data already exists (past sessions visible in calendar)
- Zero new data to maintain

**User Flow**:
1. Browse calendar to find a past session to copy
2. Trigger "Copy to Today" via context menu or action button
3. App creates today's session (or uses existing empty one)
4. App creates new `PracticeLog` entries copying `itemId`, `plannedMinutes`, `order`
5. New logs have null `actualMinutes` and empty `notes` (fresh start)
6. User can edit the copied session before practicing

**Implementation**:
- `AppState.copySessionToToday(fromSessionId:)` method
- Fetch logs for source session via existing `NotionClient.fetchLogs(forSession:)`
- Create/select today's session via existing `createSession()` or `selectDate()`
- Create new logs via existing `NotionClient.createLog()` for each source item
- UI trigger: context menu on calendar dates or "Copy to Today" button in read-only session view

### 9.7 In-App Content Viewer (GitHub Issue #19)
Display Notion page content (sheet music, tabs, audio backing tracks) directly in the practice view.

**Detailed plan:** See [docs/CONTENT_VIEWER_PLAN.md](docs/CONTENT_VIEWER_PLAN.md)

**Summary:**
- Fetch Notion blocks via API, render as HTML in WKWebView
- No third-party dependencies (pure Swift + WebKit)
- Supports images, audio with player controls, headings, lists, toggle blocks
- Content panel visible by default in practice mode, toggleable with ⌘I
- Handles S3 signed URL expiration by fetching fresh on practice start

## Architecture Notes

### Unified DataService (Future Consideration)

**Current State**: The app uses separate `NotionClient` and `CacheService` with AppState manually coordinating between them. Most write operations update Notion but not the cache, except for a few operations like `updateSessionGoal()` that do both.

**Observation**: This inconsistency led to issue #12 (calendar view not updating after practice). The minimal fix added `CacheService.updateLog()` and called it after saving to Notion in `saveCurrentItemToNotion()`.

**Potential Refactor**: Create a unified `DataPersistenceService` that wraps both services:

```swift
@MainActor
final class DataPersistenceService {
    private let notionClient: NotionClient
    private let cacheService: CacheService

    // All writes go through here - both Notion and cache updated atomically
    func updateLog(logId: String, plannedMinutes: Int, actualMinutes: Double?, order: Int, notes: String?) async throws {
        // 1. Update Notion (source of truth)
        try await notionClient.updateLog(logId: logId, plannedMinutes: plannedMinutes, actualMinutes: actualMinutes, order: order, notes: notes)

        // 2. Update local cache (guaranteed to happen if Notion succeeds)
        cacheService.updateLog(logId: logId, plannedMinutes: plannedMinutes, actualMinutes: actualMinutes, order: order, notes: notes)
    }

    // Similar patterns for createLog, deleteLog, saveSessions, etc.
}
```

**Tradeoffs**:

| Pro | Con |
|-----|-----|
| Single point of coordination | More abstraction/indirection |
| Guarantees cache stays in sync | Migration effort for existing code |
| Clearer API for AppState | May need to handle partial failures |
| Easier to add features like retry/rollback | Another layer to debug |

**Assessment**: Worth considering if the inconsistency keeps causing bugs. For now, the minimal fix (updating cache after specific writes) is pragmatic and follows the pattern already used by `updateSessionGoal()`. A full refactor would be warranted if:
- Multiple additional cache sync bugs arise
- Offline support is added (would need transaction queue anyway)
- The codebase grows significantly larger

**Related Files**:
- `Services/NotionClient.swift` - Notion API operations
- `Services/CacheService.swift` - SwiftData local cache
- `Models/AppState.swift` - Currently coordinates both manually

## References

- [SwiftUI Handoff Doc](../guitar-tui/docs/SWIFTUI_HANDOFF.md)
- [Architecture Sketch](../guitar-tui/docs/NATIVE_MAC_APP.md)
- [TUI Source Code](../guitar-tui/src/)
