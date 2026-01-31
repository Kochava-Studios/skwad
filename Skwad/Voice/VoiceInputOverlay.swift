import SwiftUI

/// Overlay shown when voice input is active
struct VoiceInputOverlay: View {
    @ObservedObject var voiceManager: VoiceInputManager
    @ObservedObject var settings = AppSettings.shared
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Microphone indicator
            HStack(spacing: 12) {
                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                    .font(.title)
                    .foregroundColor(voiceManager.isListening ? .red : .secondary)
                    .symbolEffect(.pulse, isActive: voiceManager.isListening)

                VStack(alignment: .leading, spacing: 4) {
                    Text(voiceManager.isListening ? "Listening..." : "Voice Input")
                        .font(.headline)

                    if let error = voiceManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Hold key to record")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // Transcribed text
            if !voiceManager.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(voiceManager.transcribedText)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                }

                // Action buttons (only if not auto-insert)
                if !settings.voiceAutoInsert {
                    HStack {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .keyboardShortcut(.escape, modifiers: [])

                        Spacer()

                        Button("Insert") {
                            onInsert(voiceManager.transcribedText)
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
}

/// Container view that manages voice input state
struct VoiceInputContainer: View {
    @EnvironmentObject var agentManager: AgentManager
    @StateObject private var voiceManager = VoiceInputManager.shared
    @StateObject private var pushToTalk = PushToTalkMonitor.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var showOverlay = false

    var body: some View {
        ZStack {
            // Main content would go here (passed as child)
            Color.clear

            // Voice overlay
            if showOverlay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissOverlay()
                    }

                VoiceInputOverlay(
                    voiceManager: voiceManager,
                    onInsert: { text in
                        voiceManager.injectText(text, into: agentManager)
                        dismissOverlay()
                    },
                    onDismiss: {
                        dismissOverlay()
                    }
                )
            }
        }
        .onAppear {
            if settings.voiceEnabled {
                pushToTalk.start()
            }
        }
        .onDisappear {
            pushToTalk.stop()
        }
        .onChange(of: settings.voiceEnabled) { _, enabled in
            if enabled {
                pushToTalk.start()
            } else {
                pushToTalk.stop()
            }
        }
        .onChange(of: pushToTalk.isKeyDown) { _, isDown in
            handleKeyStateChange(isDown: isDown)
        }
    }

    private func handleKeyStateChange(isDown: Bool) {
        if isDown {
            // Key pressed - start recording
            showOverlay = true
            Task {
                await voiceManager.startListening()
            }
        } else {
            // Key released - stop recording
            voiceManager.stopListening()

            // Auto-insert if enabled and we have text
            if settings.voiceAutoInsert && !voiceManager.transcribedText.isEmpty {
                voiceManager.injectText(voiceManager.transcribedText, into: agentManager)
                dismissOverlay()
            }
        }
    }

    private func dismissOverlay() {
        voiceManager.stopListening()
        voiceManager.transcribedText = ""
        voiceManager.error = nil
        showOverlay = false
    }
}
