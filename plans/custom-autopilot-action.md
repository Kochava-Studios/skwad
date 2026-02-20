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

### Phase 1: Settings — new action + custom prompt field ✅

**Files:** `AutopilotSettingsView.swift`, `AppSettings.swift`

- [x] Add `.custom` case to `AutopilotAction` enum with displayName "Custom" and description
- [x] Add `@AppStorage("autopilotCustomPrompt")` to `AppSettings` (default empty string)
- [x] In `AutopilotSettingsView`, when action == "custom", show a `TextEditor` for the custom prompt
- [x] Add placeholder/helper text explaining the expected format
- [x] Build and verify settings UI

### Phase 2: Custom LLM call path in AutopilotService ✅

**Files:** `AutopilotService.swift`

- [x] Add `callLLMCustom(message:systemPrompt:provider:apiKey:)` that calls the LLM with user's prompt as system + agent message as user, with maxTokens=1024
- [x] Add `analyzeCustom(lastMessage:customPrompt:agentId:agentName:)` that calls `callLLMCustom`, parses the response (empty/"EMPTY" check), and dispatches
- [x] Add `isEmptyResponse(_:)` static helper: trims whitespace, returns true if empty or equals "EMPTY" (case-insensitive)
- [x] Update `analyze()` to check if action is `.custom` → route to `analyzeCustom` instead of classify+dispatch
- [x] On non-empty response: set `.input` status + inject text
- [x] On LLM error: fall back to `markInput`

### Phase 3: Read custom prompt in SettingsSnapshot ✅

**Files:** `AutopilotService.swift`

- [x] Add `customPrompt: String` to `SettingsSnapshot`
- [x] Read `settings.autopilotCustomPrompt` in `readSettings()`
- [x] Pass it through to `analyzeCustom`

### Phase 4: Tests ✅

**Files:** `SkwadTests/Services/AutopilotServiceTests.swift`

- [x] Test `isEmptyResponse` with: empty string, whitespace, "EMPTY", "empty", "Empty", " EMPTY ", actual text, "EMPTY but not really"
- [x] Build passes

**Commit:** `feat: custom autopilot action with user-defined prompt` (b9a6c30)

## Files Changed

| File | Change |
|---|---|
| `Skwad/Views/Settings/AutopilotSettingsView.swift` | Add `.custom` to enum, add TextEditor UI |
| `Skwad/Models/AppSettings.swift` | Add `autopilotCustomPrompt` property |
| `Skwad/Services/AutopilotService.swift` | Add custom LLM call path, `isEmptyResponse`, routing |
| `SkwadTests/Services/AutopilotServiceTests.swift` | Add `isEmptyResponse` tests |

## Key Learnings

- The custom path cleanly bypasses tri-classification — keeping the two paths independent avoids coupling and makes both easier to reason about.
- Using `isEmptyResponse` as a static method allows direct testing without actor isolation concerns — same pattern as `parseResponse`.
- Duplicating provider-specific LLM calls (callOpenAICustom etc.) is preferable to parameterizing the originals — the classification calls have maxTokens=16 and a fixed system prompt, while custom needs maxTokens=1024 and a user-provided prompt. Different enough to warrant separate methods.
