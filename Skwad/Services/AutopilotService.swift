import Foundation
import Logging
import AIProxy

/// Classification result for an agent's last message.
enum InputClassification: String {
    /// Agent completed its work — no input needed.
    case completed
    /// Agent is asking for simple approval / yes-no confirmation.
    case binary
    /// Agent is asking an open-ended question requiring real user input.
    case open
}

/// Analyzes agent messages with an LLM to determine if user input is needed.
/// When an agent goes idle, its last message is classified and an action is
/// dispatched based on user settings.
actor AutopilotService {
    static let shared = AutopilotService()

    private let logger = Logger(label: "AutopilotService")
    private let settings = AppSettings.shared
    private weak var _agentManager: AgentManager?

    /// Call once at startup to wire up the agent manager reference.
    func setup(agentManager: AgentManager) {
        self._agentManager = agentManager
    }

    /// The classification prompt template
    static let classificationPrompt = """
        You are a classifier. Given the last message from an AI coding agent, classify it into exactly one of three categories.

        Answer ONLY with one word: "completed", "binary", or "open".

        - "completed": The agent has finished its work, is reporting results, or sharing a status update. No user input is needed.
        - "binary": The agent has a clear plan and is asking for simple approval or confirmation to proceed. A yes/no answer would suffice.
        - "open": The agent is asking an open-ended question, requesting the user to choose between options, or asking for information or feedback.

        When in doubt between "binary" and "open", answer "open".
        When in doubt between "completed" and anything else, answer "completed".

        Examples of "completed":
        - "I've completed the refactoring. Here's what I changed..."
        - "The tests are all passing now."
        - "I found the bug in line 42..."
        - "Done! The feature is implemented."

        Examples of "binary":
        - "Should I proceed with this approach?"
        - "Do you want me to implement this?"
        - "Shall I continue?"
        - "Is this plan okay?"
        - "Ready to proceed. Should I go ahead?"
        - "Should I reply to Ellie?"

        Examples of "open":
        - "Which option would you prefer?"
        - "Do you want approach A or approach B?"
        - "What should the API key be called?"
        - "Here's the implementation plan. Let me know if you'd like changes."
        - "Provide feedback on the plan before we go on."
        - "What database should we use?"
        """

    /// System framing prepended to the user's custom prompt.
    static let customPromptPrefix = """
        You are managing an AI coding agent. You will receive the agent's last message. \
        Your response will be sent directly to the agent as input.

        IMPORTANT: Reply with ONLY the exact text to send to the agent. \
        No explanations, no reasoning, no preamble, no quotes — just the raw instruction for the agent. \
        If no action is needed, reply with exactly "EMPTY" (nothing else).

        GOOD: yes, continue
        BAD: I think the agent should continue, so I'll reply with "yes, continue"

        GOOD: use approach A with the factory pattern
        BAD: Based on the agent's question, I recommend approach A. Here's what I'll tell it: "use approach A with the factory pattern"

        GOOD: EMPTY
        BAD: The agent has finished its work, no response needed. EMPTY

        Additional instructions from the user:

        """

    /// Snapshot of settings read on MainActor to avoid cross-actor @AppStorage issues.
    private struct SettingsSnapshot: Sendable {
        let provider: String
        let apiKey: String
        let action: String
        let customPrompt: String
    }

    /// Read settings on MainActor and return a snapshot.
    private func readSettings() async -> SettingsSnapshot {
        await MainActor.run {
            SettingsSnapshot(
                provider: settings.aiProvider,
                apiKey: settings.aiApiKey,
                action: settings.autopilotAction,
                customPrompt: settings.autopilotCustomPrompt
            )
        }
    }

    /// Analyze the last assistant message to determine if user input is needed.
    /// If input is detected, dispatches the configured action.
    func analyze(lastMessage: String, agentId: UUID, agentName: String) async {
        guard !lastMessage.isEmpty else { return }

        let snap = await readSettings()
        let action = AutopilotAction(rawValue: snap.action) ?? .mark

        // Custom action: skip classification, use user's prompt directly
        if action == .custom {
            await analyzeCustom(lastMessage: lastMessage, customPrompt: snap.customPrompt, provider: snap.provider, apiKey: snap.apiKey, agentId: agentId, agentName: agentName)
            return
        }

        let classification = await classify(message: lastMessage, provider: snap.provider, apiKey: snap.apiKey)

        guard classification != .completed else {
            logger.info("Autopilot: agent \(agentName) completed, no action needed")
            return
        }

        logger.info("Autopilot: agent \(agentName) classified=\(classification.rawValue), action=\(snap.action)")
        await dispatchAction(action, classification: classification, agentId: agentId, agentName: agentName, lastMessage: lastMessage)
    }

    /// Classify the agent's last message into completed, binary, or open.
    func classify(message: String, provider: String, apiKey: String) async -> InputClassification {
        do {
            logger.info("Autopilot: provider=\(provider) model=\(AppSettings.aiModel(for: provider))")
            let text = try await callLLM(message: message, provider: provider, apiKey: apiKey)
            let result = parseResponse(text)
            let suffix = String(message.suffix(64))
            logger.info("Autopilot: message=\"...\(suffix)\" raw=\"\(text.trimmingCharacters(in: .whitespacesAndNewlines))\" parsed=\(result.rawValue)")
            return result
        } catch {
            logger.error("Autopilot LLM error: \(error)")
            return .completed
        }
    }

    /// Parse the LLM response into a classification.
    /// Looks for "binary", "open", or "completed" (case-insensitive). Defaults to `.completed` on unknown input.
    static func parseResponse(_ response: String) -> InputClassification {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "binary" || trimmed.hasPrefix("binary") {
            return .binary
        } else if trimmed == "open" || trimmed.hasPrefix("open") {
            return .open
        } else {
            return .completed
        }
    }

    // Instance wrapper for static method
    private func parseResponse(_ response: String) -> InputClassification {
        Self.parseResponse(response)
    }

    // MARK: - Custom Autopilot

    /// Check if an LLM response signals "no action".
    /// Returns true for empty/whitespace strings or the keyword "EMPTY" (case-insensitive).
    static func isEmptyResponse(_ response: String) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.caseInsensitiveCompare("EMPTY") == .orderedSame
    }

    /// Analyze using the user's custom prompt. Skips tri-classification entirely.
    private func analyzeCustom(lastMessage: String, customPrompt: String, provider: String, apiKey: String, agentId: UUID, agentName: String) async {
        guard !customPrompt.isEmpty else {
            logger.info("Autopilot custom: no prompt configured, skipping")
            return
        }

        let fullPrompt = Self.customPromptPrefix + customPrompt

        do {
            let response = try await callLLMCustom(message: lastMessage, systemPrompt: fullPrompt, provider: provider, apiKey: apiKey)
            if Self.isEmptyResponse(response) {
                logger.info("Autopilot custom: agent \(agentName) → empty response, no action")
                return
            }
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Autopilot custom: agent \(agentName) → injecting \(trimmed.count) chars")
            let manager = _agentManager
            await MainActor.run {
                guard let manager = manager else { return }
                manager.updateStatus(for: agentId, status: .input, source: .hook)
                manager.injectText(trimmed, for: agentId)
            }
        } catch {
            logger.error("Autopilot custom LLM error: \(error), falling back to mark")
            await markInput(agentId: agentId)
        }
    }

    /// Call the LLM with a custom system prompt and higher token limit.
    private func callLLMCustom(message: String, systemPrompt: String, provider: String, apiKey: String) async throws -> String {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AutopilotError.missingApiKey
        }

        let modelId = AppSettings.aiModel(for: provider)

        switch provider {
        case "openai":
            return try await callOpenAICustom(message: message, systemPrompt: systemPrompt, apiKey: apiKey, model: modelId)
        case "anthropic":
            return try await callAnthropicCustom(message: message, systemPrompt: systemPrompt, apiKey: apiKey, model: modelId)
        case "google":
            return try await callGoogleCustom(message: message, systemPrompt: systemPrompt, apiKey: apiKey, model: modelId)
        default:
            throw AutopilotError.unsupportedProvider(provider)
        }
    }

    private func callOpenAICustom(message: String, systemPrompt: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: apiKey)
        let body = OpenAIChatCompletionRequestBody(
            model: model,
            messages: [
                .system(content: .text(systemPrompt)),
                .user(content: .text(message)),
            ]
        )
        let response = try await service.chatCompletionRequest(body: body, secondsToWait: 30)
        return response.choices.first?.message.content ?? ""
    }

    private func callAnthropicCustom(message: String, systemPrompt: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.anthropicDirectService(unprotectedAPIKey: apiKey)
        let body = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(content: .text(message), role: .user),
            ],
            model: model,
            system: .text(systemPrompt)
        )
        let response = try await service.messageRequest(body: body, secondsToWait: 30)
        if case .textBlock(let block) = response.content.first {
            return block.text
        }
        return ""
    }

    private func callGoogleCustom(message: String, systemPrompt: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.geminiDirectService(unprotectedAPIKey: apiKey)
        let body = GeminiGenerateContentRequestBody(
            contents: [.init(parts: [.text(message)])],
            systemInstruction: .init(parts: [.text(systemPrompt)])
        )
        let response = try await service.generateContentRequest(body: body, model: model, secondsToWait: 30)
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .text(let text) = part {
                return text
            }
        }
        return ""
    }

    // MARK: - LLM Calls

    /// Call the appropriate LLM provider and return the response text.
    private func callLLM(message: String, provider: String, apiKey: String) async throws -> String {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AutopilotError.missingApiKey
        }

        let modelId = AppSettings.aiModel(for: provider)

        switch provider {
        case "openai":
            return try await callOpenAI(message: message, apiKey: apiKey, model: modelId)
        case "anthropic":
            return try await callAnthropic(message: message, apiKey: apiKey, model: modelId)
        case "google":
            return try await callGoogle(message: message, apiKey: apiKey, model: modelId)
        default:
            throw AutopilotError.unsupportedProvider(provider)
        }
    }

    private func callOpenAI(message: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: apiKey)
        let body = OpenAIChatCompletionRequestBody(
            model: model,
            messages: [
                .system(content: .text(Self.classificationPrompt)),
                .user(content: .text(message)),
            ]
        )
        let response = try await service.chatCompletionRequest(body: body, secondsToWait: 30)
        return response.choices.first?.message.content ?? ""
    }

    private func callAnthropic(message: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.anthropicDirectService(unprotectedAPIKey: apiKey)
        let body = AnthropicMessageRequestBody(
            maxTokens: 16,
            messages: [
                AnthropicMessageParam(content: .text(message), role: .user),
            ],
            model: model,
            system: .text(Self.classificationPrompt)
        )
        let response = try await service.messageRequest(body: body, secondsToWait: 30)
        if case .textBlock(let block) = response.content.first {
            return block.text
        }
        return ""
    }

    private func callGoogle(message: String, apiKey: String, model: String) async throws -> String {
        let service = AIProxy.geminiDirectService(unprotectedAPIKey: apiKey)
        let body = GeminiGenerateContentRequestBody(
            contents: [.init(parts: [.text(message)])],
            systemInstruction: .init(parts: [.text(Self.classificationPrompt)])
        )
        let response = try await service.generateContentRequest(body: body, model: model, secondsToWait: 30)
        for part in response.candidates?.first?.content?.parts ?? [] {
            if case .text(let text) = part {
                return text
            }
        }
        return ""
    }

    // MARK: - Action Dispatch

    /// Mark agent as needing input and send a notification.
    private func markInput(agentId: UUID) async {
        let manager = _agentManager
        await MainActor.run {
            guard let manager = manager else { return }
            manager.updateStatus(for: agentId, status: .input, source: .hook)
            if let agent = manager.agents.first(where: { $0.id == agentId }) {
                NotificationService.shared.notifyAwaitingInput(agent: agent, message: "Agent is waiting for your input")
            }
        }
    }

    /// Dispatch the configured action when input is detected.
    private func dispatchAction(_ action: AutopilotAction, classification: InputClassification, agentId: UUID, agentName: String, lastMessage: String) async {
        let manager = _agentManager

        switch action {
        case .mark:
            await markInput(agentId: agentId)

        case .ask:
            await MainActor.run {
                guard let manager = manager else { return }
                manager.updateStatus(for: agentId, status: .input, source: .hook)
                if let agent = manager.agents.first(where: { $0.id == agentId }) {
                    NotificationService.shared.notifyAwaitingInput(agent: agent, message: "Agent is waiting for your input")
                    AutopilotDecisionSheet.show(agent: agent, lastMessage: lastMessage, classification: classification, agentManager: manager)
                }
            }

        case .continue:
            if classification == .binary {
                await MainActor.run {
                    guard let manager = manager else { return }
                    manager.updateStatus(for: agentId, status: .input, source: .hook)
                    manager.injectText("yes, continue", for: agentId)
                }
            } else {
                // Open questions can't be auto-answered — fall back to mark
                await markInput(agentId: agentId)
            }

        case .custom:
            // Custom is handled in analyze() before dispatchAction is called
            break
        }
    }
}

// MARK: - Errors

enum AutopilotError: LocalizedError {
    case missingApiKey
    case unsupportedProvider(String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "AI API key is not configured. Set it in Settings > Autopilot."
        case .unsupportedProvider(let provider):
            return "Unsupported AI provider: \(provider)"
        }
    }
}
