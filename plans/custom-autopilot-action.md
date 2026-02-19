# Custom Autopilot Action

## Goal

Add a 4th autopilot action — **Custom** — where the user provides their own system prompt. When an agent goes idle, the LLM receives the agent's last message + the user's prompt, and returns the exact text to inject into the agent (or empty = do nothing). This turns autopilot into a fully programmable feature.

## Design

### How it works

1. Agent goes idle → `ClaudeHookHandler` triggers autopilot (unchanged)
2. Instead of tri-classification, the LLM is called with:
   - **System**: user's custom instructions (from settings)
   - **User**: agent's last message
3. LLM returns free-form text
4. If response is empty / whitespace / "EMPTY" → no-op
5. Otherwise → set `.input` status + inject the response text into the agent

### Key decisions

- **Skip classification entirely** for custom action — the user's prompt handles everything
- **maxTokens**: 1024 for custom path (vs 16 for classification)
- **Empty signal**: trim response; if empty OR case-insensitive "EMPTY" → no-op
- **Error fallback**: on LLM error, fall back to mark behavior (safe default)
- **Default placeholder prompt**: provide a sensible example in the UI so users get it immediately

## Implementation

### Phase 1: Settings — new action + custom prompt field

**Files:** `AutopilotSettingsView.swift`, `AppSettings.swift`

- [ ] Add `.custom` case to `AutopilotAction` enum with displayName "Custom" and description
- [ ] Add `@AppStorage("autopilotCustomPrompt")` to `AppSettings` (default empty string)
- [ ] In `AutopilotSettingsView`, when action == "custom", show a `TextEditor` for the custom prompt
- [ ] Add placeholder/helper text explaining the expected format
- [ ] Build and verify settings UI

**Commit:** `feat: add custom autopilot action with prompt editor in settings`

### Phase 2: Custom LLM call path in AutopilotService

**Files:** `AutopilotService.swift`

- [ ] Add `callLLMCustom(message:systemPrompt:provider:apiKey:)` that calls the LLM with user's prompt as system + agent message as user, with maxTokens=1024
- [ ] Add `analyzeCustom(lastMessage:customPrompt:agentId:agentName:)` that calls `callLLMCustom`, parses the response (empty/"EMPTY" check), and dispatches
- [ ] Add `isEmptyResponse(_:)` static helper: trims whitespace, returns true if empty or equals "EMPTY" (case-insensitive)
- [ ] Update `analyze()` to check if action is `.custom` → route to `analyzeCustom` instead of classify+dispatch
- [ ] On non-empty response: set `.input` status + inject text
- [ ] On LLM error: fall back to `markInput`

**Commit:** `feat: custom autopilot LLM call path with text injection`

### Phase 3: Read custom prompt in SettingsSnapshot

**Files:** `AutopilotService.swift`

- [ ] Add `customPrompt: String` to `SettingsSnapshot`
- [ ] Read `settings.autopilotCustomPrompt` in `readSettings()`
- [ ] Pass it through to `analyzeCustom`

**Commit:** (squash with Phase 2 commit)

### Phase 4: Tests

**Files:** `SkwadTests/Services/AutopilotServiceTests.swift`

- [ ] Test `isEmptyResponse` with: empty string, whitespace, "EMPTY", "empty", "Empty", " EMPTY ", actual text, "EMPTY but not really"
- [ ] Build + run all tests

**Commit:** `test: add custom autopilot response parsing tests`

## Files Changed

| File | Change |
|---|---|
| `Skwad/Views/Settings/AutopilotSettingsView.swift` | Add `.custom` to enum, add TextEditor UI |
| `Skwad/Models/AppSettings.swift` | Add `autopilotCustomPrompt` property |
| `Skwad/Services/AutopilotService.swift` | Add custom LLM call path, `isEmptyResponse`, routing |
| `SkwadTests/Services/AutopilotServiceTests.swift` | Add `isEmptyResponse` tests |

## Key Learnings (to be filled after implementation)

