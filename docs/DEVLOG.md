# Development Log

Running log of development sessions, decisions, and progress.

---

## 2026-01-13: Project Setup

### Initial App Shell
- Created SwiftUI macOS app project from scratch
- Set up dark mode UI with gradient background (charcoal to near-black)
- Used SF Mono font throughout for terminal/dev aesthetic
- Orange-to-pink gradient title, colored status card accents (cyan/orange/green)
- Keyboard hints footer showing TUI-style shortcuts (j/k, space, /, p)
- Hidden title bar for cleaner look (traffic lights still visible)

### Project Structure
```
GuitarPractice/
├── GuitarPracticeApp.swift   # Main entry, window config
├── ContentView.swift         # Placeholder UI with status cards
├── Assets.xcassets/          # App icon, accent color
└── Info.plist
```

### Documentation
- Created `PLAN.md` with 6-phase development roadmap
- Phases: Data Layer → Library View → Session Management → Practice Timer → Menu Bar → Polish

### Repository
- Initialized git, created GitHub repo: https://github.com/sohara/guitar-practice-swiftui (private)

### Tech Decisions
- **SwiftUI over AppKit**: Declarative, modern, first-class MenuBarExtra support
- **macOS 14.0 minimum**: Access to latest SwiftUI features
- **No external dependencies yet**: Start with URLSession for Notion API

---

## 2026-01-13: Phase 1 - Core Data Layer

### New Files
```
GuitarPractice/
├── Models/
│   ├── Types.swift       # LibraryItem, PracticeSession, PracticeLog, SelectedItem, LoadingState
│   └── AppState.swift    # Main app state management with @Published properties
└── Services/
    ├── Config.swift           # Notion database/data source IDs
    ├── KeychainService.swift  # Secure API key storage using Security framework
    └── NotionClient.swift     # Async/await Notion API client
```

### Features Implemented
- **Data Models**: All core types matching TUI implementation
- **KeychainService**: Save/get/delete API key securely
- **NotionClient**: Actor-based client with full CRUD operations
  - `fetchLibrary()` - Paginated library query
  - `fetchSessions()` - Sessions sorted by date desc
  - `fetchLogs(forSession:)` - Logs filtered by session
  - `createSession()` / `createLog()` - With template support
  - `updateLog()` / `deleteLog()` - For editing sessions
- **AppState**: ObservableObject managing:
  - Library and sessions loading states
  - Selected items array
  - API key presence detection
- **UI Updates**:
  - API key setup screen with secure input
  - Library list with item rows (type icon, name, artist, stats)
  - Header with live stats badges
  - Settings sheet for disconnecting
  - Loading and error states
  - Click to select items (green highlight)

### Technical Notes
- Used `actor` for NotionClient to ensure thread safety
- Property extractors mirror TUI's helper functions
- LoadingState enum with idle/loading/loaded/error cases
- Parallel data fetching with TaskGroup

### Bug Fix: Database IDs vs Data Source IDs
- Initial implementation used data source IDs for queries (matching TUI's SDK approach)
- REST API requires database IDs for `/databases/{id}/query` endpoint
- Fixed by switching to `Config.Notion.Databases.*` for all query operations
- Data source IDs are SDK-specific; database IDs work with raw REST API

### Next Steps
- Phase 2: Search/filter/sort for library
- Split view layout (Library | Selected)

---

## 2026-01-13: Phase 2 - Library View

### Features Implemented
- **NavigationSplitView Layout**: Library on left, Selected Items on right
  - Set minimum column widths (400pt library, 280pt selected) to prevent content truncation
- **Search**: Live filtering by name, artist, and tags
  - Press `/` to focus search field
  - Clear button (×) when text entered
- **Type Filter**: Dropdown to filter by All/Song/Exercise/Course Lesson
- **Sort Options**: Name, Last Practiced, Times Practiced
  - Click same option to toggle ascending/descending
  - Visual indicator (chevron) shows current direction
- **Keyboard Navigation**:
  - `↑`/`↓` or `j`/`k` to navigate library
  - `Space` to toggle selection
  - Orange highlight shows focused item
  - Auto-scroll to keep focused item visible
- **Selected Items Panel**:
  - Shows total planned time
  - Per-item time adjustment (+/- buttons)
  - Remove button per item
  - Clear all button
  - Empty state with instructions
- **Header Stats**: Now shows filtered/total count (e.g., "45/129") when filters active

### Bug Fix: Keychain Prompts
- Debug builds were prompting for keychain access on every launch
- Cause: Data Protection keychain is strict about app identity for unsigned builds
- Fix: Use legacy file-based keychain (`kSecUseDataProtectionKeychain: false`)

### Technical Notes
- `SortOption` enum for type-safe sort options
- `filteredLibrary` computed property chains search → type filter → sort
- `@FocusState` for search field focus management
- `ScrollViewReader` with `scrollTo()` for auto-scrolling to focused item
- `onKeyPress` modifiers for keyboard shortcuts

### Next Steps
- Phase 3: Session Management (pick/create sessions, save to Notion)

---

## 2026-01-13: Phase 3 - Session Management

### Features Implemented
- **Session Picker**: Dropdown menu to select existing sessions or create new ones
  - Sessions displayed by date (MMM d, yyyy format) instead of name
  - Checkmark indicator for currently selected session
  - "New Session..." option creates session named by current date
- **Session Loading**: Fetches practice logs for selected session from Notion
  - Converts logs to SelectedItems matched with library items
  - Loading spinner while fetching
- **Delta Saves**: Only syncs changes to Notion
  - Tracks dirty items (modified plannedMinutes or order)
  - Tracks deleted items for removal from Notion
  - Creates new logs for items not yet saved
  - Updates existing logs for modified items
- **Selected Items Panel**:
  - Drag and drop reordering with `.onMove`
  - Actual time display for practiced items
  - Completion indicator (checkmark) for items with actual time
  - Unsaved changes indicator (orange dot)
- **Dual Panel Focus System**:
  - `Tab` key switches focus between Library and Selected Items panels
  - Arrow keys (↑/↓) and j/k navigate whichever panel is focused
  - Orange highlight for focused library item (when library panel active)
  - Cyan highlight for focused selected item (when selected panel active)
- **Keyboard Shortcuts for Selected Items**:
  - `+`/`-` adjusts planned time on focused item
  - `Delete` removes focused item from session
  - `Enter` adds/removes item (library panel only)

### UX Refinements
- Single click focuses item, double-click or Enter toggles selection
- Click on selected item row sets panel focus and item focus
- `.focusable()` modifier required on main view for key events to work

### Bug Fix: Key Events Not Firing
- Symptom: Arrow keys and other shortcuts played error sound, no action
- Cause: View wasn't focusable, so key events weren't being handled
- Fix: Added `.focusable()` modifier to MainContentView

### Technical Notes
- `FocusedPanel` enum tracks which panel has keyboard focus
- `moveFocusUp()`/`moveFocusDown()` dispatch to appropriate panel based on focus
- Session footer shows Save button (orange when unsaved, gray when clean)
- `⌘S` keyboard shortcut for save

### Future Enhancement Ideas
- `Ctrl-F`/`Ctrl-B` for page up/down in library list

### Next Steps
- Phase 4: Practice Timer (full-window timer mode, track actual time)
