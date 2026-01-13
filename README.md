# Guitar Practice

A native macOS app for managing guitar practice sessions, backed by Notion.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5-purple)

## Overview

This is a SwiftUI port of [guitar-tui](https://github.com/sohara/guitar-tui), a terminal app for creating guitar practice sessions in Notion. The native app provides the same functionality with a better UX and Mac-native features like a menu bar timer.

### Features (Planned)

- Browse Practice Library (songs, exercises, course lessons)
- Search and filter with multiple sort options
- Build practice sessions by selecting items
- Timer with pause/resume for tracking actual practice time
- Menu bar widget showing timer during practice
- Sync with Notion databases

## Development

```bash
# Open in Xcode
open GuitarPractice.xcodeproj

# Build from command line
xcodebuild -scheme GuitarPractice -configuration Debug build

# Run the built app
open ~/Library/Developer/Xcode/DerivedData/GuitarPractice-*/Build/Products/Debug/GuitarPractice.app
```

## Documentation

- [PLAN.md](PLAN.md) - Development roadmap and architecture
- [docs/DEVLOG.md](docs/DEVLOG.md) - Running development log

## Requirements

- macOS 14.0+
- Xcode 15+
- Notion API key (stored in Keychain)

## Related

- [guitar-tui](https://github.com/sohara/guitar-tui) - Terminal UI version (TypeScript/OpenTUI)
