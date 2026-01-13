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

### Next Steps
- Phase 2: Search/filter/sort for library
- Split view layout (Library | Selected)
