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

---

## 2026-01-13: Phase 4 - Practice Timer

### Features Implemented
- **Full-Screen Practice Mode**: Dedicated view for focused practice
  - Large item name and artist display
  - Type icon with color coding
  - Progress indicator (e.g., "2 of 5")
- **Countdown Timer**: Shows remaining time from planned minutes
  - Large MM:SS display
  - Switches to orange "OVERTIME" mode when time exceeded
  - Elapsed time shown below (e.g., "Elapsed: 2:30 / 5:00")
- **Timer Controls**:
  - Start/Pause/Resume with visual "PAUSED" indicator
  - Automatic start when entering practice mode
  - Timer runs at 0.1s precision using async Task
- **Practice Flow**:
  - **Finish** (Enter): Saves actual time to Notion immediately, exits to session view
  - **Next** (N): Saves actual time to Notion immediately, moves to next item
  - **Skip** (S): Moves to next item without saving time
  - **Exit** (Esc): Exits practice mode without saving current item
- **Auto-Save to Notion**: Actual time saved immediately on Finish/Next (no manual save required)
- **Resume Support**: If re-practicing an item, timer resumes from previous actual time

### Keyboard Shortcuts
| Key | Action |
|-----|--------|
| Space | Pause/Resume timer |
| Enter | Finish & Exit (save time, return to session) |
| N | Save & Next (save time, continue to next item) |
| S | Skip (no save, move to next) |
| Esc | Exit practice mode |

### Bug Fixes
- **Focus Ring on Load**: Red rectangle visible on app launch
  - Cause: Default macOS focus ring on `.focusable()` view
  - Fix: Added `.focusEffectDisabled()` to hide system focus indicator
- **Practice View Key Events**: Same focusable issue as main view
  - Fix: Added `@FocusState` with `.focused()` and `.onAppear { isFocused = true }` to auto-focus

### Technical Notes
- Practice state in AppState: `isPracticing`, `practiceItemIndex`, `practiceElapsedSeconds`, `isTimerRunning`
- Timer uses `Task` with `Task.sleep(nanoseconds:)` for 0.1s updates
- `saveCurrentItemToNotion()` called on finish/next for immediate persistence
- Practice button added to session footer with `⌘P` shortcut

### Next Steps
- Phase 5: Menu Bar Integration (timer in menu bar when practicing)

---

## 2026-01-13: Phase 5 - Menu Bar Integration

### Features Implemented
- **MenuBarExtra**: Always-visible menu bar icon with contextual content
  - Guitar icon when idle, guitar icon + countdown timer when practicing
  - `.monospacedDigit()` for stable timer display without width jitter
- **Idle Menu**:
  - "Show Window" button to bring app to foreground
  - "Quit" with ⌘Q keyboard shortcut
- **Practicing Menu**:
  - Current item name and artist display
  - Timer showing remaining time (or overtime duration)
  - Progress indicator (e.g., "2 of 5")
  - Pause/Resume control
  - "Save & Next" to continue to next item
  - "Finish & Exit" to save and return to session view
  - "Exit Practice" to cancel without saving
  - "Show Window" to bring main window to front

### Architecture Changes
- **Lifted AppState to App level**: `@StateObject` in `GuitarPracticeApp` shared between WindowGroup and MenuBarExtra
- **ContentView accepts AppState**: Changed from `@StateObject` to `@ObservedObject var appState: AppState`
- **AppDelegate for window management**:
  - `applicationDidFinishLaunching` brings window to front on launch
  - `applicationShouldHandleReopen` shows window when clicking dock icon
  - Uses `orderFrontRegardless()` to ensure window appears even when app wasn't active

### Bug Fixes
- **Window not appearing with MenuBarExtra**:
  - Symptom: Adding MenuBarExtra caused main window to not show
  - Investigation: Tried `isInserted` binding, various activation policies
  - Fix: Always-visible MenuBarExtra with AppDelegate handling window activation
- **Window not coming to foreground on launch**:
  - Fix: `DispatchQueue.main.async` in `applicationDidFinishLaunching` with `orderFrontRegardless()`

