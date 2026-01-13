# Guitar Practice - SwiftUI Mac App

A native macOS app for managing guitar practice sessions in Notion.

## Quick Start

```bash
# Open in Xcode
open GuitarPractice.xcodeproj

# Or build from command line
xcodebuild -scheme GuitarPractice -configuration Debug build
```

## Documentation

- `PLAN.md` - Development roadmap and architecture
- `docs/DEVLOG.md` - Running development log
- `../guitar-tui/docs/DEVELOPMENT.md` - Notion API details and database structure

## Key Files

- `GuitarPractice/GuitarPracticeApp.swift` - Main app entry point
- `GuitarPractice/ContentView.swift` - Root view

## Notion Integration

This app shares the same Notion databases as the TUI app:

| Database | Data Source ID |
|----------|----------------|
| Practice Library | `2d709433-8b1b-804c-897c-000b76c9e481` |
| Practice Sessions | `f4658dc0-2eb2-43fe-b268-1bba231c0156` |
| Practice Logs | `2d709433-8b1b-809b-bae2-000b1343e18f` |

See `../guitar-tui/docs/DEVELOPMENT.md` for API quirks (data source ID vs database ID).

## Notes

- Requires macOS 14.0+
- API key should be stored in Keychain, not hardcoded
- Reference TUI implementation in `../guitar-tui/src/` for Notion API patterns
