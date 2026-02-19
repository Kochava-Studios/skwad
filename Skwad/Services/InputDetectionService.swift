import Foundation
import Logging
import SwiftAISDK
import OpenAIProvider
import AnthropicProvider
import GoogleProvider

/// Analyzes agent messages with an LLM to determine if user input is needed.
/// When an agent goes idle, its last message is classified as "needs input" or not,
/// and an action is dispatched based on user settings.
actor InputDetectionService {
    static let shared = InputDetectionService()

    private let logger = Logger(label: "InputDetectionService")
    private let settings = AppSettings.shared

    /// The classification prompt template
    static let classificationPrompt = """
        You are a binary classifier. Given the last message from an AI coding agent, determine if the message is asking the user for input, confirmation, a decision, or approval before continuing.

        Answer ONLY "yes" or "no".

        Examples of "yes":
        - "Should I proceed with this approach?"
        - "Do you want me to implement this?"
        - "Which option would you prefer?"
        - "Is this plan okay?"
        - "Shall I continue?"

        Examples of "no":
        - "I've completed the refactoring. Here's what I changed..."
        - "The tests are all passing now."
        - "Here's the implementation plan..."
        - "I found the bug in line 42..."
        """

    /// Analyze the last assistant message to determine if user input is needed.
    /// If input is detected, dispatches the configured action.
    func analyze(lastMessage: String, agentId: UUID, agentName: String, mcpService: MCPService) async {
        guard !lastMessage.isEmpty else { return }

        let needsInput = await classify(message: lastMessage)
        guard needsInput else {
            logger.info("Input detection: no input needed for agent \(agentName)")
            return
        }

        logger.info("Input detection: input needed for agent \(agentName), action=\(settings.aiInputDetectionAction)")

        let action = InputDetectionAction(rawValue: settings.aiInputDetectionAction) ?? .mark
        await dispatchAction(action, agentId: agentId, agentName: agentName, lastMessage: lastMessage, mcpService: mcpService)
    }

    /// Classify whether a message is asking for user input.
    /// Returns true if the LLM determines input is needed.
    func classify(message: String) async -> Bool {
        do {
            let model = try buildLanguageModel()
            let result: DefaultGenerateTextResult<Never> = try await generateText(
                model: model,
                system: Self.classificationPrompt,
                prompt: message
            )
            return parseResponse(result.text)
        } catch {
            logger.error("Input detection LLM error: \(error.localizedDescription)")
            return false
        }
    }

    /// Parse the LLM response into a boolean.
    /// Returns true if the response contains "yes" (case-insensitive).
    static func parseResponse(_ response: String) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "yes" || trimmed.hasPrefix("yes")
    }

    // Instance wrapper for static method
    private func parseResponse(_ response: String) -> Bool {
        Self.parseResponse(response)
    }

    // MARK: - Language Model

    /// Build the appropriate language model based on user settings.
    private func buildLanguageModel() throws -> LanguageModel {
        let apiKey = settings.aiApiKey
        let modelId = settings.effectiveAiModel

        guard !apiKey.isEmpty else {
            throw InputDetectionError.missingApiKey
        }

        switch settings.aiProvider {
        case "openai":
            let provider = createOpenAIProvider(settings: OpenAIProviderSettings(apiKey: apiKey))
            let model = try provider.languageModel(modelId)
            return .v3(model)

        case "anthropic":
            let provider = createAnthropicProvider(settings: AnthropicProviderSettings(apiKey: apiKey))
            let model = try provider.languageModel(modelId: modelId)
            return .v3(model)

        case "google":
            let provider = createGoogleGenerativeAI(settings: GoogleProviderSettings(apiKey: apiKey))
            let model = try provider.languageModel(modelId: modelId)
            return .v3(model)

        default:
            throw InputDetectionError.unsupportedProvider(settings.aiProvider)
        }
    }

    // MARK: - Action Dispatch

    /// Dispatch the configured action when input is detected.
    private func dispatchAction(_ action: InputDetectionAction, agentId: UUID, agentName: String, lastMessage: String, mcpService: MCPService) async {
        switch action {
        case .mark:
            await mcpService.updateAgentStatus(for: agentId, status: .input, source: .hook)
            let agent = await mcpService.findAgentById(agentId)
            if let agent = agent {
                await MainActor.run {
                    NotificationService.shared.notifyAwaitingInput(agent: agent, message: "Agent is waiting for your input")
                }
            }

        case .ask:
            let agent = await mcpService.findAgentById(agentId)
            if let agent = agent {
                await MainActor.run {
                    NotificationService.shared.notifyAwaitingInput(agent: agent, message: "Agent is waiting for your input")
                    InputDetectionSheet.show(agent: agent, lastMessage: lastMessage, mcpService: mcpService)
                }
            }

        case .continue:
            await mcpService.injectText("yes, continue", for: agentId)
        }
    }
}

// MARK: - Errors

enum InputDetectionError: LocalizedError {
    case missingApiKey
    case unsupportedProvider(String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "AI API key is not configured. Set it in Settings > AI."
        case .unsupportedProvider(let provider):
            return "Unsupported AI provider: \(provider)"
        }
    }
}
