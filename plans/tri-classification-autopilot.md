# Tri-Classification Autopilot

## Goal

Refine the autopilot feature from binary (yes/no) classification to three-way classification (completed/binary/open), with different action behavior per classification.

## Classifications

| Classification | Examples | Meaning |
|---|---|---|
| `completed` | "Tests are passing now", "I've finished the refactoring" | Agent is done, no input needed |
| `binary` | "Should I proceed?", "Should I reply to Ellie?" | Agent wants a yes/no go-ahead |
| `open` | "Provide feedback on the plan", "Which option: A or B?" | Agent needs real user input |

## Action Matrix

All autopilot actions set `.input` status when input is detected. `completed` always = no-op (agent stays idle).

| Action \ Classification | `completed` | `binary` | `open` |
|---|---|---|---|
| **Mark** | — | `.input` + notification | `.input` + notification |
| **Ask** | — | dialog (Continue=default) | dialog (Switch=default, no Continue) |
| **Auto-continue** | — | inject "yes, continue" | fallback → `.input` + notification |

## Implementation

### Phase 1: Classification enum + prompt

**Files:** `InputDetectionService.swift`, `AutopilotSettingsView.swift`

- [ ] Add `InputClassification` enum: `.completed`, `.binary`, `.open`
- [ ] Rewrite `classificationPrompt` for three-way output (`completed` / `binary` / `open`)
- [ ] Update `parseResponse` to return `InputClassification` instead of `Bool`
- [ ] Update `classify()` return type to `InputClassification`

**Commit:** `feat: tri-classification prompt for autopilot`

### Phase 2: Action dispatch with classification

**Files:** `InputDetectionService.swift`

- [ ] Update `analyze()` to use `InputClassification`
- [ ] Update `dispatchAction()` signature to take classification
- [ ] `completed` → early return (no action for any setting)
- [ ] `.mark`: set `.input` + notification for both `binary` and `open`
- [ ] `.ask`: pass classification to sheet (next phase) — for now set `.input` + show sheet for both
- [ ] `.continue` + `binary`: inject text (existing behavior)
- [ ] `.continue` + `open`: fallback to mark behavior (`.input` + notification)
- [ ] All actions that detect input set `.input` status (`.ask` and `.continue` currently don't)

**Commit:** `feat: action dispatch based on classification type`

### Phase 3: Adaptive InputDetectionSheet

**Files:** `InputDetectionSheet.swift`

- [ ] Add `classification: InputClassification` parameter to `InputDetectionSheet`
- [ ] Update `show()` to accept and pass classification
- [ ] When `classification == .binary`: keep current layout (Continue = default, Return shortcut)
- [ ] When `classification == .open`: hide Continue button, Switch to Agent gets `.return` shortcut and becomes default
- [ ] Update panel title to reflect classification (e.g. "Input Needed" vs "Question from Agent")

**Commit:** `feat: adaptive input detection dialog for open vs binary`

### Phase 4: Tests

**Files:** new `SkwadTests/Services/InputDetectionServiceTests.swift`

- [ ] Test `parseResponse` with all three classifications + edge cases
- [ ] Test classification prompt examples (unit-testable without LLM)
- [ ] Build + run existing tests to verify no regressions

**Commit:** `test: add input classification parsing tests`

## Key Learnings (to be filled after implementation)

