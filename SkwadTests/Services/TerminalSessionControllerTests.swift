import Foundation
import Testing
@testable import Skwad

@Suite("TerminalSessionController", .serialized)
struct TerminalSessionControllerTests {

    // MARK: - Test Helpers

    /// Create a controller with a mock adapter attached
    @MainActor
    static func createController(
        activityTracking: ActivityTracking = .all,
        idleTimeout: TimeInterval = 0.1
    ) -> (TerminalSessionController, MockTerminalAdapter) {
        let controller = TerminalSessionController(
            agentId: UUID(),
            folder: "/tmp/test",
            agentType: "claude",
            activityTracking: activityTracking,
            idleTimeout: idleTimeout,
            onStatusChange: { _, _ in }
        )

        let adapter = MockTerminalAdapter()
        controller.attach(to: adapter)

        return (controller, adapter)
    }

    /// Create a hook-managed controller (activityTracking = .userInput)
    @MainActor
    static func createHookController(
        idleTimeout: TimeInterval = 0.1
    ) -> (TerminalSessionController, MockTerminalAdapter) {
        return createController(activityTracking: .userInput, idleTimeout: idleTimeout)
    }

    // MARK: - Blocked Status

    @Suite("Blocked Status")
    struct BlockedStatusTests {

        @Test("setting blocked status on controller is reflected")
        @MainActor
        func setBlockedStatus() async {
            let (controller, _) = TerminalSessionControllerTests.createController()
            controller.status = .blocked
            #expect(controller.status == .blocked)
        }

        @Test("return key unblocks to running")
        @MainActor
        func returnKeyUnblocksToRunning() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .blocked

            adapter.simulateUserInput(keyCode: 36) // Return

            #expect(controller.status == .running)
        }

        @Test("escape key unblocks to idle")
        @MainActor
        func escapeKeyUnblocksToIdle() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .blocked

            adapter.simulateUserInput(keyCode: 53) // Escape

            #expect(controller.status == .idle)
        }

        @Test("arrow keys do not unblock")
        @MainActor
        func arrowKeysDoNotUnblock() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .blocked

            adapter.simulateUserInput(keyCode: 125) // Down arrow
            #expect(controller.status == .blocked)

            adapter.simulateUserInput(keyCode: 126) // Up arrow
            #expect(controller.status == .blocked)
        }

        @Test("regular keys do not unblock")
        @MainActor
        func regularKeysDoNotUnblock() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()
            controller.status = .blocked

            adapter.simulateUserInput(keyCode: 0) // a key
            #expect(controller.status == .blocked)

            adapter.simulateUserInput(keyCode: 49) // space
            #expect(controller.status == .blocked)
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

            // Status should still be idle
            #expect(controller.status == .idle)
        }

        @Test("terminal output is ignored for hook agents")
        @MainActor
        func terminalOutputIgnored() async {
            let (controller, adapter) = TerminalSessionControllerTests.createHookController()

            adapter.simulateActivity()

            // Status should still be idle
            #expect(controller.status == .idle)
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

        @Test("hook agents use userInput-only tracking")
        @MainActor
        func hookAgentsUserInputOnly() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                activityTracking: .userInput
            )
            #expect(controller.activityTracking == .userInput)
            #expect(controller.activityTracking.contains(.userInput))
            #expect(!controller.activityTracking.contains(.terminalOutput))
        }

        @Test("regular agents use full tracking")
        @MainActor
        func regularAgentsFullTracking() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                activityTracking: .all
            )
            #expect(controller.activityTracking == .all)
            #expect(controller.activityTracking.contains(.userInput))
            #expect(controller.activityTracking.contains(.terminalOutput))
        }

        @Test("hook registration downgrades from all to userInput")
        @MainActor
        func hookRegistrationDowngrades() async {
            let (controller, _) = TerminalSessionControllerTests.createController(
                activityTracking: .all
            )
            #expect(controller.activityTracking == .all)

            controller.setActivityTracking(.userInput)

            #expect(controller.activityTracking == .userInput)
            #expect(!controller.activityTracking.contains(.terminalOutput))
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

        @Test("setActivityTracking downgrades tracking")
        @MainActor
        func setActivityTrackingDowngrades() async {
            let (controller, adapter) = TerminalSessionControllerTests.createController(
                activityTracking: .all
            )

            // Terminal output should work initially
            adapter.simulateActivity()
            #expect(controller.status == .running)

            // Downgrade to userInput only
            controller.setActivityTracking(.userInput)

            // Reset to idle
            controller.status = .idle

            // Terminal output should now be ignored
            adapter.simulateActivity()
            #expect(controller.status == .idle)
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
