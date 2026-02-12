import AppKit
import UserNotifications

/// Handles macOS desktop notifications for agent events (e.g. blocked status).
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

    /// Send a desktop notification when an agent becomes blocked.
    func notifyBlocked(agent: Agent, message: String? = nil) {
        guard settings.desktopNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Skwad - \(agent.name)"
        content.body = message ?? "Needs your attention"
        content.sound = .default
        content.userInfo = ["agentId": agent.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "blocked-\(agent.id.uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
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
            guard let manager = self.agentManager else {
                completionHandler()
                return
            }

            // Find which workspace contains this agent and switch to it
            if let workspace = manager.workspaces.first(where: { $0.agentIds.contains(agentId) }) {
                manager.switchToWorkspace(workspace.id)
            }
            manager.selectAgent(agentId)

            // Bring window to front
            NSApp.activate()
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)

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
