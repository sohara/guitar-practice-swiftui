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
- Calendar view (embedded in right panel, view/edit modes, heat map, day stats)
- Stats dashboard (streaks, top items, weekly trends, type breakdown)
- Custom app icon (AI-generated guitar with green accents)
- UI polish (flexible split view, larger footer text, hover labels)

## Quick Start

```bash
# Build and run (development)
make run

# Install release build to /Applications (for daily use)
make install

# Or open in Xcode
open GuitarPractice.xcodeproj
```

## Makefile Commands

| Command | What it does |
|---------|--------------|
| `make build` | Debug build only |
| `make run` | Debug build + kill existing + launch |
| `make release` | Release build only |
| `make install` | Release build + install to /Applications + launch |
| `make clean` | Clean build artifacts |

## Development Workflow

- **Development**: Use `make run` for quick iteration on debug builds
- **Daily use**: Use `make install` to update the /Applications release version
- Release builds in /Applications have stable code signatures, avoiding keychain prompts

Always run `make run` before reviewing changes and before committing.

**IMPORTANT**: Always check the exit code of `make run`, not just the output text. A non-zero exit code means the build failed, even if "BUILD SUCCEEDED" appears in the output (the failure may occur in subsequent steps like launching the app).

**IMPORTANT**: Never commit or push until the user has manually tested and confirmed the fix works. Always ask for confirmation after launching the app for testing.

## Documentation

- `PLAN.md` - Development roadmap, architecture, Phase 7 ideas
- `docs/DEVLOG.md` - Detailed development log with decisions and bug fixes
- `../guitar-tui/docs/DEVELOPMENT.md` - Notion API details and database structure

## Project Structure

```
GuitarPractice/
├── GuitarPracticeApp.swift      # App entry, MenuBarExtra, AppDelegate
├── ContentView.swift            # Root view (~40 lines)
├── Models/
│   ├── Types.swift              # Data models (LibraryItem, DaySummary, etc.)
│   └── AppState.swift           # @MainActor state management
├── Services/
│   ├── Config.swift             # Notion database IDs
│   ├── KeychainService.swift    # Secure API key storage
│   ├── NotionClient.swift       # Async Notion API client
│   ├── CacheService.swift       # SwiftData local cache
│   └── StatsService.swift       # Practice analytics
├── Views/
│   ├── MainContentView.swift    # Split view layout
│   ├── Header/                  # HeaderView
│   ├── Library/                 # Sidebar, filter, list, row views
│   ├── Session/                 # Calendar, session detail views
│   ├── Practice/                # Timer view
│   ├── Stats/                   # Stats dashboard
│   ├── Settings/                # Settings, API key setup
│   └── Common/                  # Footer, loading, skeletons
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
| ⌘P | Enter practice (paused) |
| ⇧⌘P | Enter practice (timer running) |
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
