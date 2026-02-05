# Changelog

All notable changes to this project will be documented in this file.

## [1.2.1] - 2026-02-04

### Added
- File drop support: drag files onto terminal to inject their path
- MCP tool `close-agent` for agents to close agents they created
- Agent creator tracking: `create-agent` now tracks which agent created another agent

### Changed
- Renamed MCP tool `show-markdown` to `display-markdown` with improved description
- Markdown panel is now per-agent: switching agents shows/hides the panel accordingly

### Fixed
- Context menu submenu flickering when terminal is active
- Markdown panel now reloads when file path changes
- Split pane now correctly collapses to single pane when removing an agent from a pane

### Removed
- N/A


## [1.2.0] - 2026-02-03

### Added
- Draggable split pane dividers for 2-pane and 4-pane layouts
- MCP tool `show-markdown` for agents to display markdown files in a panel

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A


## [1.1.0] - 2026-02-02

### Added
- Separate idle timeouts for terminal output (2s) and user input (10s)

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A


## [1.0.1] - 2026-01-31

### Added
- Agent recovery: help agents recover forgotten ID with folder matching
- Register agent context menu entry
- Move agent to workspace option in context menu

### Changed
- Improve send-message response to discourage polling
- Modernize to SOTA Swift patterns (view/logic separation)

### Fixed
- N/A

### Removed
- N/A


## [1.0.0] - 2026-01-28

### Added
- Workspace support for organizing agents
- Workspace-scoped MCP communication
- 4-pane grid layout mode
- Split vertical and horizontal layout modes
- Sparkle auto-update support
- Configurable default "open with" app and keyboard shortcut
- Comprehensive keyboard shortcuts
- Sidebar collapse toggle
- Broadcast message to all agents
- Close all agents option
- Clear agent keyboard shortcut (Shift+Cmd+C)
- Restart all menu option with confirmation
- Scroll wheel zoom in avatar editor
- Recent agent badges in empty state

### Changed
- Extended common source folder candidates list
- Extended avatar cropper zoom limits to 10%-2000%

### Fixed
- Focus pane when clicking visible agent instead of swapping
- Split pane implementation issues
- Settings organization
- Use zip instead of ditto to avoid resource fork corruption
- Notify terminal to resize when git panel toggles

### Removed
- N/A


## [0.9.0] - Initial Release

### Added
- Multi-agent terminal management with Ghostty and SwiftTerm engines
- Agent-to-agent communication via MCP server
- Git integration with status panel, staging, and commits
- Git worktree support for agent isolation
- Voice input with push-to-talk
- Custom agent avatars with image cropping
- Activity detection (working/idle status)
- Terminal state preservation when switching agents

### Changed
- N/A

### Fixed
- N/A

### Removed
- N/A
