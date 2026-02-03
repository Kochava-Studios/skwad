import Foundation
import AppKit
import Observation

/// Monitors global key events for push-to-talk functionality
@Observable
final class PushToTalkMonitor {
    static let shared = PushToTalkMonitor()

    var isKeyDown = false

    private var flagsMonitor: Any?
    private let settings = AppSettings.shared

    private init() {
    }

    func start() {

        // Skip initialization in Xcode Previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        stop()  // Ensure no duplicate monitors

        // Monitor flags changed events (modifier keys)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Also monitor local events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard settings.voiceEnabled else { return }

        let targetKeyCode = UInt16(settings.voicePushToTalkKey)

        // Check if this is our target key
        guard event.keyCode == targetKeyCode else { return }

        // Determine if key is pressed or released based on modifier flags
        let isPressed = isModifierPressed(keyCode: targetKeyCode, flags: event.modifierFlags)

        DispatchQueue.main.async {
            self.isKeyDown = isPressed
        }
    }

    private func isModifierPressed(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55:  // Command keys
            return flags.contains(.command)
        case 56, 60:  // Shift keys
            return flags.contains(.shift)
        case 58, 61:  // Option keys
            return flags.contains(.option)
        case 59, 62:  // Control keys
            return flags.contains(.control)
        case 57:  // Caps Lock
            return flags.contains(.capsLock)
        case 63:  // Fn
            return flags.contains(.function)
        default:
            return false
        }
    }
}
