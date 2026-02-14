# Create Agent

Use the `create-agent` MCP tool to create a new agent in the skwad.

`create-agent` parameters:
- `name` (required): Agent display name
- `agentType` (required): One of: claude, codex, opencode, gemini, custom1, custom2, shell
- `repoPath` (required): Repository or worktree folder path
- `agentId` (optional): Your agent ID (to track who created it)
- `icon` (optional): Emoji icon for the agent
- `createWorktree` (optional): Set to true to create a new git worktree
- `branchName` (optional): Branch name (required if createWorktree is true)
- `companion` (optional): If true, agent is a companion linked to the creator
- `command` (optional): Command to run (only for shell agents)

Based on $ARGUMENTS, fill in the parameters. If key info is missing, ask the user.
You can use `list-repos` and `list-worktrees` to help pick a repository path.
