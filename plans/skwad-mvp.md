# Skwad - Multi-Agent Terminal Manager. DONE!

## Overview

A macOS app to manage a team of AI coding agents, each running in its own embedded terminal. Built with SwiftUI + SwiftTerm.

## Core Features (MVP)

1. **Agent Management**
   - Add/remove agents
   - Each agent has: name, avatar/icon, working directory, status
   - Persist agent configurations

2. **Embedded Terminals**
   - Each agent runs in a SwiftTerm LocalProcessTerminalView
   - Launches `claude` CLI (or any command)
   - Full terminal emulation (colors, cursor, etc.)

3. **UI Layout** (matching your screenshot)
   - Left sidebar: workspace info + agent list
   - Main area: selected agent's terminal
   - Status indicators per agent (active/idle/error)

4. **Workspace/Project Support**
   - Associate agents with a project folder
   - Quick switching between workspaces

---

## Architecture

```
Skwad/
├── App/
│   ├── SkwadApp.swift              # App entry point
│   └── ContentView.swift           # Main layout
├── Models/
│   ├── Agent.swift                 # Agent model
│   ├── Workspace.swift             # Workspace/project model
│   └── AgentManager.swift          # ObservableObject managing agents
├── Views/
│   ├── Sidebar/
│   │   ├── SidebarView.swift       # Main sidebar
│   │   ├── WorkspaceHeaderView.swift
│   │   ├── AgentListView.swift
│   │   └── AgentRowView.swift
│   ├── Terminal/
│   │   ├── TerminalHostView.swift  # NSViewRepresentable wrapping SwiftTerm
│   │   └── AgentTerminalView.swift # Terminal + header for agent
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   └── PersistenceService.swift    # Save/load agent configs
└── Resources/
    └── Assets.xcassets
```

---

## Implementation Phases

### Phase 1: Project Setup & Basic Shell
- [ ] Create Xcode project (macOS App, SwiftUI)
- [ ] Add SwiftTerm package dependency
- [ ] Create basic window with split view
- [ ] Embed single SwiftTerm terminal running /bin/zsh
- [ ] **Commit**: "feat: initial project with embedded terminal"

### Phase 2: Agent Model & Management
- [ ] Define Agent model (id, name, icon, command, workingDirectory, status)
- [ ] Create AgentManager (ObservableObject)
- [ ] Implement add/remove agent
- [ ] Store agents in memory (no persistence yet)
- [ ] **Commit**: "feat: agent model and manager"

### Phase 3: Sidebar UI
- [ ] Build sidebar with workspace header
- [ ] Agent list with selection
- [ ] Agent row showing name, status indicator
- [ ] "New Agent" button
- [ ] **Commit**: "feat: sidebar with agent list"

### Phase 4: Multi-Terminal Support
- [ ] Create terminal instances per agent
- [ ] Switch displayed terminal based on selection
- [ ] Each terminal runs its own process
- [ ] Handle terminal lifecycle (start/stop)
- [ ] **Commit**: "feat: multi-agent terminal switching"

### Phase 5: Agent Configuration
- [ ] New agent dialog (name, command, working dir)
- [ ] Edit agent settings
- [ ] Delete agent (with confirmation)
- [ ] **Commit**: "feat: agent configuration UI"

### Phase 6: Persistence
- [ ] Save agent configs to disk (JSON in ~/Library/Application Support/Skwad)
- [ ] Load on app launch
- [ ] Auto-save on changes
- [ ] **Commit**: "feat: persist agent configurations"

### Phase 7: Polish & UX
- [ ] Status indicators (running/idle based on terminal activity)
- [ ] Keyboard shortcuts (Cmd+1-9 for agents, Cmd+N new agent)
- [ ] App icon
- [ ] Menu bar integration
- [ ] **Commit**: "feat: keyboard shortcuts and polish"

---

## Technical Notes

### SwiftTerm Integration

```swift
import SwiftTerm

// NSViewRepresentable wrapper for SwiftUI
struct TerminalHostView: NSViewRepresentable {
    let command: String
    let workingDirectory: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        terminal.startProcess(executable: "/bin/zsh",
                              args: ["-c", command],
                              environment: nil,
                              execName: nil)
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
```

### Agent Model

```swift
struct Agent: Identifiable, Codable {
    let id: UUID
    var name: String        // derived from folder name: "frontend", "backend", etc.
    var avatar: String?     // optional custom avatar/emoji
    var folder: String      // the working directory - this is the primary input
    var status: AgentStatus
}
// Command is always: claude --dangerously-skip-permissions
// Launched in the agent's folder

enum AgentStatus: String, Codable {
    case idle, running, error
}
```

---

## Future Ideas (Post-MVP)

- Agent communication via MCP crew tools
- Split view showing multiple agents simultaneously
- Terminal output search/filtering
- Agent templates (Claude, GPT, local models)
- Session recording/replay
- Integration with git worktrees

---

## Key Learnings

(To be filled after implementation)