### Technical Notes
- `LSUIElement = false` in Info.plist keeps app in dock and app switcher
- MenuBarExtra label uses HStack with Image and Text for timer display
- Timer state observed reactively - menu bar updates every 0.1s during practice

### Future Enhancement Ideas
- Format actual time as MM:SS instead of decimal minutes (e.g., "2:30" instead of "2.5m")
- `Ctrl-F`/`Ctrl-B` for page up/down in library list
- Open in Notion (⌘O) - planned for Phase 6

### Next Steps
- Phase 6: Polish (keyboard shortcuts refinement, Open in Notion, visual polish)

---

## 2026-01-13: Phase 6 - Polish

### Features Implemented
- **Open in Notion (⌘O)**: Opens focused item in Notion app
  - Uses `notion://` protocol to launch native app instead of browser
  - Works for both library items and selected session items based on focused panel
- **Time Format Improvement**: Actual time now displays as MM:SS (e.g., "2:30") instead of decimal minutes ("2.5m")
  - Added `formatMinutesAsTime()` helper function
  - Updated session header and selected item rows
- **Page Navigation (Ctrl-F/Ctrl-B)**: Jump 10 items at a time in library list
  - Ctrl-F for page down, Ctrl-B for page up
  - Uses `onKeyPress` with modifier check
- **Loading Skeletons**: Shimmer placeholders while data loads
  - `ShimmerView` with animated gradient sweep
  - `SkeletonLibraryRow` mimics actual row layout
  - `SkeletonFilterBar` for search/filter area
- **Auto-Select Today's Session**: On app launch, automatically selects session matching today's date if one exists

### Performance Improvement
- **No Reload After Practice**: Added `loadDataIfNeeded()` that skips fetch if data already loaded
  - Prevents unnecessary API calls when returning from practice mode
  - `refresh()` still forces full reload when explicitly requested

### Keyboard Shortcuts Added
| Key | Action |
|-----|--------|
| ⌘O | Open focused item in Notion app |
| ⌘R | Refresh data (already existed) |
| Ctrl-F | Page down in library (10 items) |
| Ctrl-B | Page up in library (10 items) |

### Technical Notes
- `NSWorkspace.shared.open()` with `notion://notion.so/{id}` URL scheme
- `Calendar.startOfDay(for:)` for date comparison in session auto-select
- Footer updated to show current keyboard hints including ^F/B and ⌘O

### Phases 1-6 Complete
All 6 phases implemented:
1. ✅ Core Data Layer
2. ✅ Library View
3. ✅ Session Management
4. ✅ Practice Timer
5. ✅ Menu Bar Integration
6. ✅ Polish

---

## 2026-01-13: Phase 7 Planning

### Implementation Order Decided
After analyzing dependencies between Phase 7 features, settled on this order:

1. **Timer Alert** (7.1) - Quick win, immediately useful, introduces AVFoundation + UserNotifications
2. **SwiftData Cache** (7.2) - Foundational data layer enabling efficient local queries
3. **Calendar View** (7.3) - Leverages cache for date-range queries
4. **Stats Dashboard** (7.4) - Leverages cache for aggregation queries
5. **UI Polish** (7.5) - Flexible split view + typography improvements

### Rationale
- SwiftData is foundational because Calendar and Stats need to query historical data
- Without cache: each view would hit Notion API repeatedly
- With cache: instant queries via SwiftData `@Query` predicates
- Timer Alert first as warm-up - quick win that delivers immediate value

### Next Steps
- Implement Timer Alert (7.1): sound chime + macOS notification when practice time elapses

---

## 2026-01-13: Phase 7.1 - Timer Alert

### Features Implemented
- **Overtime Detection**: Detects when timer crosses from countdown to overtime
  - `hasTriggeredOvertimeAlert` flag prevents repeated alerts
  - Checks transition in timer loop: `wasNotOvertime && isNowOvertime`
- **Sound Alert**: Plays system sounds when time elapses
  - `NSSound.beep()` for immediate feedback
  - `NSSound(named: "Glass")` for more distinct chime
- **macOS Notification**: Shows notification banner
  - Title: "Practice Time Complete"
  - Body: "{item name} - Time's up!"
  - Uses `UserNotifications` framework
