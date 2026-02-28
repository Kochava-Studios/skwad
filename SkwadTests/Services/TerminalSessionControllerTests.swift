import Foundation
import Testing
@testable import Skwad

@Suite("TerminalSessionController", .serialized)
struct TerminalSessionControllerTests {

    // MARK: - Test Helpers

    /// Create a controller with a mock adapter attached
    @MainActor
    static func createController(
        agentType: String = "claude",
        activityTracking: ActivityTracking = .all,
        idleTimeout: TimeInterval = 0.1
    ) -> (TerminalSessionController, MockTerminalAdapter) {
        let controller = TerminalSessionController(
            agentId: UUID(),
            folder: "/tmp/test",
            agentType: agentType,
            activityTracking: activityTracking,
            idleTimeout: idleTimeout,
            onStatusChange: { _, _ in }
        )

        let adapter = MockTerminalAdapter()
        controller.attach(to: adapter)

        return (controller, adapter)
    }

    /// Create a hook-managed controller (claude agent with .all tracking and longer timeout)
    @MainActor
    static func createHookController(
        idleTimeout: TimeInterval = 0.1
    ) -> (TerminalSessionController, MockTerminalAdapter) {
        return createController(agentType: "claude", activityTracking: .all, idleTimeout: idleTimeout)
    }

    // MARK: - Input Status

    @Suite("Input Status")
    struct InputStatusTests {

        @Test("setting input status on controller is reflected")
        @MainActor
        func setInputStatus() async {
            let (controller, _) = TerminalSessionControllerTests.createController()
            controller.status = .input
            #expect(controller.status == .input)
        }

        @Test("return key exits input to running")
        @MainActor
        func returnKeyExitsInputToRunning() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .input

            adapter.simulateUserInput(keyCode: 36) // Return

            #expect(controller.status == .running)
        }

        @Test("escape key exits input to idle")
        @MainActor
        func escapeKeyExitsInputToIdle() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .input

            adapter.simulateUserInput(keyCode: 53) // Escape

