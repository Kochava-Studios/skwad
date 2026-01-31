# Per-Agent Command Settings

## Objective

Change the Coding settings to store default options per agent type, and allow selecting an agent type when creating a new agent.

## Current State

- Single global `agentCommand` + `agentCommandOptions` in AppSettings
- AgentSheet creates agents without agent type selection
- All agents run the same command

## Target State

- Each predefined agent (Claude, Codex, OpenCode, Aider, Goose, Gemini) has its own stored options
- Custom 1 and Custom 2 have both command and options
- New agent sheet includes agent type picker
- Agent model stores which agent type to use
- Terminal launches with the correct command based on agent type

## Implementation Plan

### Phase 1: Update AppSettings for per-agent options

1. Add new storage for per-agent options:
   - `agentOptions_claude`, `agentOptions_codex`, etc. for predefined agents
   - `customAgent1Command`, `customAgent1Options` for Custom 1
   - `customAgent2Command`, `customAgent2Options` for Custom 2

2. Add helper methods:
   - `getOptions(for agentType: String) -> String`
   - `setOptions(_ options: String, for agentType: String)`
   - `getCommand(for agentType: String) -> String` (for custom agents)
   - `getFullCommand(for agentType: String) -> String`

3. Migrate existing `agentCommandOptions` to `agentOptions_claude` (or whichever was selected)

### Phase 2: Update CodingSettingsView

1. Keep the agent picker at the top (but now it's just for selecting which agent to configure)
2. Show "Command" field only for Custom 1 and Custom 2
3. Show "Options" field for all agents
4. Bind to the per-agent storage based on selection
5. Update footer to show full command preview

### Phase 3: Update Agent model

1. Add `agentType: String` property to Agent
2. Add `agentType` to SavedAgent for persistence
3. Update AgentManager.addAgent() to accept agentType parameter

### Phase 4: Update AgentSheet

1. Add agent type picker (similar style to repo/worktree pickers)
2. Default to "claude" or last used agent type
3. Pass selected agent type to AgentManager.addAgent()

### Phase 5: Update terminal launch

1. Update code that builds the terminal command to use `settings.getFullCommand(for: agent.agentType)`

## Commits

1. `feat: add per-agent options storage to AppSettings`
2. `feat: update CodingSettingsView for per-agent configuration`
3. `feat: add agentType to Agent model`
4. `feat: add agent type picker to AgentSheet`
5. `feat: launch terminal with agent-specific command`

## Files to Modify

- `Skwad/Models/AppSettings.swift`
- `Skwad/Views/Settings/SettingsView.swift` (CodingSettingsView)
- `Skwad/Models/Agent.swift`
- `Skwad/Models/AgentManager.swift`
- `Skwad/Views/Sidebar/AgentSheet.swift`
- Terminal launch code (need to find where command is built)

## Decisions

- All agents start with empty options (no defaults)
- Agent type picker in AgentSheet shows icons like in Settings

## Completed

- [x] Phase 1: Updated AppSettings with per-agent options storage
- [x] Phase 2: Updated CodingSettingsView to configure each agent type
- [x] Phase 3: Added agentType to Agent and SavedAgent models
- [x] Phase 4: Added agent type picker to AgentSheet
- [x] Phase 5: Updated terminal views to use agent-specific commands
- [x] Fixed pre-existing bug in MCPService.swift (corrupted sendMessage function)
