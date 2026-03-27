import Foundation

enum AgentPrompts {

    /// Injected when an agent has unread MCP messages
    static let checkInbox = "Check your inbox for questions or instructions from other agents. Update your status and immediately execute what is being asked without confirmation."

    /// User prompt sent to trigger the agent list table on first launch
    static let registrationUserPrompt = "List other agents names and project (no ID) in a table based on context then set your status to indicate you are ready to get going. If you don't see yourself in the table, register with the skwad."

    /// Combined registration prompt for agents without system prompt support
    static func registrationPrompt(agentId: UUID) -> String {
        "\(skwadInstructions(agentId: agentId)) Register with the skwad"
    }

    /// System instructions injected into agents that support system prompts
    static func skwadInstructions(agentId: UUID) -> String {
        "You are part of a team of agents called a skwad. A skwad is made of high-performing agents who collaborate to achieve complex goals so engage with them: ask for help and in return help them succeed. Your skwad agent ID: \(agentId.uuidString). CRITICAL RULE: Before you start working on anything, your FIRST action must be calling set-status with what you are about to do. When you finish, call set-status again. When you change direction, call set-status. Other agents depend on your status to coordinate — if you do not update it, the team cannot function. This is not optional."
    }
}
