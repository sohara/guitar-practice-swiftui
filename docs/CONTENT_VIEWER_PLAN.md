# Issue #19: View Practice Library Item Content in Practice Mode

**Status:** Planned (not yet implemented)
**GitHub Issue:** [#19](https://github.com/sohara/guitar-practice-swiftui/issues/19)

## Overview

Display Notion page content (sheet music, tabs, audio backing tracks, notes) directly in the practice view, eliminating the need to switch to Notion while practicing.

## Approach: WebView + HTML Generation

Fetch Notion blocks via API, convert to HTML in Swift, render in WKWebView. This approach:
- Handles images, audio, and rich text naturally via HTML
- Avoids building a complex native SwiftUI renderer
- Leverages HTML5 `<audio controls>` for free audio player UI
- Keeps data private (fetched via user's API key, not public embeds)

## Dependencies

**No third-party libraries required.** This implementation uses only Apple frameworks:

| Component | Technology | Notes |
|-----------|------------|-------|
| WebView | `WKWebView` (WebKit framework) | Built into macOS, wrapped with `NSViewRepresentable` for SwiftUI |
| HTML generation | Pure Swift string building | No template engine needed |
| Styling | Inline CSS in HTML | Dark theme matching app aesthetic |
| Audio playback | HTML5 `<audio controls>` | Native browser audio player, no JS needed |
| API calls | Existing `NotionClient` | Already uses `URLSession` |

**Why not React/react-notion-x?**
- Would require bundling a React app, JS bridge complexity
- Our content is relatively simple (text, images, audio, lists)
- Swift HTML generation is straightforward for these block types
- Keeps the app 100% native with no web build tooling

## Content Types to Support

Based on analysis of actual Practice Library items:

| Priority | Block Type | HTML Rendering |
|----------|------------|----------------|
| P0 | Images | `<img src="...">` (sheet music, tabs) |
| P0 | Audio | `<audio controls src="...">` (backing tracks) |
| P0 | Headings | `<h2>`, `<h3>` |
| P0 | Paragraphs | `<p>` with links |
| P0 | Bulleted lists | `<ul><li>` (nested) |
| P1 | Toggle blocks | `<details><summary>` |
| P1 | Files | `<a href="..." download>` (PDFs, Guitar Pro) |
| P1 | Inline code | `<code>` |
| P2 | Numbered lists | `<ol><li>` |
| P2 | Code blocks | `<pre><code>` |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ PracticeView (HSplitView)                                   │
├─────────────────────────┬───────────────────────────────────┤
│ Left Panel (400pt min)  │ Right Panel (ContentPanelView)    │
│ - Timer display         │ - WKWebView                       │
│ - Control buttons       │ - Loading/error states            │
│ - Notes card            │ - Toggle button (⌘I)              │
└─────────────────────────┴───────────────────────────────────┘
```

## Implementation Steps

### Step 1: Add Block Fetching to NotionClient

**File:** `GuitarPractice/Services/NotionClient.swift`

Add method to fetch page blocks:

```swift
func fetchBlocks(pageId: String) async throws -> [NotionBlock]
```

- Call `GET /blocks/{page_id}/children` with pagination
- Parse block types: paragraph, heading_1/2/3, bulleted_list_item, image, audio, file, toggle, code
- Handle nested children (recursive fetch for toggles)

### Step 2: Create NotionBlock Model

**File:** `GuitarPractice/Models/Types.swift`

```swift
struct NotionBlock: Identifiable {
    let id: String
    let type: BlockType
    let content: BlockContent
    var children: [NotionBlock]?

    enum BlockType: String {
        case paragraph, heading1, heading2, heading3
        case bulletedListItem, numberedListItem
        case image, audio, file
        case toggle, code, divider
    }

    enum BlockContent {
        case richText([RichTextSpan])
        case media(url: String, caption: String?)
        case file(url: String, name: String)
        case code(text: String, language: String?)
    }
}

struct RichTextSpan {
    let text: String
    let bold: Bool
    let italic: Bool
    let code: Bool
    let link: String?
}
```

### Step 3: Create HTML Renderer

**File:** `GuitarPractice/Services/NotionHTMLRenderer.swift`

```swift
struct NotionHTMLRenderer {
    func render(blocks: [NotionBlock]) -> String
    func renderBlock(_ block: NotionBlock) -> String
    func renderRichText(_ spans: [RichTextSpan]) -> String
    func wrapInHTMLDocument(_ body: String) -> String  // Add CSS
}
```

CSS styling:
- Dark theme matching app (charcoal background, light text)
- SF Mono font
- Responsive images (`max-width: 100%`)
- Audio player styling
- Proper spacing and typography

### Step 4: Create ContentPanelView

**File:** `GuitarPractice/Views/Practice/ContentPanelView.swift`

```swift
struct ContentPanelView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.isLoadingContent {
                // Loading skeleton
            } else if let error = appState.contentError {
                // Error state with retry
            } else if let html = appState.contentHTML {
                WebView(html: html)
            } else {
                // Empty state: "Press ⌘I to load content"
            }
        }
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    func makeNSView(...) -> WKWebView
    func updateNSView(...)
}
```

### Step 5: Add AppState Properties

**File:** `GuitarPractice/Models/AppState.swift`

```swift
// Content panel state
@Published var showContentPanel: Bool = true  // Visible by default
@Published var isLoadingContent: Bool = false
@Published var contentHTML: String? = nil
@Published var contentError: String? = nil
@Published var contentBlocks: [NotionBlock]? = nil

