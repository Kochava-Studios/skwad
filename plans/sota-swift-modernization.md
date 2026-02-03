# SOTA Swift Modernization Plan

This plan modernizes the Skwad codebase to use state-of-the-art Swift patterns (2026-02-03).

## Status Legend
- 🟢 Completed
- ⏭️ Skipped (not worth the complexity)

---

## Overview

The audit identified opportunities to modernize:
1. **ObservableObject → @Observable**: Modern SwiftUI state management
2. **DispatchQueue → async/await**: Modern concurrency
3. **Unsafe patterns → Safe alternatives**: Memory safety
4. **Legacy APIs → Modern APIs**: Code quality

---

## Phase 1: @Observable Migration

### 1.1 VoiceInputManager 🟢

Converted from `ObservableObject + @Published` to `@Observable` macro:
- Removed `@Published` wrappers
- Updated views to use `@State` instead of `@StateObject`
- Added `import Observation`

### 1.2 PushToTalkMonitor 🟢

Converted from `ObservableObject + @Published` to `@Observable` macro.

### 1.3 RepoDiscoveryService 🟢

Converted to `@Observable @MainActor`:
- Replaced `DispatchQueue` patterns with `Task.detached`
- Fixed FSEvents callback with `passRetained` for memory safety
- Replaced `unsafeBitCast` with `Unmanaged<CFArray>` for type safety
- Updated views to use `.onChange()` instead of `.onReceive()`

### 1.4 AgentManager 🟢

Converted to `@Observable @MainActor`:
- Replaced all `@EnvironmentObject` usages with `@Environment(AgentManager.self)`
- Replaced all `.environmentObject()` with `.environment()`
- Replaced `@StateObject` with `@State` in views
- Replaced `DispatchQueue.global().async` with `Task.detached` in `refreshGitStats`

### 1.5 AppSettings ⏭️

**SKIPPED**: AppSettings uses `@AppStorage` which is incompatible with `@Observable`. The current `ObservableObject` pattern is actually correct for persistent settings. `@AppStorage` already triggers SwiftUI updates for stored properties.

---

## Phase 2: Concurrency Modernization

### 2.1 AgentManager Git Stats 🟢

Replaced `DispatchQueue.global/main.async` with `Task.detached` + `MainActor.run`:

```swift
// Before
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    // work
    DispatchQueue.main.async {
        self?.agents[index].gitStats = stats
    }
}

// After
Task.detached(priority: .userInitiated) {
    // work
    await MainActor.run { [weak self] in
        self?.agents[index].gitStats = stats
    }
}
```

### 2.2 RepoDiscoveryService 🟢

Same pattern applied to `refreshRepos()`.

### 2.3 AsyncDelay Utility 🟢

Modernized to pure `Task.sleep`:

```swift
// Before
static func dispatch(after delay: TimeInterval, action: @escaping @MainActor () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        MainActor.assumeIsolated { action() }
    }
}

// After
static func dispatch(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) -> Task<Void, Never> {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        action()
    }
}
```

---

## Phase 3: Memory Safety

### 3.1 GitFileWatcher 🟢

Fixed unsafe `Unmanaged.passUnretained` + `unsafeBitCast` patterns:

**Before (unsafe):**
```swift
var context = FSEventStreamContext(
    info: Unmanaged.passUnretained(self).toOpaque(), // Crash if deallocated!
    ...
)
// ...
guard let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] // Fragile
```

**After (safe):**
```swift
callbackContext = Unmanaged.passRetained(self) // Holds strong reference

var context = FSEventStreamContext(
    info: callbackContext?.toOpaque(),
    ...
)

func stop() {
    // ...
    callbackContext?.release() // Properly release
    callbackContext = nil
}

// Safer path extraction
let cfArray = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue()
guard let pathArray = cfArray as? [String] else { return }
```

### 3.2 RepoDiscoveryService 🟢

Same pattern applied.

---

## Phase 4: Lower Priority (Skipped)

### 4.1 Error Logging for try? ⏭️

**SKIPPED**: The `try?` patterns in AppSettings and MCP code handle failures gracefully. Adding logging would add complexity without benefit:
- AppSettings: If JSON decoding fails, empty defaults are acceptable
- MCP: Malformed requests are expected; failures don't need logging

### 4.2 NSRegularExpression → Swift Regex ⏭️

**SKIPPED**: NSRegularExpression works fine. Swift Regex requires iOS 16+ / macOS 13+. Not worth the migration effort for working code.

---

## Summary

| Task | Status | Commit |
|------|--------|--------|
| VoiceInputManager → @Observable | 🟢 | (pending) |
| PushToTalkMonitor → @Observable | 🟢 | (pending) |
| RepoDiscoveryService → @Observable | 🟢 | (pending) |
| AgentManager → @Observable | 🟢 | (pending) |
| AppSettings → @Observable | ⏭️ | - |
| DispatchQueue → async/await | 🟢 | (pending) |
| AsyncDelay modernization | 🟢 | (pending) |
| GitFileWatcher memory safety | 🟢 | (pending) |
| RepoDiscoveryService memory safety | 🟢 | (pending) |
| Error logging | ⏭️ | - |
| Swift Regex | ⏭️ | - |

**Completed:** 9/11 tasks
**Skipped:** 3 tasks (not worth complexity)

---

## Key Learnings

### @Observable Migration Pattern

1. **Class declaration**: Add `@Observable` macro, remove `ObservableObject` conformance
2. **Properties**: Remove `@Published` - all properties are automatically observable
3. **Views consuming singleton**:
   - `@ObservedObject var x = Singleton.shared` → `@State var x = Singleton.shared`
   - `@StateObject var x = Singleton.shared` → `@State var x = Singleton.shared`
4. **Environment injection**:
   - `@EnvironmentObject var x: Type` → `@Environment(Type.self) var x`
   - `.environmentObject(x)` → `.environment(x)`
5. **Publishers**:
   - `.onReceive($property)` → `.onChange(of: property)`

### FSEvents Callback Safety

1. Use `Unmanaged.passRetained()` to hold strong reference during callback lifetime
2. Store the `Unmanaged` reference as a property for proper cleanup
3. Use `Unmanaged<CFArray>.fromOpaque()` instead of `unsafeBitCast`
4. Always release retained references in `stop()`/`deinit`

### Modern Concurrency

1. Replace `DispatchQueue.global().async` with `Task.detached(priority:)`
2. Replace `DispatchQueue.main.async` with `await MainActor.run`
3. Replace `DispatchQueue.main.asyncAfter` with `Task.sleep(for:)`
4. Capture MainActor-isolated properties before `Task.detached`:
   ```swift
   let folder = self.folder  // Capture before task
   Task.detached {
       let result = compute(folder)  // Use captured value
       await MainActor.run { self.update(result) }
   }
   ```

### When NOT to Use @Observable

- Classes using `@AppStorage` - the property wrapper is incompatible
- Classes that need Combine publishers for external subscribers
- Legacy code that heavily uses `$` bindings with Combine
