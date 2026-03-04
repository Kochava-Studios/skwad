# Coding Agents - CLI Arguments

This document tracks the CLI arguments across supported coding agents.

> **Note**: This file is referenced by `Skwad/Services/TerminalCommandBuilder.swift` - keep it updated when adding new agents or discovering new CLI options.

## Arguments Reference

| Intent | Claude Code | Codex | OpenCode | Gemini CLI | GitHub Copilot |
|--------|-------------|-------|----------|------------|----------------|
| **System Prompt** | `--append-system-prompt "..."` | `-c 'developer_instructions=...'` | N/A | N/A | N/A |
| **User Prompt** | Last argument (no flag) | Last argument (no flag) | `--prompt "..."` | `--prompt-interactive "..."` | `--interactive "..."` |
| **MCP Config** | `--mcp-config '<json>'` | N/A | N/A | N/A | `--additional-mcp-config '<json>'` |
| **MCP Server Filter** | N/A | N/A | N/A | `--allowed-mcp-server-names` | N/A |
| **Allowed Tools** | `--allowed-tools 'mcp__skwad__*'` | N/A | N/A | N/A | `--allow-tool 'skwad(<tool>)'` (per tool) |
| **Hooks / Plugins** | `--plugin-dir "<path>"` | `-c 'notify=["bash","<script>"]'` | N/A | N/A | N/A |
| **Resume Conversation** | `--resume <session-id>` | `codex resume <thread-id>` | `-c` / `-s <session-id>` | N/A | N/A |
| **Fork Conversation** | `--fork-session` (with `--resume`) | `codex fork <thread-id>` | `--fork` (with `-c` or `-s`) | N/A | N/A |
| **Inline Registration** | Yes (system + user prompt) | Yes (system + user prompt) | Yes (user prompt) | Yes (user prompt) | Yes (user prompt) |
| **Activity Detection** | Hook-based (plugin) | Hook-based (notify script) | Terminal output | Terminal output | Terminal output |
| **Session ID Source** | `session_id` (hook payload) | `thread-id` (hook payload) | N/A | N/A | N/A |
| **History Storage** | JSONL in `~/.claude/projects/` | SQLite `~/.codex/state_5.sqlite` | N/A | N/A | N/A |

## Usage in Skwad

These arguments are used by `TerminalCommandBuilder.swift` to:
1. Inject MCP server configuration
2. Add inline registration prompts so agents auto-register with the skwad
3. Configure hook-based activity detection (Claude, Codex)
4. Resume/fork previous conversations (Claude, Codex)
