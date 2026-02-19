import AppKit
import UserNotifications

/// Handles macOS desktop notifications for agent events (e.g. awaiting input).
/// Notification clicks switch to the relevant workspace and agent.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private weak var agentManager: AgentManager?
    private let settings = AppSettings.shared

    private override init() {
        super.init()
    }

    /// Call once at startup to configure the notification center delegate and request permission.
    func setup(agentManager: AgentManager) {
        self.agentManager = agentManager
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Send a desktop notification when an agent is awaiting input.
    /// Skipped if agent is already awaiting input (dedup) or currently visible on screen.
    func notifyAwaitingInput(agent: Agent, message: String? = nil) {
        guard settings.desktopNotificationsEnabled else { return }

        // Skip if agent is already awaiting input (second hook for same event)
        if let current = agentManager?.agents.first(where: { $0.id == agent.id }),
           current.status == .input { return }

        // Skip if agent is currently displayed
        if let manager = agentManager,
           manager.activeAgentIds.contains(agent.id) { return }

        let content = UNMutableNotificationContent()
        content.title = "Skwad - \(agent.name)"
        content.body = message ?? "Needs your attention"
        content.sound = .default
        content.userInfo = ["agentId": agent.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "input-\(agent.id.uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Agent Navigation

    /// Switch to the workspace containing the given agent and bring the window to front.
    func switchToAgent(_ agent: Agent) {
        guard let manager = agentManager else { return }
        if let workspace = manager.workspaces.first(where: { $0.agentIds.contains(agent.id) }) {
            manager.switchToWorkspace(workspace.id)
        }
        manager.selectAgent(agent.id)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification click: switch to the workspace/agent.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let agentIdString = userInfo["agentId"] as? String,
              let agentId = UUID(uuidString: agentIdString) else {
            completionHandler()
            return
        }

        Task { @MainActor in
            guard let manager = self.agentManager,
                  let agent = manager.agents.first(where: { $0.id == agentId }) else {
                completionHandler()
                return
            }
            self.switchToAgent(agent)
            completionHandler()
        }
    }

    /// Show notifications even when app is in foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
