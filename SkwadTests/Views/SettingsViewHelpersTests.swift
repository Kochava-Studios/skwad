import Testing
import SwiftUI
@testable import Skwad

@Suite("SettingsView Helpers")
struct SettingsViewHelpersTests {

    // MARK: - Key Name Mapping

    /// Helper that mirrors the keyName logic from VoiceSettingsView
    static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case 54: return "Right Command"
        case 55: return "Left Command"
        case 56: return "Left Shift"
        case 60: return "Right Shift"
        case 58: return "Left Option"
        case 61: return "Right Option"
        case 59: return "Left Control"
        case 62: return "Right Control"
        case 57: return "Caps Lock"
        case 63: return "Fn"
        default: return "Key \(keyCode)"
        }
    }

    @Suite("Key Name Mapping")
    struct KeyNameMappingTests {

        @Test("right command key code 54")
        func rightCommandKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 54) == "Right Command")
        }

        @Test("left command key code 55")
        func leftCommandKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 55) == "Left Command")
        }

        @Test("left shift key code 56")
        func leftShiftKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 56) == "Left Shift")
        }

        @Test("right shift key code 60")
        func rightShiftKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 60) == "Right Shift")
        }

        @Test("left option key code 58")
        func leftOptionKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 58) == "Left Option")
        }

        @Test("right option key code 61")
        func rightOptionKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 61) == "Right Option")
        }

        @Test("left control key code 59")
        func leftControlKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 59) == "Left Control")
        }

        @Test("right control key code 62")
        func rightControlKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 62) == "Right Control")
        }

        @Test("caps lock key code 57")
        func capsLockKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 57) == "Caps Lock")
        }

        @Test("fn key code 63")
        func fnKeyCode() {
            #expect(SettingsViewHelpersTests.keyName(for: 63) == "Fn")
        }

        @Test("unknown key code returns generic name")
        func unknownKeyCodeReturnsGeneric() {
            #expect(SettingsViewHelpersTests.keyName(for: 100) == "Key 100")
            #expect(SettingsViewHelpersTests.keyName(for: 0) == "Key 0")
            #expect(SettingsViewHelpersTests.keyName(for: -1) == "Key -1")
        }
    }
}
