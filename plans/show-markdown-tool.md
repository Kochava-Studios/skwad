# Plan: show-markdown MCP Tool

## Goal
Add a new MCP tool `show-markdown` that allows agents to display a markdown file in a sliding panel, incentivizing models to request plan reviews from users.

## Design Decisions

### Tool Behavior
- **Tool name**: `show-markdown`
- **Input**: `filePath` (required) - absolute path to a markdown file
- **Output**: Success/error response indicating if panel was opened
- **Side effect**: Opens a sliding panel showing the rendered markdown

### UI Design
- Sliding panel from the right (like GitPanelView)
- Resizable panel width (350-800px, default 500px)
- Header with:
  - File name/path
  - Close button (X)
- Content area with Textual-rendered markdown
- Auto-scrolls to top when opened

### Architecture
1. **MCPTypes.swift**: Add `showMarkdown` to `MCPToolName` enum + response struct
2. **MCPTools.swift**: Add tool definition and handler
3. **MCPService.swift**: Add method to request markdown panel display
4. **AgentDataProvider**: Add new method `showMarkdownPanel(filePath:agentId:)`
5. **AgentManagerWrapper**: Implement the new protocol method
6. **AgentManager**: Add published property for markdown panel state
7. **MarkdownPanelView.swift**: New view for rendering markdown (using Textual)
8. **ContentView.swift**: Integrate the panel (similar to GitPanelView)

## Implementation Steps

### Phase 1: Add Textual dependency
- [ ] Add Textual package to Package.swift
- [ ] Commit: `feat: add textual package dependency for markdown rendering`

### Phase 2: Create MarkdownPanelView
- [ ] Create `Skwad/Views/Markdown/MarkdownPanelView.swift`
  - Sliding panel UI (reuse patterns from GitPanelView)
  - Header with file name and close button
  - Textual markdown rendering
  - Error state for file not found / not readable
- [ ] Commit: `feat: add markdown panel view with textual rendering`

### Phase 3: Add MCP tool infrastructure
- [ ] Add `showMarkdown` to `MCPToolName` enum
- [ ] Add `ShowMarkdownResponse` struct
- [ ] Add tool definition in `MCPToolHandler.listTools()`
- [ ] Add handler method `handleShowMarkdown`
- [ ] Commit: `feat: add show-markdown mcp tool definition`

### Phase 4: Wire up AgentManager and panel state
- [ ] Add `showMarkdownPanel(filePath:agentId:)` to `AgentDataProvider` protocol
- [ ] Implement in `AgentManagerWrapper`
- [ ] Add `@Published` state in AgentManager for panel visibility + file path
- [ ] Commit: `feat: wire show-markdown tool to agent manager`

### Phase 5: Integrate panel in ContentView
- [ ] Add MarkdownPanelView to ContentView (similar to GitPanelView)
- [ ] Add slide-in animation and transition
- [ ] Handle close action
- [ ] Commit: `feat: integrate markdown panel in main content view`

### Phase 6: Testing & polish
- [ ] Test with various markdown files
- [ ] Handle edge cases (file not found, permission denied, empty file)
- [ ] Verify panel closes when switching agents
- [ ] Commit: `chore: polish markdown panel feature`

## Key Files to Modify

| File | Changes |
|------|---------|
| `Package.swift` | Add Textual dependency |
| `MCPTypes.swift` | Add enum case + response struct |
| `MCPTools.swift` | Add tool definition + handler |
| `MCPService.swift` | Add showMarkdownPanel method |
| `AgentManager.swift` | Add published state for panel |
| `ContentView.swift` | Integrate MarkdownPanelView |

## New Files

| File | Purpose |
|------|---------|
| `Skwad/Views/Markdown/MarkdownPanelView.swift` | Markdown panel UI |

## Notes
- The tool should return quickly (just signals to show panel)
- File reading happens in the view, not the tool handler
- Panel only shows for the agent that called the tool
- Multiple calls replace the current panel content