- **Permission Request**: Requests notification permission on app launch
  - Added to `AppDelegate.applicationDidFinishLaunching`
  - Requests `.alert` and `.sound` permissions

### Technical Details
- Alert only triggers once per item (reset on `startPractice()` and `moveToNextPracticeItem()`)
- If resuming an item already in overtime, alert is pre-marked as triggered
- Works when app is backgrounded / menu bar only view

### Files Changed
- `GuitarPractice/Models/AppState.swift` - Alert logic and trigger
- `GuitarPractice/GuitarPracticeApp.swift` - Permission request

### Next Steps
- Phase 7.2: SwiftData local cache (foundational)

---

## 2026-01-13: Phase 7.2 - SwiftData Local Cache

### Features Implemented
- **SwiftData Models**: Cached versions of all data types
  - `CachedLibraryItem`, `CachedPracticeSession`, `CachedPracticeLog`
  - `CacheMetadata` for tracking last update timestamps
  - Use `@Attribute(.unique)` for ID-based upserts
- **CacheService**: Manages all cache operations
  - `loadLibraryItems()` / `saveLibraryItems()` - full library sync
  - `loadSessions()` / `saveSessions()` - sessions list sync
  - `loadLogs(forSession:)` / `saveLogs(_:forSession:)` - per-session logs
  - Handles insert/update/delete to keep cache in sync with Notion
- **Cache-First Loading Strategy**:
  - On app launch, load from cache first (instant display)
  - Then fetch from Notion in background
  - Update cache when fresh data arrives
  - If Notion fails but cache exists, keep showing cached data
- **Silent Background Refresh**: No loading spinner if cached data is displayed

### Architecture
```
ContentView
  └─ .task { setupCache → loadDataIfNeeded }
       └─ Load from cache (instant)
       └─ Fetch from Notion (background)
       └─ Save to cache (persist)
```

### Files Added
- `GuitarPractice/Models/CachedModels.swift` - SwiftData `@Model` classes
- `GuitarPractice/Services/CacheService.swift` - Cache operations

### Files Modified
- `GuitarPractice/GuitarPracticeApp.swift` - ModelContainer setup
- `GuitarPractice/ContentView.swift` - Pass modelContext to AppState
- `GuitarPractice/Models/AppState.swift` - Cache-first loading logic

