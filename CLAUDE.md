# Guitar Practice - SwiftUI Mac App

A native macOS app for managing guitar practice sessions, backed by Notion databases.

## Project Status

**Phases 1-7 Complete** - The app is fully functional with:
- Library browser with search, filter, sort, keyboard navigation
- Session management with drag-and-drop reordering
- Practice timer with countdown, overtime mode, menu bar integration
- Auto-save to Notion, auto-select today's session
- Loading skeletons, Open in Notion (⌘O)
- Timer alerts (sound + notification when time elapses)
- Local cache with SwiftData (instant app launch)
- Calendar view (embedded in right panel, view/edit modes)
- Stats dashboard (streaks, top items, weekly trends, type breakdown)
- Custom app icon (AI-generated guitar with green accents)
- UI polish (flexible split view, larger footer text, hover labels)

## Quick Start

```bash
# Build and run from command line
xcodebuild -scheme GuitarPractice -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/GuitarPractice-*/Build/Products/Debug/GuitarPractice.app

# Or open in Xcode
open GuitarPractice.xcodeproj
```

## Documentation

- `PLAN.md` - Development roadmap, architecture, Phase 7 ideas
- `docs/DEVLOG.md` - Detailed development log with decisions and bug fixes
- `../guitar-tui/docs/DEVELOPMENT.md` - Notion API details and database structure

## Project Structure

```
GuitarPractice/
├── GuitarPracticeApp.swift      # App entry, MenuBarExtra, AppDelegate
├── ContentView.swift            # All views (1500+ lines)
├── Models/
│   ├── Types.swift              # Data models (LibraryItem, PracticeSession, etc.)
│   └── AppState.swift           # @MainActor state management
├── Services/
│   ├── Config.swift             # Notion database IDs
│   ├── KeychainService.swift    # Secure API key storage
│   └── NotionClient.swift       # Async Notion API client
├── Assets.xcassets/
└── Info.plist
```

## Key Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ↑↓ or j/k | Navigate lists |
| Tab | Switch between library/session panels |
| Space/Enter | Toggle item selection |
| +/- | Adjust planned time |
| Ctrl-F/B | Page down/up in library |
| ⌘O | Open focused item in Notion app |
| ⌘P | Start practice |
| ⌘S | Save session |
| ⌘R | Refresh data |

## Notion Integration

Shares databases with the TUI app (`../guitar-tui/`):

| Database | Database ID |
|----------|-------------|
| Practice Library | `2d709433-8b1b-804c-897c-000b76c9e481` |
| Practice Sessions | `f4658dc0-2eb2-43fe-b268-1bba231c0156` |
| Practice Logs | `2d709433-8b1b-809b-bae2-000b1343e18f` |

**Note**: REST API uses database IDs (above), not data source IDs. See TUI docs for details.

## Technical Notes

- Requires macOS 14.0+ (for SwiftUI features, potential SwiftData)
- API key stored in Keychain (legacy file-based to avoid debug prompts)
- `@MainActor` AppState shared between WindowGroup and MenuBarExtra
- Uses `notion://` protocol to open items in Notion app (not browser)
- `loadDataIfNeeded()` prevents unnecessary reloads after practice
