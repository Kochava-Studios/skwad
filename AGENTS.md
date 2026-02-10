# Skwad - Agent Development Guide

This document provides context for AI agents working on the Skwad codebase.

## Project Overview

Skwad is a macOS SwiftUI application that manages multiple AI coding agents, each running in an embedded terminal. It supports two terminal engines (Ghostty and SwiftTerm), agent-to-agent communication via MCP, and git worktree integration.

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14+)
- **Terminal Engines**:
  - Ghostty (libghostty) - GPU-accelerated, default
  - SwiftTerm - fallback option
- **MCP Server**: Hummingbird HTTP framework
- **Persistence**: @AppStorage (UserDefaults) + Codable JSON
- **Build**: Xcode project + Swift Package Manager

## Project Structure

```
Skwad/
├── Models/
│   ├── Agent.swift              # Agent data model with runtime state
│   ├── AgentManager.swift       # Central agent lifecycle management
│   └── AppSettings.swift        # App settings with @AppStorage
├── Views/
│   ├── ContentView.swift        # Main layout with sidebar + terminal
│   ├── Sidebar/
│   │   ├── SidebarView.swift    # Agent list with drag-drop
│   │   └── AgentSheet.swift     # New/edit agent dialog
│   ├── Terminal/
│   │   ├── AgentTerminalView.swift   # Terminal wrapper
│   │   ├── GhosttyHostView.swift     # Ghostty NSViewRepresentable
│   │   └── TerminalHostView.swift    # SwiftTerm NSViewRepresentable
│   ├── Git/
│   │   ├── GitPanelView.swift   # Sliding git status panel
│   │   ├── DiffView.swift       # Syntax-highlighted diff display
│   │   └── CommitSheet.swift    # Commit dialog
│   └── Settings/
│       └── SettingsView.swift   # Settings window
├── Git/
│   ├── GitCLI.swift             # Low-level git command runner (with timeout)
│   ├── GitRepository.swift      # High-level git operations
│   ├── GitWorktreeManager.swift # Worktree discovery and creation
│   ├── GitFileWatcher.swift     # FSEvents file monitoring
│   └── GitTypes.swift           # FileStatus, DiffLine, etc.
├── MCP/
│   ├── MCPService.swift         # Actor managing messages and agent data
│   ├── MCPServer.swift          # Hummingbird HTTP server
│   ├── MCPSessionManager.swift  # MCP session tracking
│   ├── MCPToolHandler.swift     # Tool execution
│   └── MCPTypes.swift           # Message, AgentInfo structs
├── GhosttyTerminal/             # Ghostty integration (libghostty wrappers)
└── SkwadApp.swift               # App entry point
```

## Architecture

### Terminal Management
- All terminals are kept alive in a ZStack with opacity toggle (not recreated on switch)
- This preserves terminal state/history when switching between agents
- `restartToken` on Agent model forces terminal recreation on restart while keeping same ID
- Focus is managed via `window?.makeFirstResponder()` in updateNSView

### Terminal Engines
- **Ghostty** (default): Uses libghostty C API via Swift wrappers
  - `GhosttyAppManager` - singleton managing Ghostty app instance
  - `GhosttyHostView` - NSViewRepresentable wrapper
  - Reads user's `~/.config/ghostty/config` for styling
- **SwiftTerm**: Fallback option
  - `TerminalHostView` - NSViewRepresentable wrapper
  - `ActivityDetectingTerminalView` - subclass for activity detection

### Activity Detection
- Detects terminal output to determine Working vs Idle status
- Uses debouncing (2s timeout) before marking as Idle
- Status colors: orange=Working, green=Idle, red=Error
- When idle, checks for unread MCP messages

### MCP Communication
- `MCPService` (actor) manages message queue and agent queries
- `AgentDataProvider` protocol bridges MainActor-isolated AgentManager safely
- Server starts AFTER AgentManager is set to avoid race conditions
- Registration prompt injected ~3s after terminal starts (if MCP enabled)
- Communication tools: `register-agent`, `list-agents`, `send-message`, `check-messages`, `broadcast-message`
- Management tools: `list-repos`, `list-worktrees`, `create-agent`