### Technical Notes
- SwiftData stores data in `~/Library/Application Support/` automatically
- Uses predicates for efficient session-specific log queries
- Tags stored as JSON-encoded Data (SwiftData doesn't support [String] directly)
- `@Environment(\.modelContext)` propagated through view hierarchy

### Next Steps
- Phase 7.3: Calendar View (leverages cache for date-range queries)

---

## 2026-01-13: Phase 7.3 - Calendar View (Initial)

### Features Implemented
- **Calendar Sheet**: Accessible via calendar icon in header
  - Month grid with prev/next navigation
  - Days with practice sessions highlighted in green
  - Today's date outlined in cyan
  - Currently selected session highlighted
  - Click a day to load that session
- **Stats Footer**: Shows at-a-glance metrics
  - Sessions this month count
  - Total time this month (estimated)
  - Current practice streak (consecutive days)
- **Streak Calculation**: Counts consecutive days with sessions

### Files Modified
- `GuitarPractice/Models/AppState.swift` - Added `isCalendarPresented` state
- `GuitarPractice/ContentView.swift` - Added CalendarView, CalendarDayView, CalendarStatView

### Future Improvements (from user feedback)
- Convert calendar from popup sheet to main view/tab
- Show session summary info (items practiced, total time) per day
- Eventually make calendar the primary way to view practice history
- Heat map intensity based on practice duration

### Next Steps
- Phase 7.4: Stats Dashboard
- Phase 7.5: UI Polish (flexible split view, typography)

---

## 2026-01-13: Phase 7.3 - Calendar as Main View (Complete)

### Major Refactor
Converted the calendar from a popup sheet to the primary session navigation interface. The calendar now lives permanently in the right panel, replacing the session dropdown as the main way to navigate practice history.

### Architecture Changes
**Old Structure (Right Panel):**
```
SelectedItemsView
├── SessionHeaderView (dropdown picker)
├── Selected items list
└── SessionFooterView
```

**New Structure (Right Panel):**
```
SessionPanelView
├── CalendarNavigatorView (compact month calendar)
│   ├── Month navigation
│   ├── Day grid with practice indicators
│   └── Mini stats (streak, monthly count)
└── SessionDetailView
    ├── SessionDetailHeaderView (date, summary stats)
    └── Content based on mode:
        ├── NoSessionView (create option)
        ├── SessionViewingModeView (read-only for past)
        └── SessionEditingModeView (full edit)
```

### New Components Created
- `SessionPanelView` - Container combining calendar + detail
- `CalendarNavigatorView` - Compact embedded calendar
- `CalendarNavigatorDayView` - Individual day cell
- `MiniStatView` - Compact stat display (streak, monthly)
- `SessionDetailView` - Session content switcher
- `SessionDetailHeaderView` - Date and summary display
- `NoSessionView` - Empty state with create option
- `SessionViewingModeView` - Read-only past session view
- `SessionItemReadOnlyRow` - Read-only item display
- `SessionEditingModeView` - Full edit mode (reuses existing components)
- `SessionEditingFooterView` - Save/practice buttons

### AppState Changes
- Added `SessionViewMode` enum (`.viewing`, `.editing`)
- Added `selectedDate: Date` - Currently selected calendar date
- Added `sessionViewMode: SessionViewMode` - Current view mode
- Added `displayedMonth: Date` - Month shown in calendar
- Added `selectDate(_:)` - Select date and load associated session
- Added `switchToEditMode()` - Switch from viewing to editing
- Added `sessionForDate(_:)` - Find session for a date
- Added `isSelectedDateToday`, `isSelectedDatePast` computed properties
- Added `createSessionForSelectedDate()` - Create session for selected date

### Behavior
| Scenario | View Mode | Actions |
|----------|-----------|---------|
| Past session exists | viewing | View items read-only, "Edit" button |
| Past session, after "Edit" | editing | Full edit capabilities |
| Today's session exists | editing | Full edit (default) |
| Today, no session | - | "Start Session" button |
| Past date, no session | - | "No practice recorded" message |
| Future date, no session | - | "Create Session" button |

### Files Modified
- `GuitarPractice/Models/AppState.swift` - Added view mode and date selection logic
- `GuitarPractice/ContentView.swift` - Added all new view components, removed calendar sheet

### Removed
- Calendar button from HeaderView (calendar now always visible)
- Calendar sheet presentation (`.sheet(isPresented: $appState.isCalendarPresented)`)

### Technical Notes
- Old `SelectedItemsView` and related components left in codebase for reference
- Old `CalendarView` (popup version) also retained
- Calendar grid uses smaller cells (28pt height vs 44pt in popup)
- View mode automatically determined by date when selecting

### Future Calendar Enhancements (documented for later)
- **Day cell stats**: Show actual/planned time directly on each calendar day (e.g., "45m" or "45/60m")
- **Day cell item count**: Show number of items practiced per day
- **Heat map intensity**: Color gradient based on practice duration (light green → dark green)
- **Tooltip/hover**: Quick summary on hover before clicking
- **Week view**: More compact horizontal layout option
- **Collapsible calendar**: Toggle to hide/show the calendar section

### Next Steps
- Phase 7.4: Stats Dashboard
- Phase 7.5: UI Polish

---

## 2026-01-14: App Icon

### Custom App Icon Added
Created custom app icon for the macOS app, replacing the default placeholder.

### Design
- **Final choice**: Dark guitar with green neon accents and pick
- Generated using Google Gemini AI image generator
- Applied macOS Big Sur rounded corner mask (22.37% radius)

### Tools Created
- `fix_corners.swift` - Applies transparent rounded corners to square source images
  ```bash
  swiftc -o fix_corners fix_corners.swift -framework AppKit -framework CoreGraphics
  ./fix_corners input.png output.png
  ```

### Alternative Explored
- `icon/guitar-pick-orange` branch - Programmatically generated white guitar pick on orange gradient
- Created `generate_icon.swift` for fully programmatic icon generation

### Technical Notes
- macOS app icons require 10 PNG files (16-1024px at 1x and 2x scales)
- AI-generated images often have baked-in rounded corners - request square images instead
- Used `sips` for resizing, custom Swift script for corner masking

### Files Added
- `GuitarPractice/Assets.xcassets/AppIcon.appiconset/` - All icon sizes
- `fix_corners.swift` - Corner mask utility

---

## 2026-01-14: Phase 7.5 - Stats Dashboard

### Features Implemented
- **Stats Toggle Button**: Chart icon in header toggles between session view and stats dashboard
- **Stats Dashboard View**: Scrollable panel with multiple stat sections
  - Overview cards: Total time, sessions, items practiced, average session
  - Streak cards: Current streak and longest streak
  - Recent activity: Last 7 days bar chart
  - Type breakdown: Time spent by item type (Song/Exercise/Course Lesson)
  - Top items: By time or count (toggleable)
  - Weekly trend: 8-week bar chart

### New Files
- `GuitarPractice/Services/StatsService.swift` - Computes all aggregated statistics
- Stats views in ContentView.swift:
  - `StatsDashboardView` - Main container
  - `StatsOverviewSection` - Overview cards grid
  - `StatCard` - Single stat display card
  - `StreakCard` - Streak display with suffix
  - `RecentActivitySection` - 7-day bar chart
  - `RecentDayBar` - Single day bar
  - `TypeBreakdownSection` - Item type distribution
  - `TypeBreakdownRow` - Single type row with progress bar
  - `TopItemsSection` - Most practiced items
  - `TopItemRow` - Single item row
  - `WeeklyTrendSection` - 8-week trend chart
  - `WeeklyTrendBar` - Single week bar

### CacheService Updates
- Added `loadAllLogs()` - Fetches all practice logs for stats aggregation

### AppState Updates
- Added `isShowingStats: Bool` - Toggle for stats view
- Added `practiceStats: PracticeStats?` - Computed stats data
- Added `statsService: StatsService` - Service instance
- Added `refreshStats()` - Computes stats from cached data
- Added `toggleStatsView()` - Toggles and refreshes stats

### Stats Computed
- **Total practice time**: Sum of all actual minutes
- **Total sessions**: Count of all sessions
- **Items practiced**: Unique items with practice time
- **Average session**: Mean time per session
- **Current/longest streak**: Consecutive practice days
- **This week/month/30 days**: Time in period
- **Top items by time**: Sorted by total practice time
- **Top items by count**: Sorted by practice count
- **Minutes by type**: Grouped by Song/Exercise/Course Lesson
- **Weekly trend**: 8 weeks of practice time
- **Recent days**: 7 days with time and item count

### Technical Notes
- Stats computed on-demand when toggled (not on every data refresh)
- Uses cached data from SwiftData for efficient aggregation
- Streak calculation handles today/yesterday edge cases
- Bar charts scale dynamically based on max values

### UI Design
- Cards use colored backgrounds with opacity (0.1 fill, 0.2 stroke)
- Monospace "SF Mono" font throughout for consistency
- Cyan highlights for current week/today
- Toggle between time/count views for top items

### Next Steps
- Phase 7.5: UI Polish (flexible split view, typography)

---

## 2026-01-14: Phase 7.5 - UI Polish

### Features Implemented
- **Hover Labels (Tooltips)**: Added `.help()` modifiers to icon-only buttons
  - Settings button: "Settings"
  - Refresh button: "Refresh Data"
  - (Stats toggle and Open in Notion already had tooltips)
- **Typography Improvements**: Increased footer text size
  - All footer text increased from 10pt to 12pt
  - KeyHint key labels and action text now more readable
  - "Guitar Practice" footer branding increased to 12pt
- **Flexible Split View**: Replaced `NavigationSplitView` with native `HSplitView`
  - User-adjustable divider position (draggable)
  - Defaults to roughly 50/50 split (equal ideal widths of 450pt)
  - Minimum widths: 300pt for library, 280pt for session/stats panel
  - More natural macOS behavior

### Technical Notes
- `HSplitView` provides native macOS split pane with draggable divider
- `.help("text")` modifier shows native macOS tooltips on hover
- Updated both main content view and loading skeleton view for consistency

### Files Modified
- `GuitarPractice/ContentView.swift` - Tooltip modifiers, font sizes, split view conversion

### All Phase 7 Items Complete
1. ✅ Timer Alert (7.1)
2. ✅ SwiftData Cache (7.2)
3. ✅ Calendar View (7.3)
4. ✅ Stats Dashboard (7.4)
5. ✅ UI Polish (7.5)

---

## 2026-01-14: Phase 8.1 - ContentView Refactoring

### Code Organization
Refactored `ContentView.swift` from **1500+ lines to 40 lines** by extracting views into separate files organized by feature area.

### New Directory Structure
```
GuitarPractice/Views/
├── MainContentView.swift      # Split view layout + keyboard handlers
├── Header/
│   └── HeaderView.swift
├── Library/
│   ├── LibrarySidebarView.swift
│   ├── FilterBarView.swift
│   ├── LibraryListView.swift
│   └── LibraryRowView.swift
├── Session/
│   ├── SessionPanelView.swift
│   ├── CalendarNavigatorView.swift
│   ├── SessionDetailView.swift
│   ├── SessionViewingModeView.swift
│   └── SessionEditingModeView.swift
├── Practice/
│   └── PracticeView.swift
├── Stats/
│   └── StatsDashboardView.swift
├── Settings/
│   ├── SettingsView.swift
│   └── APIKeySetupView.swift
└── Common/
    ├── FooterView.swift
    ├── LoadingView.swift
    ├── ErrorView.swift
    ├── Skeletons.swift
    └── Helpers.swift
```

### Files Created
- 21 new Swift files under `GuitarPractice/Views/`
- Updated Xcode project file to include all new files

### Technical Notes
- No functional changes - pure code organization refactor
- Each view struct moved to its own file
- Related views grouped in subdirectories by feature
- `formatMinutesAsTime()` helper moved to `Common/Helpers.swift`

---

## 2026-01-14: Calendar Enhancements

### Features Implemented
- **Day Cell Stats**: Calendar days now show actual practice time (e.g., "45m" or "1h")
  - Falls back to item count if no actual time recorded yet
  - Compact display fits within the day cell
- **Heat Map Intensity**: Green gradient shows practice duration at a glance
  - Intensity scales from 0-60 minutes for full saturation
  - Light green (short practice) to dark green (long practice)
  - Sessions with no actual time yet show very light green
- **Hover Tooltips**: Native macOS tooltips show quick summary on hover
  - Date, item count, and practiced/planned time
  - Shows before clicking for quick scanning

### New Types
- `DaySummary` in `Types.swift` - Contains itemCount, plannedMinutes, actualMinutes
  - `intensity` computed property for heat map (0.0 to 1.0)
  - `timeLabel` computed property for compact display (e.g., "45m", "1h", "1h30")

### AppState Changes
- Added `daySummaries(for month: Date)` - Computes summaries for all sessions in a month
- Added `daySummary(for date: Date)` - Convenience method for single date lookup

### CalendarNavigatorView Changes
- Day cells increased from 28pt to 36pt height to accommodate stats
- `CalendarNavigatorDayView` now accepts optional `DaySummary` instead of `hasSession` bool
- Background color now uses heat map intensity for practiced days
- `.help()` modifier provides native tooltip on hover

### Technical Notes
- Day summaries computed on-demand from cached session logs
- No additional API calls - leverages existing SwiftData cache
- Heat map caps at 60 minutes for max intensity to avoid visual saturation

### Follow-up Fixes
- **Increased text sizes** - Day numbers 10pt→13pt, time labels 7pt→10pt
- **Cell height** - Increased from 28pt to 44pt for better readability
- **Cell spacing** - Increased from 2pt to 6pt for less cramped appearance
- **Time format** - Changed from "1h5" to "1h 5m" for clarity
- **Streak bug fix** - Now correctly counts streak from yesterday if no practice today

---

## 2026-01-14: Phase 9.1 - Recent Items Filter

### Features Implemented
- **Recent Items Toggle**: Filter to show only items practiced in the last 7 days
  - Toggle button with clock icon in filter bar
  - Cyan highlight when filter is active
  - Tooltip: "Show only items practiced in last 7 days"
  - Reduces library list from 100+ items to ~10-15 recent items

### Files Modified
- `GuitarPractice/Models/AppState.swift` - Added `showRecentOnly` property, updated `filteredLibrary`
- `GuitarPractice/Views/Library/FilterBarView.swift` - Added Recent toggle button

### Technical Notes
- Filter applies before search text and type filters
- Uses `Calendar.current.date(byAdding: .day, value: -7, to: Date())` for 7-day cutoff
- Items with no `lastPracticed` date are excluded when filter is active

---

## 2026-01-14: Phase 9.3 - Notes History

### Features Implemented
- **Notes History in Timer View**: Shows previous practice notes for the current item while practicing
- **Unified NotesCard Component**: Single card containing current + historical notes with consistent styling
- **Visual Design**: Each note is a `NoteRow` with identical structure, differentiated by accent color:
  - Current note: Yellow accent bar, "TODAY" label, editable on click
  - Previous notes: Gray accent bar, date label (e.g., "JAN 12"), read-only
- **Scrollable Container**: Max height of 180px with scroll for many notes
- **Edit UX**:
  - Click current note to edit inline
  - Enter or "Save" button to save
  - Escape to cancel and revert changes

### New Files/Components
- `NotesCard` - Container component for all notes
- `NoteRow` - Reusable row component for individual notes
- `HistoricalNote` struct in `Types.swift` - Represents a past note with date

### NotionClient Changes
- Added `fetchLogsForItem(itemId:)` - Queries Practice Logs filtered by Item relation

### AppState Changes
- Added `currentItemNotesHistory: [HistoricalNote]` - Cached history for current item
- Added `isLoadingNotesHistory: Bool` - Loading state
- Added `fetchNotesHistoryForCurrentItem()` - Fetches and filters notes
- History fetched on practice start and when switching items
- History cleared on practice end

### Bug Fix
- Notes weren't persisting to Notion - `saveCurrentItemToNotion()` was missing the `notes` parameter in the `updateLog()` call

### Design Evolution
Started with separate components (current note card + collapsible previous notes section), then unified into single `NotesCard` after feedback:
1. **First iteration**: Separate `PracticeNotesSection` + `PreviousNotesSection` components
2. **Second iteration**: Unified card with collapsible disclosure for history
3. **Final iteration**: Fully unified with identical `NoteRow` styling, no collapsing, scrollable

### Technical Notes
- History excludes current session's log (filter by sessionId)
- History only includes logs with non-empty notes
- History sorted by date descending (most recent first)
- Joins logs with sessions to get dates for display

---

## 2026-01-14: Header Reorganization (9.4) ✅

Moved contextual stats from global header to their respective views for better information architecture.

### Changes Made
1. **HeaderView.swift** - Removed StatBadge components (library items, sessions, items in session)
2. **FilterBarView.swift** - Added library count at end of filter row (shows "X/Y" when filtered, "N items" otherwise)
3. **CalendarNavigatorView.swift** - Added "total" sessions count to mini stats (alongside streak and "this month")
4. **StatBadge.swift** - Deleted (no longer needed)

### Header Now Contains
- App title (left)
- Stats toggle, Open in Notion, Settings, Refresh buttons (right)

---

## 2026-01-14: Keychain Password Prompt Fix

### Issue
App was prompting for system password on every restart to authorize keychain access.

### Cause
Keychain items are tied to the app's code signature. During development, each rebuild can have a slightly different signature, triggering re-authorization prompts.

### Fix
Added `kSecAttrAccessibleWhenUnlocked` to `KeychainService.swift` base query. This makes the keychain item less strict about code signature verification while still requiring the device to be unlocked.

After updating, users need to re-enter their API key once to create a new keychain entry with the updated settings.

---

## 2026-01-15: Calendar Date Selection Fix

### Issue
Clicking on today's date in the calendar view would often fail to register. Users had to click on other dates first before being able to select today and see the "Ready to practice?" prompt.

### Investigation
Added diagnostic logging to trace the issue. Discovered that button taps were not being registered at all for today's date - no tap handler was firing. Taps on other dates worked fine.

### Root Cause
SwiftUI hit-testing issue. The `CalendarNavigatorDayView` button content includes a `ZStack` with `RoundedRectangle` background, overlay stroke, and text content. For dates with certain visual states (particularly `isToday: true` combined with `isSelected: true`), SwiftUI's automatic hit-testing was failing to detect taps.

### Fix
Added `.contentShape(Rectangle())` to the button's content in `CalendarNavigatorDayView`. This explicitly defines the tappable area as the full rectangular frame, ensuring consistent tap detection regardless of the internal view hierarchy or visual state.

```swift
.frame(height: 44)
.contentShape(Rectangle())  // Added this line
```

### Lesson Learned
When using complex view hierarchies inside SwiftUI buttons (ZStack, overlays, conditional styling), always consider adding `.contentShape()` to ensure reliable hit-testing.

---

## 2026-01-15: HSplitView Divider Position Fix

### Issue
Clicking the stats toggle button (chart icon) in the header caused the HSplitView divider to reset, making the right pane shrink unexpectedly.

### Root Cause
The `if/else` conditional in `MainContentView.swift` caused SwiftUI to recreate the right pane view when toggling between stats and session views, triggering HSplitView to reset its divider position.

### Fix
Replaced `if/else` with `ZStack` using opacity toggling. Both views remain in the hierarchy; visibility is controlled via `.opacity(0)` / `.opacity(1)`. This preserves the HSplitView structure identity and maintains user-adjusted divider positions.

---

## 2026-01-15: Refresh Button Feedback

### Issue
The refresh button in the header didn't provide visual feedback - data was silently fetched in the background without showing loading skeletons.

### Root Cause
The "silent refresh" pattern in `fetchLibrary()` and `fetchSessions()` skipped setting `.loading` state when data already existed. The MainContentView condition `isLoading && library.isEmpty` meant skeletons only showed on cold start.

### Fix
Added `isRefreshing` flag to AppState that distinguishes explicit user refresh from background silent refresh. When set, MainContentView shows loading skeletons and HeaderView shows spinning animation.

---

## 2026-01-15: Calendar Month Navigation Animation

### Issue
When navigating months in the calendar view, date numerals would "glide down" in an unwanted animation caused by implicit SwiftUI animations.

### Root Cause
The `withAnimation` blocks around month navigation triggered implicit animations on the entire calendar grid, causing individual date cells to animate independently.

### Fix
Replaced the broken implicit animation with intentional directional slide transitions:
- Added `@State var navigatingForward` to track navigation direction
- Added `.id(displayedMonth)` to calendar grid to trigger view identity changes
- Added `.transition(.asymmetric(...))` with `.move(edge:)` for directional slides
- Months now slide in from right (forward) or left (backward)
- Also increased tap area on navigation buttons (32x32) for easier clicking

---

## 2026-01-15: Play Button Respects Focused Item (#5)

### Issue
Clicking "Play" or pressing Cmd+P always started practice from the first session item, ignoring the currently highlighted/focused item.

### Fix
Updated `startPractice()` in AppState to:
1. Start from `focusedSelectedIndex` if an item is focused
2. Otherwise, auto-select the first unplayed item (`actualMinutes == nil`)
3. Fall back to index 0 if all items have been played

---

## 2026-01-15: Cmd+O in Practice View (#6)

### Issue
Cmd+O to open the current item in Notion only worked in the main view, not during practice.

### Fix
- Added `openCurrentPracticeItemInNotion()` method to AppState
- Added button with Cmd+O shortcut to PracticeView header
- Added "⌘O notion" hint to practice footer

---

## 2026-01-15: Keyboard Navigation Focus Fix (#7)

### Issue
Arrow key navigation in library/session lists sometimes stopped working after clicking on items or using filters.

### Root Cause
Clicking on list items (which are Buttons) transferred focus away from MainContentView, causing onKeyPress handlers to stop receiving events.

### Fix
- Added `@FocusState` to MainContentView to manage focus explicitly
- Refocus main view on appear and when panel changes
- Refocus when exiting search field
- Added `clampFocusedItemIndex()` to keep focus valid when filters reduce list size
