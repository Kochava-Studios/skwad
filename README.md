<p align="center">
   <img src="Skwad/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="Skwad App Icon" />
</p>

# Skwad

Meet your new, slightly revolutionary coding crew. Skwad is a macOS app that runs a whole team of AI coding agents—each in its own embedded terminal—and lets them coordinate work themselves so you can get real, parallel progress without tab chaos.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)
[![Downloads](https://img.shields.io/github/downloads/Kochava-Studios/skwad/total.svg?color=orange)](https://tooomm.github.io/github-release-stats/?username=Kochava-Studios&repository=skwad)

## Why Skwad

- **Feels like a control room:** your agents are always visible, always alive, always ready.
- **Fast, native, fluid:** GPU‑accelerated Ghostty terminals and a UI that keeps up.
- **Actually collaborative:** built‑in MCP lets agents coordinate work themselves and hand off tasks.
- **Git without context switching:** diff, stage, commit, and stay in flow.

## Features

- **Multi-agent management** - Run multiple AI coding agents simultaneously (Claude Code, Codex, OpenCode, Gemini CLI, GitHub Copilot, or custom)
- **GPU-accelerated terminals** - Powered by [libghostty](https://github.com/ghostty-org/ghostty), with SwiftTerm fallback
- **Agent-to-agent communication** - Built-in MCP server for inter-agent messaging and coordination
- **Git integration** - Worktree support, repo discovery, diff viewer, stage/commit panel
- **Activity detection** - See which agents are working or idle at a glance

## Requirements

- macOS 14.0 (Sonoma) or later
- [Zig](https://ziglang.org/) (only if building libghostty from source)
- An AI coding CLI (e.g., [Claude Code](https://github.com/anthropics/claude-code))

## Building

```bash
git clone https://github.com/anthropics/skwad.git
cd skwad

# Download prebuilt libghostty (recommended)
mkdir -p Vendor/libghostty/lib
gh release download libs-v1 -p 'libghostty.a' -D Vendor/libghostty/lib

# Or build from source (requires Zig 0.15+)
brew install zig
sudo xcodebuild -downloadComponent MetalToolchain
./scripts/build-libghostty.sh

# Open and build in Xcode
open Skwad.xcodeproj
```

## Architecture

See [AGENTS.md](AGENTS.md) for detailed architecture documentation.

## Dependencies

- [libghostty](https://github.com/ghostty-org/ghostty) - GPU-accelerated terminal
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Fallback terminal emulation
- [Hummingbird](https://github.com/hummingbird-project/hummingbird) - HTTP server for MCP
- [swift-log](https://github.com/apple/swift-log) - Logging

## License

MIT
