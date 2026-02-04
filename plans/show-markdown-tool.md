# Plan: show-markdown MCP Tool

## Goal
Add a new MCP tool `show-markdown` that allows agents to display a markdown file in a sliding panel, incentivizing models to request plan reviews from users.

## Design Decisions

### Tool Behavior
- **Tool name**: `show-markdown`
- **Input**: `filePath` (required) - absolute path to a markdown file, `agentId` (required) - caller's agent ID
- **Output**: Success/error response indicating if panel was opened
- **Side effect**: Opens a sliding panel showing the rendered markdown

### UI Design
- Sliding panel from the right (like GitPanelView)
- Resizable panel width (350-800px, default 500px)
- Header with:
  - File name/path
  - Close button (X)
- Content area with MarkdownUI-rendered markdown
- Auto-scrolls to top when opened

### Architecture
1. **MCPTypes.swift**: Add `showMarkdown` to `MCPToolName` enum + response struct
2. **MCPTools.swift**: Add tool definition and handler
3. **MCPService.swift**: Add method to request markdown panel display
4. **AgentDataProvider**: Add new method `showMarkdownPanel(filePath:agentId:)`
5. **AgentManagerWrapper**: Implement the new protocol method
6. **AgentManager**: Add published property for markdown panel state
7. **MarkdownPanelView.swift**: New view for rendering markdown (using MarkdownUI)
8. **ContentView.swift**: Integrate the panel (similar to GitPanelView)

## Implementation Steps

### Phase 1: Add MarkdownUI dependency
- [x] Add MarkdownUI package to Package.swift and Xcode project
- [x] Commit: `feat: add markdownui package dependency for markdown rendering`

### Phase 2: Create MarkdownPanelView
- [x] Create `Skwad/Views/Markdown/MarkdownPanelView.swift`
  - Sliding panel UI (reuse patterns from GitPanelView)
  - Header with file name and close button
  - MarkdownUI markdown rendering
  - Error state for file not found / not readable
- [x] Commit: `feat: add markdown panel view with markdownui rendering`

### Phase 3: Add MCP tool infrastructure
- [x] Add `showMarkdown` to `MCPToolName` enum
- [x] Add `ShowMarkdownResponse` struct
- [x] Add tool definition in `MCPToolHandler.listTools()`
- [x] Add handler method `handleShowMarkdown`
- [x] Commit: `feat: add show-markdown mcp tool definition`

### Phase 4: Wire up AgentManager and panel state
- [x] Add `showMarkdownPanel(filePath:agentId:)` to `AgentDataProvider` protocol
- [x] Implement in `AgentManagerWrapper`
- [x] Add state in AgentManager for panel visibility + file path
- [x] Commit: `feat: wire show-markdown tool to agent manager`

### Phase 5: Integrate panel in ContentView
- [x] Add MarkdownPanelView to ContentView (similar to GitPanelView)
- [x] Add slide-in animation and transition
- [x] Handle close action
- [x] Close panel when switching agents
- [x] Notify terminal to resize when panel toggles
- [x] Commit: `feat: integrate markdown panel in main content view`

### Phase 6: Testing & polish
- [ ] Test with various markdown files
- [ ] Handle edge cases (file not found, permission denied, empty file)
- [ ] Verify panel closes when switching agents
- [ ] Commit: `chore: polish markdown panel feature`

## Key Files Modified

| File | Changes |
|------|---------|
| `Package.swift` | Add MarkdownUI dependency |
| `Skwad.xcodeproj/project.pbxproj` | Add MarkdownUI package + MarkdownPanelView.swift |
| `MCPTypes.swift` | Add enum case + response struct |
| `MCPTools.swift` | Add tool definition + handler |
| `MCPService.swift` | Add showMarkdownPanel method |
| `AgentManager.swift` | Add state for panel |
| `ContentView.swift` | Integrate MarkdownPanelView |

## New Files

| File | Purpose |
|------|---------|
| `Skwad/Views/Markdown/MarkdownPanelView.swift` | Markdown panel UI |

## Notes
- The tool returns quickly (just signals to show panel)
- File reading happens in the view, not the tool handler
- Panel only shows for the agent that called the tool
- Multiple calls replace the current panel content
- Used MarkdownUI instead of Textual (MarkdownUI is mature and well-documented)

## Key Learnings
- Xcode projects require manual updates to project.pbxproj for new files and packages
- MarkdownUI uses `.markdownTheme(.gitHub)` for GitHub-style rendering
- Pattern for sliding panels: use `.transition(.move(edge: .trailing))` with animation
- Close panels on agent switch via `.onChange(of: agentManager.activeAgentIds)`
