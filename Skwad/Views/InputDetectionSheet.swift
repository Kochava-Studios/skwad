import SwiftUI

/// A floating panel shown when AI input detection determines an agent needs user attention.
/// Presents the last agent message and offers actions: switch to agent, dismiss, or auto-continue.
struct InputDetectionSheet: View {
    let agent: Agent
    let lastMessage: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {

            // Header with agent avatar + name
            HStack(spacing: 10) {
                Text(agent.avatar ?? "🤖")
                    .font(.title)
                Text(agent.name)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Agent's last message
            ScrollView {
                Text(lastMessage)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)

            Divider()

            // Action buttons
            HStack {
                Button("Dismiss") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Switch to Agent") {
                    NotificationService.shared.switchToAgent(agent)
                    dismiss()
                }

                Button("Continue") {
                    NotificationService.shared.injectText("yes, continue", for: agent.id)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    // MARK: - Window Presentation

    /// Strong reference to the active panel so it isn't deallocated.
    @MainActor private static var activePanel: NSPanel?

    @MainActor
    static func show(agent: Agent, lastMessage: String) {
        // Close any existing panel first
        activePanel?.close()
        activePanel = nil

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 350),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Input Detected — \(agent.name)"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let view = InputDetectionSheet(
            agent: agent,
            lastMessage: lastMessage,
            dismiss: {
                panel.close()
                InputDetectionSheet.activePanel = nil
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        activePanel = panel
    }
}
