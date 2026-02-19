import SwiftUI

/// A floating panel shown when autopilot determines an agent needs user attention.
/// Presents the last agent message and offers actions: switch to agent, dismiss, or auto-continue.
struct AutopilotDecisionSheet: View {
    let agent: Agent
    let lastMessage: String
    let classification: InputClassification
    let onDismiss: () -> Void
    let onSwitch: () -> Void
    let onContinue: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {

            // Header with agent avatar + name
            HStack(spacing: 10) {
                AvatarView(avatar: agent.avatar, size: 32, font: .title)
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

            // Action buttons — layout depends on classification
            HStack {
                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if let onContinue = onContinue {
                    // Binary: Switch + Continue (Continue is default)
                    Button("Switch to Agent") {
                        onSwitch()
                    }

                    Button("Yes, Continue") {
                        onContinue()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    // Open: only Switch (is default — user needs to go type something)
                    Button("Switch to Agent") {
                        onSwitch()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    // MARK: - Window Presentation

    /// Strong reference to the active panel so it isn't deallocated.
    @MainActor private static var activePanel: NSPanel?

    @MainActor
    static func show(agent: Agent, lastMessage: String, classification: InputClassification, agentManager: AgentManager) {
        // Close any existing panel first
        activePanel?.close()
        activePanel = nil

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 350),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = classification == .binary
            ? "Confirmation — \(agent.name)"
            : "Question — \(agent.name)"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.center()

        let closePanel = {
            panel.close()
            AutopilotDecisionSheet.activePanel = nil
        }

        let view = AutopilotDecisionSheet(
            agent: agent,
            lastMessage: lastMessage,
            classification: classification,
            onDismiss: {
                agentManager.updateStatus(for: agent.id, status: .idle)
                closePanel()
            },
            onSwitch: {
                agentManager.switchToAgent(agent)
                closePanel()
            },
            onContinue: classification == .binary ? {
                agentManager.injectText("yes, continue", for: agent.id)
                closePanel()
            } : nil
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        activePanel = panel
    }
}
