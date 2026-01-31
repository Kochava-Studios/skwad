# Skwad Feature Roadmap

## Current State (v0.1)

### Completed Features

- Multi-agent terminal management
- Ghostty (libghostty) terminal engine with GPU acceleration
- SwiftTerm fallback option
- User Ghostty config support (~/.config/ghostty/config)
- Agent-to-agent MCP communication
- Activity detection (working/idle status)
- Terminal title display in sidebar
- Window drag and double-click maximize
- Agent persistence across restarts
- Customizable agent command (Claude, Codex, OpenCode, Aider, Goose, Gemini, custom)
- Open in IDE context menu (VS Code, Xcode, Finder, Terminal)
- App icons for agents and IDE menu items
- Git worktree integration (repo picker, worktree picker, new worktree creation)
- Source folder auto-detection and configuration
- Git status panel with diff viewer, staging, and commit
- Appearance modes (Auto/System/Light/Dark)
- MCP settings panel with Claude install command
- Resizable sidebar
- Agent restart/duplicate in context menu
- Recent Agents menu (File > Recent Agents)
- Voice input with push-to-talk and waveform visualization
- Terminal title display in header (name, path, title)

---

## Feature Roadmap

### Git Integration

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Git worktree auto-creation | P1 | Done | Create worktree from new agent dialog |
| Worktree switcher UI | P1 | Done | Repo + worktree pickers in agent creation |
| Built-in diff viewer | P2 | Done | Sliding panel with status, diff, stage/unstage, commit |
| GitHub PR integration | P2 | - | Create PRs, monitor CI, merge |
| GitLab integration | P3 | - | Same as GitHub but for GitLab |
| Merge conflict resolver | P3 | - | In-app conflict resolution |

### Multi-Pane & Layouts

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Split pane (2 agents) | P1 | - | Horizontal or vertical |
| Quad view (4 agents) | P2 | - | 2x2 grid layout |
| Custom layouts | P3 | - | Drag-and-drop pane arrangement |
| Layout presets | P3 | - | Save/restore layouts |

### IDE & Tool Integration

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Open in IDE button | P1 | Done | VS Code, Xcode, Finder, Terminal |
| ~~Lazygit split pane~~ | - | Superseded | Built-in git panel covers this |
| File browser | P2 | - | Browse agent's working directory |
| Port forwarding display | P2 | - | Detect servers, show ports |

### Agent Workflow

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| ~~Agent templates/presets~~ | - | Done | File > Recent Agents (last 8 with name/avatar/folder) |
| Task queue system | P2 | - | Queue tasks, agent picks up when idle |
| Progress tracking | P2 | - | Parse output for progress bars |
| Auto-start agents | P2 | - | Start agents on app launch |
| Agent cloning | P3 | - | Duplicate agent with new folder |

### UI/UX Enhancements

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| ~~Desktop notifications~~ | - | N/A | Claude Code handles its own notifications |
| Output search | P2 | - | Search across terminal output |
| Keyboard shortcuts | P2 | Done | Cmd+1-9 for agents, Ctrl+Tab cycling |
| Command palette | P3 | - | Cmd+K style quick actions |
| Appearance modes | P3 | Done | Auto/System/Light/Dark with smart terminal color detection |

### Communication & Input

| Feature | Priority | Status | Notes |
|---------|----------|--------|-------|
| Voice input | P2 | Done | Push-to-talk with waveform, Apple speech recognition |
| Broadcast to all agents | P2 | - | Send same message to all |
| Agent chat history | P3 | - | View MCP message history |

---

## Priority Legend

| Priority | Meaning |
|----------|---------|
| P0 | Critical / Blocking |
| P1 | High priority / Next up |
| P2 | Medium priority / Nice to have soon |
| P3 | Low priority / Future consideration |

---

## Inspiration Sources

- [Supacode](https://supacode.sh/) - Git worktree, GitHub integration
- [Superset](https://superset.sh/) - Multi-IDE, port forwarding, code review
- [Aizen](https://aizen.win/) - Voice input, split panes, lazygit

---

## Notes

_Feature requests and ideas to be evaluated:_

-
