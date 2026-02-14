---
name: worktree
description: Isolate work in a new git worktree via Skwad
---

Use Skwad's MCP tools to isolate your current task in a new git worktree:

1. Call `list-repos` to find the repository you're working in.
2. Call `list-worktrees` with the repo path to see existing worktrees.
3. Ask the user what branch name to use for the new worktree.
4. Call `create-agent` with `createWorktree: true`, the repo path, and the branch name. Use your agent type and a descriptive name.
5. Once the new agent is created, inform the user they can switch to it in Skwad.
