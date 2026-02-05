# Coding Agents - CLI Arguments

This document tracks the CLI arguments for system prompts and user prompts across supported coding agents.

> **Note**: This file is referenced by `Skwad/Services/TerminalCommandBuilder.swift` - keep it updated when adding new agents or discovering new CLI options.

## Arguments Reference

| Agent | System Prompt | User Prompt | Other |
|-------|--------------|-------------|-------|
| **Claude Code** | `--append-system-prompt "..."` | Last argument (no flag) | |
| **Codex** | N/A | Last argument (no flag) | |
| **OpenCode** | N/A | `--prompt "..."` | |
| **Gemini CLI** | N/A | `--prompt-interactive "..."` | |
| **GitHub Copilot** | N/A | `--interactive "..."` | |

## Status

- **Claude Code**: Fully implemented (system prompt + user prompt)
- **Codex**: Implemented (user prompt only)
- **OpenCode**: Implemented (user prompt only)
- **Gemini CLI**: Implemented (user prompt only)
- **GitHub Copilot**: Implemented (user prompt only)

## Usage in Skwad

These arguments are used by `TerminalCommandBuilder.swift` to:
1. Inject MCP server configuration
2. Add inline registration prompts so agents auto-register with the skwad
