import SwiftUI

/// Modifier key codes used for push-to-talk configuration
enum ModifierKeyCode: UInt16, CaseIterable {
  case rightCommand = 54
  case leftCommand = 55
  case leftShift = 56
  case capsLock = 57
  case leftOption = 58
  case leftControl = 59
  case rightShift = 60
  case rightOption = 61
  case rightControl = 62
  case function = 63

  var displayName: String {
    switch self {
    case .rightCommand: "Right Command"
    case .leftCommand: "Left Command"
    case .leftShift: "Left Shift"
    case .rightShift: "Right Shift"
    case .leftOption: "Left Option"
    case .rightOption: "Right Option"
    case .leftControl: "Left Control"
    case .rightControl: "Right Control"
    case .capsLock: "Caps Lock"
    case .function: "Fn"
    }
  }

  static func name(for keyCode: Int) -> String {
    ModifierKeyCode(rawValue: UInt16(keyCode))?.displayName ?? "Key \(keyCode)"
  }

  static let allKeyCodes: Set<UInt16> = Set(allCases.map(\.rawValue))
}

struct VoiceSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  @State private var pushToTalk = PushToTalkMonitor.shared
  @State private var isRecordingKey = false

  private let voiceEngines = [
    ("apple", "Apple SpeechAnalyzer")
  ]

  var body: some View {
    Form {
      Section {
        Text("Voice input allows you to speak commands to your agents using push-to-talk. Hold the configured key to record, release to stop.")
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } header: {
        Text("About")
      }

      Section {
        Toggle("Enable voice input", isOn: $settings.voiceEnabled)

        Picker("Engine", selection: $settings.voiceEngine) {
          ForEach(voiceEngines, id: \.0) { engine in
            Text(engine.1).tag(engine.0)
          }
        }
        .disabled(!settings.voiceEnabled)
      } header: {
        Text("Engine")
      } footer: {
        Text("Uses on-device speech recognition. No data is sent to the cloud.")
          .foregroundColor(.secondary)
      }

      Section {
        LabeledContent("Push-to-Talk Key") {
          Button(isRecordingKey ? "Press any key..." : keyName(for: settings.voicePushToTalkKey)) {
            isRecordingKey = true
          }
          .buttonStyle(.bordered)
          .background(
            KeyRecorderView(isRecording: $isRecordingKey) { keyCode in
              settings.voicePushToTalkKey = Int(keyCode)
            }
          )
        }
        .disabled(!settings.voiceEnabled)

        Toggle("Auto-insert transcription", isOn: $settings.voiceAutoInsert)
          .disabled(!settings.voiceEnabled)
      } header: {
        Text("Input")
      } footer: {
        Text(settings.voiceAutoInsert
             ? "Transcribed text will be automatically inserted into the terminal."
             : "Transcribed text will be shown in a popup for review before insertion.")
        .foregroundColor(.secondary)
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .padding()
    .onChange(of: isRecordingKey) { _, recording in
      // Stop push-to-talk monitor while recording a new key
      if recording {
        pushToTalk.stop()
      } else if settings.voiceEnabled {
        pushToTalk.start()
      }
    }
  }

  private func keyName(for keyCode: Int) -> String {
    ModifierKeyCode.name(for: keyCode)
  }
}

/// Hidden view that captures key events for recording push-to-talk key
struct KeyRecorderView: NSViewRepresentable {
  @Binding var isRecording: Bool
  let onKeyRecorded: (UInt16) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = KeyRecorderNSView()
    view.onKeyRecorded = { keyCode in
      onKeyRecorded(keyCode)
      isRecording = false
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let view = nsView as? KeyRecorderNSView else { return }
    view.isRecording = isRecording
    if isRecording {
      nsView.window?.makeFirstResponder(nsView)
    }
  }
}

class KeyRecorderNSView: NSView {
  var isRecording = false
  var onKeyRecorded: ((UInt16) -> Void)?

  override var acceptsFirstResponder: Bool { isRecording }

  override func keyDown(with event: NSEvent) {
    guard isRecording, ModifierKeyCode.allKeyCodes.contains(event.keyCode) else { return }
    onKeyRecorded?(event.keyCode)
  }

  override func flagsChanged(with event: NSEvent) {
    guard isRecording, ModifierKeyCode.allKeyCodes.contains(event.keyCode) else { return }
    onKeyRecorded?(event.keyCode)
  }
}