### Git Integration
- `GitCLI` - Low-level command runner with 30s timeout
- `GitRepository` - High-level operations (status, diff, stage, commit)
- `GitWorktreeManager` - Repo discovery and worktree operations
- `GitFileWatcher` - FSEvents monitoring with debounce for auto-refresh
- `GitPanelView` - Sliding panel UI with VSplitView layout

### Agent Lifecycle
1. User creates agent via AgentSheet (picks folder/worktree, name, avatar)
2. AgentManager.addAgent() creates Agent, saves to settings
3. Terminal view spawns shell, sends `cd <folder> && <agent-command>`
4. If MCP enabled, registration prompt injected after ~3s
5. Agent marked as registered when `register-agent` tool is called
6. On restart, same ID is kept but `restartToken` changes to force terminal recreation

### Settings & Persistence
- `AppSettings.shared` singleton with @AppStorage properties
- Simple values: @AppStorage directly
- Complex types (savedAgents, recentRepos): Codable + JSON Data
- Source folder auto-detected on first launch (~/src, ~/source, ~/sources)

## Key Patterns

### Concurrency Safety
- `MCPService` is an actor for thread-safe message handling
- `AgentDataProvider` protocol bridges MainActor ↔ actor boundaries safely
- Never use `nonisolated(unsafe)` - use proper async boundaries instead
- Terminal callbacks dispatch to MainActor when updating UI state

### Weak References
- Terminal dictionary in AgentManager uses weak refs to avoid retain cycles
- Coordinator classes use `[weak self]` in closures and timers

### Error Handling
- GitCLI has 30s timeout to prevent hung processes
- Git operations return Result<T, GitError> for proper error propagation

## Common Tasks

### Adding a New Setting
1. Add @AppStorage property to AppSettings.swift
2. Add UI control in appropriate SettingsView section
3. Use the setting where needed via AppSettings.shared

### Adding a New MCP Tool
1. Add tool name to `MCPToolName` enum in MCPTypes.swift
2. Add response struct in MCPTypes.swift if needed
3. Add tool definition in `MCPToolHandler.listTools()` in MCPTools.swift
4. Add switch case in `MCPToolHandler.callTool()` in MCPTools.swift
5. Implement handler method in MCPTools.swift
6. Add service method in MCPService.swift if needed
7. If accessing AgentManager, extend `AgentDataProvider` protocol and `AgentManagerWrapper`

### Modifying Terminal Behavior
- Ghostty: GhosttyHostView.swift callbacks (onReady, onActivity, etc.)
- SwiftTerm: TerminalHostView.swift and ActivityDetectingTerminalView
- Both check `settings.mcpServerEnabled` before MCP operations

### Adding Git Operations
1. Add low-level command in GitCLI if needed
2. Add high-level operation in GitRepository
3. Update GitPanelView UI to expose the feature

## Testing

Currently no automated tests. Manual testing checklist:
1. Build and run (Cmd+R)
2. Create agent from repo picker, verify terminal launches
3. Create agent with new worktree
4. Switch agents, verify state preserved
5. Open git panel, stage/unstage/commit
6. Test agent communication (send message between agents)
7. Restart agent, verify same ID kept
8. Change settings, verify applied
9. Quit and relaunch, verify restore works
10. Drag and drop to reorder agents

## Version Bump

To bump the marketing version, use the Makefile target:

```bash
make set-version VERSION=x.y.z
```

This updates `MARKETING_VERSION` in all build configurations in the Xcode project file.

## Known Limitations

- Terminal colors set by claude/shell may override app colors (Ghostty respects config)
- Single window only (no multi-window support)
- SwiftTerm doesn't support MCP messaging (terminal not registered)
- MCP messages are in-memory only (lost on app restart)

## Future Ideas (see plans/feature-roadmap.md)

- Split pane view for multiple agents
- Agent templates/presets
- Desktop notifications
- GitHub PR integration
- Voice input
