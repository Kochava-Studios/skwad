# view-mermaid MCP Tool

## Goal

Add a `view-mermaid` MCP tool that allows agents to display Mermaid diagrams in a panel. The Mermaid panel shares the right-side panel area with the existing Markdown panel. When both are active, they stack vertically (markdown on top, mermaid on bottom) with a draggable divider between them. Each section is collapsible.

## Dependency

- **beautiful-mermaid-swift** (`https://github.com/lukilabs/beautiful-mermaid-swift`, from: `"0.1.0"`)
  - Provides `MermaidRenderer.renderImage(source:theme:scale:)` → `NSImage`
  - Provides `DiagramTheme` with built-in themes (`.zincLight`, `.zincDark`, `.tokyoNight`, `.dracula`, etc.)
  - Pure Swift, no WebView/JS. Supports flowcharts, state, sequence, class, ER diagrams.
  - **Gotcha**: `BeautifulMermaid` exports a `State` type that clashes with `SwiftUI.State` — use `@SwiftUI.State` in files that import both.

## Architecture

### Panel Layout (shared right panel area)

When both markdown and mermaid are active for the active agent:
```
┌──────────────────────┐
│ Artifacts      ⤢  ✕  │  ← panel toolbar (expand, close all)
├──────────────────────┤
│ ▾ 📄 file.md  ...  ✕ │  ← markdown header (collapsible, review buttons, font, close)
├──────────────────────┤
│                      │
│  Markdown content    │
│                      │
├══════════════════════┤  ← draggable divider
│ ▾ 📊 Diagram      ✕ │  ← mermaid header (collapsible, close)
├──────────────────────┤
│                      │
│  Mermaid diagram     │
│                      │
└──────────────────────┘
```

When only one is active, it takes the full height (no panel toolbar, no collapse chevrons).

### File Structure

All artifact-related views live in `Views/Artifacts/`:
- `ArtifactPanelView.swift` — Container: resize handle, width, expand, close-all, section layout
- `MarkdownPanelView.swift` — Markdown section: header with review/font controls, WebView content, comment popup
- `MarkdownWebView.swift` — WKWebView markdown renderer
- `MermaidPanelView.swift` — Mermaid section: header, rendered diagram image

### Data Flow (same pattern as display-markdown)

```
Agent calls view-mermaid tool with mermaid source text
  → MCPTools.handleViewMermaid()
  → AgentCoordinator.showMermaidPanel()
  → AgentDataProvider.showMermaidPanel()
  → AgentManagerWrapper → AgentManager.showMermaidPanel()
  → Sets agent.mermaidSource
  → ContentView observes change → renders ArtifactPanelView
```

---

## Implementation Plan

### Phase 1: Add SPM dependency + MCP tool plumbing ✅
**Commit: `feat: add view-mermaid MCP tool`**

1. **Package.swift** — Added `beautiful-mermaid-swift` dependency
2. **MCPTypes.swift** — Added `.viewMermaid` to `MCPToolName` enum + `ShowMermaidResponse` struct
3. **MCPTools.swift** — Added tool definition, callTool case, `handleViewMermaid()` handler
4. **Agent.swift** — Added `mermaidSource` and `mermaidTitle` runtime properties
5. **AgentCoordinator.swift** — Added `showMermaidPanel()` + protocol method + wrapper

### Phase 2: Create MermaidPanelView ✅
**Commit: `feat: add mermaid diagram panel view`**

1. **MermaidPanelView.swift** — Renders mermaid via `MermaidRenderer.renderImage()`, theme-aware, collapsible header

### Phase 3: ArtifactPanelView container ✅
**Commit: `feat: artifact panel with collapsible markdown/mermaid`**

1. **ArtifactPanelView.swift** — Container with resize handle, panel width, expand/close, section layout
2. **MarkdownPanelView.swift** — Refactored: removed resize handle + expand (moved to container), added `isCollapsible`/`isCollapsed` support
3. **ContentView.swift** — Replaced `MarkdownPanelView` with `ArtifactPanelView`, renamed `markdownExpanded` → `artifactExpanded`

### Phase 4: Test and polish
**Commit: `test: verify view-mermaid tool`**

1. Manual test: agent sends mermaid diagram, panel renders
2. Manual test: both panels visible, collapsible, draggable divider
3. Manual test: close/reopen, single-section mode, expand mode

---

## Key Decisions

- **Source text, not file path**: Unlike `display-markdown` which takes a file path, `view-mermaid` takes the mermaid source directly as a string. No file watching needed.
- **`MermaidRenderer.renderImage()` over `MermaidView`**: Static image rendering gives us a simple SwiftUI `Image` to display. Avoids NSView embedding complexity.
- **Theme follows system**: `.zincDark`/`.zincLight` based on `colorScheme`.
- **Collapsible via panel headers**: Each panel's own header gains a chevron toggle when `isCollapsible=true` (i.e. when both sections active). No extra wrapper headers — clean single-header-per-section.
- **Panel toolbar only in dual mode**: When only one artifact is active, no extra toolbar — the section fills the panel directly.
