<p align="center">
   <img src="Skwad/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="Skwad App Icon" />
</p>

# Skwad

Meet your new, slightly revolutionary coding crew. Skwad is a macOS app that runs a whole team of AI coding agents—each in its own embedded terminal—and lets them coordinate work themselves so you can get real, parallel progress without tab chaos.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Why Skwad

- **Feels like a control room:** your agents are always visible, always alive, always ready.
- **Fast, native, fluid:** GPU‑accelerated Ghostty terminals and a UI that keeps up.
- **Actually collaborative:** built‑in MCP lets agents coordinate work themselves and hand off tasks.
- **Git without context switching:** diff, stage, commit, and stay in flow.

## Features

### Multi-Agent Management
- Run multiple AI coding agents simultaneously, each in their own terminal
- Support for Claude Code, Codex, OpenCode, Aider, Goose, Gemini CLI, or custom commands
- Real-time activity detection showing when agents are working or idle
- Drag & drop reordering in the sidebar

### Terminal Engines
- **Ghostty** (default): GPU-accelerated terminal powered by [libghostty](https://github.com/ghostty-org/ghostty)
- **SwiftTerm**: Fallback option using [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- Respects your `~/.config/ghostty/config` for colors and styling

### Agent-to-Agent Communication (MCP)
- Built-in MCP server enables agents to communicate with each other
- Agents can send messages, broadcast to all, and check their inbox
- Automatic message notification when agents become idle
- Tools: `register-agent`, `list-agents`, `send-message`, `check-messages`, `broadcast-message`

### Git Integration
- **Worktree support**: Create agents from existing worktrees or create new ones
- **Repository picker**: Quick access to recent repos with full repo discovery
- **Git status panel**: View diffs, stage/unstage files, and commit without leaving the app
- **File watcher**: Auto-refresh on file changes

### Customization
- Name your agents, assign emoji or image avatars
- Customizable terminal colors and fonts
- Resizable sidebar
- Dark theme optimized for coding

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+1-9 | Jump to agent 1-9 |
| Ctrl+Tab | Next agent |
| Ctrl+Shift+Tab | Previous agent |
| Cmd+, | Open settings |

### Context Menu Actions
- Edit agent (name, avatar)
- Duplicate agent
- Restart agent
- Open in VS Code / Xcode / Finder / Terminal
- Close agent

## Requirements

- macOS 14.0 (Sonoma) or later
- An AI coding CLI installed and available in your PATH:
  - [Claude Code](https://github.com/anthropics/claude-code) (default)
  - Or any other supported agent command

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/anthropics/skwad.git
   cd skwad
   ```

2. Open in Xcode:
   ```bash
   open Skwad.xcodeproj
   ```

3. Build and run (Cmd+R)

## Usage

### Creating an Agent

1. Click "New Agent" in the sidebar
2. Choose how to select a folder:
   - **Recent repos**: Quick access to recently used repositories
   - **All repos**: Browse discovered git repositories in your source folder
   - **Browse**: Select any folder manually
3. Optionally select or create a git worktree
4. Name your agent and pick an avatar
5. Click "Add Agent"

### Git Status Panel

Click the git branch icon (bottom-right) to open the git panel:
- View changed files grouped by status (staged, modified, untracked, conflicts)
- Click a file to view its diff
- Stage/unstage files with +/- buttons
- Commit staged changes with a message

### Agent Communication

When MCP is enabled, agents can talk to each other:

1. Each agent auto-registers with Skwad on startup
2. Use `list-agents` to see other agents
3. Use `send-message` to send a message to another agent
4. Recipients are notified when they become idle

## Settings

Access via **Skwad > Settings** (Cmd+,):

### General
- **Restore agents on launch**: Recreate your agent layout on app start
- **Terminal Engine**: Choose between Ghostty (GPU-accelerated) or SwiftTerm
- **Source Folder**: Base folder for git repository discovery

### Coding
- **Agent Command**: Claude, Codex, OpenCode, Aider, Goose, Gemini, or custom
- **Command Options**: Additional flags (e.g., `--dangerously-skip-permissions`)

### Terminal (SwiftTerm only)
- Font family and size
- Background and foreground colors

### MCP Server
- Enable/disable agent communication
- Configure server port (default: 8766)

## Architecture

See [AGENTS.md](AGENTS.md) for detailed architecture documentation for AI agents working on this codebase.

## Dependencies

- [libghostty](https://github.com/ghostty-org/ghostty) - GPU-accelerated terminal (via embedded framework)
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Fallback terminal emulation
- [Hummingbird](https://github.com/hummingbird-project/hummingbird) - HTTP server for MCP
- [swift-log](https://github.com/apple/swift-log) - Logging

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