// Methods
func loadContentForCurrentItem() async
func toggleContentPanel()
```

### Step 6: Modify PracticeView Layout

**File:** `GuitarPractice/Views/Practice/PracticeView.swift`

Convert to HSplitView:
- Left panel: existing timer/controls (condensed)
- Right panel: ContentPanelView (visible by default)
- Add ⌘I keyboard shortcut to toggle visibility

Layout adjustments:
- Reduce spacing in left panel when content panel is shown
- Left panel min width: 350pt
- Right panel min width: 400pt (when visible)
- Auto-load content when entering practice mode (in `startPractice()`)

### Step 7: Handle Signed URL Expiration

Notion S3 URLs expire after ~1 hour. Strategy:
- Fetch blocks fresh when entering practice mode (not cached)
- Show "Refresh Content" button if session is long
- Re-fetch if user explicitly requests

## Files to Create

1. `GuitarPractice/Services/NotionHTMLRenderer.swift` - HTML generation
2. `GuitarPractice/Views/Practice/ContentPanelView.swift` - WebView wrapper
3. `GuitarPractice/Views/Practice/WebView.swift` - WKWebView NSViewRepresentable

## Files to Modify

1. `GuitarPractice/Services/NotionClient.swift` - Add `fetchBlocks()`
2. `GuitarPractice/Models/Types.swift` - Add `NotionBlock`, `RichTextSpan`
3. `GuitarPractice/Models/AppState.swift` - Add content panel state/methods
4. `GuitarPractice/Views/Practice/PracticeView.swift` - HSplitView layout
5. `GuitarPractice/Views/Common/FooterView.swift` - Add ⌘I hint in practice mode

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ⌘I | Toggle content panel |
| ⌘R | Refresh content (when panel focused) |

## Testing Plan

1. **Manual testing:**
   - Load a course lesson item with images → verify sheet music displays
   - Load an item with backing track → verify audio player works
   - Load an item with nested bullet lists → verify nesting renders
   - Load an item with toggle blocks → verify expand/collapse
   - Test signed URL expiration (wait >1hr, verify refresh works)

2. **Edge cases:**
   - Item with no page content (empty body)
   - Item with unsupported block types
   - Network error during fetch
   - Very long content (scrolling)

## Future Enhancements (Out of Scope for Initial Implementation)

- Cache rendered HTML locally
- PDF inline viewer
- YouTube embed support
- Synced blocks
- Tables

## Research Notes

### Existing Swift Notion Libraries (API only, no rendering)
- [NotionSwift](https://github.com/chojnac/NotionSwift) - Mature SDK, macOS 10.13+
- [swift-notion-api](https://github.com/Taichone/swift-notion-api) - Swift 6 ready, async/await

### React Renderers (for reference, not used)
- [react-notion-x](https://github.com/NotionX/react-notion-x) - Full-featured, ~28kb gzipped

### Notion Block API
- Endpoint: `GET /blocks/{page_id}/children`
- Pagination via `start_cursor` and `has_more`
- Nested blocks require recursive fetch
- Media URLs are S3 signed URLs (~1hr expiry)

### Sample Content Analyzed
Pages from Practice Library contain:
- Sheet music images (PNG)
- Backing track audio (MP3, M4A)
- Lesson notes with nested bullet lists
- External links (YouTube, Patreon, AnyFlip)
- Guitar Pro files (.gp)
- PDFs