            #expect(controller.status == .idle)
        }

        @Test("arrow keys do not exit input")
        @MainActor
        func arrowKeysDoNotExitInput() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .input

            adapter.simulateUserInput(keyCode: 125) // Down arrow
            #expect(controller.status == .input)

            adapter.simulateUserInput(keyCode: 126) // Up arrow
            #expect(controller.status == .input)
        }

        @Test("regular keys do not exit input")
        @MainActor
        func regularKeysDoNotExitInput() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .input

            adapter.simulateUserInput(keyCode: 0) // a key
            #expect(controller.status == .input)

            adapter.simulateUserInput(keyCode: 49) // space
            #expect(controller.status == .input)
        }

    }

    // MARK: - Input Protection

    @Suite("Input Protection")
    struct InputProtectionTests {

        @Test("injectText works when input is not protected")
        @MainActor
        func injectTextWorksNormally() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController()

            controller.injectText("hello")

            #expect(adapter.sentTexts.contains("hello"))
        }

        @Test("injectText is blocked after user keypress")
        @MainActor
        func injectTextBlockedAfterKeypress() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController()

            // Simulate user typing
            adapter.simulateUserInput(keyCode: 0)

            // Clear recorded texts from any side effects
            adapter.reset()

            // Try to inject — should be blocked
            controller.injectText("should not appear")

            #expect(!adapter.sentTexts.contains("should not appear"))
        }

        @Test("sendCommand still works during input protection")
        @MainActor
        func sendCommandNotBlocked() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController()

            // Simulate user typing to activate protection
            adapter.simulateUserInput(keyCode: 0)
            adapter.reset()

            // sendCommand should bypass protection (it's explicit, not automatic)
            controller.sendCommand("explicit command")

            #expect(adapter.sentTexts.contains("explicit command"))
        }
    }

    // MARK: - Hook-Managed Agents

    @Suite("Hook-Managed Agents")
    struct HookManagedTests {

        @Test("user input does not change status for hook agents")
        @MainActor
        func userInputDoesNotChangeStatus() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .idle

            adapter.simulateUserInput(keyCode: 0) // regular key

            // Hook agents: user input doesn't drive status state machine
            #expect(controller.status == .idle)
        }

        @Test("terminal output sets running for hook agents")
        @MainActor
        func terminalOutputSetsRunning() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .idle

            adapter.simulateActivity()

            #expect(controller.status == .running)
        }

        @Test("terminal output schedules idle timer for hook agents")
        @MainActor
        func terminalOutputSchedulesIdleTimer() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController(idleTimeout: 0.05)
            controller.status = .idle

            adapter.simulateActivity()
            #expect(controller.status == .running)

            // Wait for idle timer to fire
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            #expect(controller.status == .idle)
        }

        @Test("idle timer does not override input status")
        @MainActor
        func idleTimerDoesNotOverrideInput() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController(idleTimeout: 0.05)

            // Terminal output sets running + schedules idle timer
            adapter.simulateActivity()
            #expect(controller.status == .running)

            // Set blocked (e.g. permission prompt hook)
            controller.status = .input

            // Wait for idle timer to fire
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            // Should still be blocked
            #expect(controller.status == .input)
        }

        @Test("user input still activates input protection for hook agents")
        @MainActor
        func userInputActivatesInputProtection() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()

            adapter.simulateUserInput(keyCode: 0)
            adapter.reset()

            controller.injectText("should not appear")
            #expect(!adapter.sentTexts.contains("should not appear"))
        }
    }

    // MARK: - Activity Tracking Rules

    @Suite("Activity Tracking Rules")
    struct ActivityTrackingRulesTests {

        @Test("shell agents have no tracking")
        @MainActor
        func shellAgentsNoTracking() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                activityTracking: .none
            )
            #expect(controller.activityTracking.isEmpty)
            #expect(!controller.activityTracking.contains(.userInput))
            #expect(!controller.activityTracking.contains(.terminalOutput))
        }

        @Test("hook agents use full tracking with longer timeout")
        @MainActor
        func hookAgentsFullTracking() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                activityTracking: .all
            )
            #expect(controller.activityTracking == .all)
            #expect(controller.activityTracking.contains(.userInput))
            #expect(controller.activityTracking.contains(.terminalOutput))
        }

        @Test("regular agents use full tracking")
        @MainActor
        func regularAgentsFullTracking() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                agentType: "codex",
                activityTracking: .all
            )
            #expect(controller.activityTracking == .all)
            #expect(controller.activityTracking.contains(.userInput))
            #expect(controller.activityTracking.contains(.terminalOutput))
        }

        @Test("usesActivityHooks returns true for claude")
        func claudeUsesHooks() {
            #expect(TerminalCommandBuilder.usesActivityHooks(agentType: "claude"))
        }

        @Test("usesActivityHooks returns false for shell")
        func shellDoesNotUseHooks() {
            #expect(!TerminalCommandBuilder.usesActivityHooks(agentType: "shell"))
        }
    }

    // MARK: - Activity Tracking

    @Suite("Activity Tracking")
    struct ActivityTrackingTests {

        @Test("shell agents (no tracking) are always idle")
        @MainActor
        func shellAgentsAlwaysIdle() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController(
                activityTracking: .none
            )

            adapter.simulateActivity()
            #expect(controller.status == .idle)

            adapter.simulateUserInput(keyCode: 0)
            #expect(controller.status == .idle)
        }

        @Test("terminal output sets running for regular agents")
        @MainActor
        func terminalOutputSetsRunning() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController(
                agentType: "aider"
            )

            adapter.simulateActivity()
            #expect(controller.status == .running)
        }

        @Test("user input sets running for regular agents")
        @MainActor
        func userInputSetsRunning() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController(
                agentType: "aider"
            )
            controller.status = .idle

            adapter.simulateUserInput(keyCode: 0)
            #expect(controller.status == .running)
        }

        @Test("dispose invalidates timers and terminates adapter")
        @MainActor
        func disposeCleanup() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController()

            controller.dispose()

            #expect(adapter.terminateCalls == 1)
        }
    }
}
