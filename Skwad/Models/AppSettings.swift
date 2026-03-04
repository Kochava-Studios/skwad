import Foundation
import SwiftUI
import AppKit

struct SavedAgent: Codable, Identifiable {
    let id: UUID
    var name: String
    var avatar: String
    var folder: String
    var agentType: String
    var createdBy: UUID?
    var isCompanion: Bool
    var shellCommand: String?
    var personaId: UUID?

    init(id: UUID, name: String, avatar: String, folder: String, agentType: String = "claude", createdBy: UUID? = nil, isCompanion: Bool = false, shellCommand: String? = nil, personaId: UUID? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.folder = folder
        self.agentType = agentType
        self.createdBy = createdBy
        self.isCompanion = isCompanion
        self.shellCommand = shellCommand
        self.personaId = personaId
    }

    // Custom decoding to handle migration from old format without newer fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatar = try container.decode(String.self, forKey: .avatar)
        folder = try container.decode(String.self, forKey: .folder)
        agentType = try container.decodeIfPresent(String.self, forKey: .agentType) ?? "claude"
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        isCompanion = try container.decodeIfPresent(Bool.self, forKey: .isCompanion) ?? false
        shellCommand = try container.decodeIfPresent(String.self, forKey: .shellCommand)
        personaId = try container.decodeIfPresent(UUID.self, forKey: .personaId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, folder, agentType, createdBy, isCompanion, shellCommand, personaId
    }
}

enum PersonaType: String, Codable {
    case system
    case user
}

enum PersonaState: String, Codable {
    case enabled
    case disabled
    case deleted
}

struct Persona: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var instructions: String
    var type: PersonaType
    var state: PersonaState

    init(id: UUID = UUID(), name: String, instructions: String, type: PersonaType = .user, state: PersonaState = .enabled) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.type = type
        self.state = state
    }

    // Migration: old personas without type/state default to user/enabled
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        instructions = try container.decode(String.self, forKey: .instructions)
        type = try container.decodeIfPresent(PersonaType.self, forKey: .type) ?? .user
        state = try container.decodeIfPresent(PersonaState.self, forKey: .state) ?? .enabled
    }
}

struct BenchAgent: Codable, Identifiable {
    let id: UUID
    var name: String
    var avatar: String
    var folder: String
    var agentType: String
    var shellCommand: String?
    var personaId: UUID?

    init(id: UUID = UUID(), name: String, avatar: String, folder: String, agentType: String = "claude", shellCommand: String? = nil, personaId: UUID? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.folder = folder
        self.agentType = agentType
        self.shellCommand = shellCommand
        self.personaId = personaId
    }

    init(from agent: Agent) {
        self.id = UUID()
        self.name = agent.name
        self.avatar = agent.avatar ?? "🤖"
        self.folder = agent.folder
        self.agentType = agent.agentType
        self.shellCommand = agent.shellCommand
        self.personaId = agent.personaId
    }
}

enum AppearanceMode: String, CaseIterable {
    case auto = "auto"
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var footerDescription: String {
        switch self {
        case .auto: return "Derives color scheme from terminal background color."
        case .system: return "Follows your macOS system appearance setting."
        case .light: return "Always use light appearance."
        case .dark: return "Always use dark appearance."
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Appearance
    @AppStorage("appearanceMode") var appearanceMode: String = "auto" {
        didSet { applyAppearance() }
    }

    /// Apply the current appearance mode to the app
    func applyAppearance() {
        // Skip in Xcode Previews - NSApp is not available
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        
        switch AppearanceMode(rawValue: appearanceMode) {
        case .auto:
            // Determine appearance from terminal background color
            let bgColor = effectiveBackgroundColor
            NSApp.appearance = NSAppearance(named: bgColor.isLight ? .aqua : .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system, .none:
            NSApp.appearance = nil
        }
    }

    // General
    @AppStorage("restoreLayoutOnLaunch") var restoreLayoutOnLaunch: Bool = true
    @AppStorage("keepInMenuBar") var keepInMenuBar: Bool = false
    @AppStorage("terminalEngine") var terminalEngine: String = "ghostty"  // "ghostty" or "swiftterm"
    @AppStorage("savedAgentsData") private var savedAgentsData: Data = Data()

    // Source folder for git worktree features
    @AppStorage("sourceBaseFolder") var sourceBaseFolder: String = "" {
        didSet {
            // Skip in Xcode Previews
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            let folder = sourceBaseFolder
            Task { @MainActor in
                RepoDiscoveryService.shared.updateBaseFolder(folder)
            }
        }
    }
    @AppStorage("sourceBaseFolderInitialized") private var sourceBaseFolderInitialized: Bool = false

    /// Initialize source base folder on first launch by checking common locations
    func initializeSourceBaseFolderIfNeeded() {
        guard !sourceBaseFolderInitialized else { return }
        sourceBaseFolderInitialized = true

        let candidates = [
            // Tier 1 - Most common
            "~/src",
            "~/dev",
            "~/code",
            "~/projects",
            "~/repos",
            // Tier 2 - Also common
            "~/source",
            "~/sources",
            "~/workspace",
            "~/workspaces",
            "~/git",
            "~/github",
            "~/Development",
            // Tier 3 - Less common but valid
            "~/work",
            "~/coding",
        ]
        for candidate in candidates {
            let expanded = NSString(string: candidate).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                sourceBaseFolder = candidate
                return
            }
        }
    }

    /// Expanded path for source base folder
    var expandedSourceBaseFolder: String {
        NSString(string: sourceBaseFolder).expandingTildeInPath
    }

    /// Check if source base folder is configured and valid
    var hasValidSourceBaseFolder: Bool {
        guard !sourceBaseFolder.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: expandedSourceBaseFolder, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // Recent repos tracking (last 5 used)
    @AppStorage("recentReposData") private var recentReposData: Data = Data()

    var recentRepos: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: recentReposData)) ?? []
        }
        set {
            recentReposData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func addRecentRepo(_ repoName: String) {
        var recent = recentRepos
        // Remove if already present
        recent.removeAll { $0 == repoName }
        // Add to front
        recent.insert(repoName, at: 0)
        // Keep only last 5
        if recent.count > 5 {
            recent = Array(recent.prefix(5))
        }
        recentRepos = recent
    }

    // Personas
    @AppStorage("personasData") private var personasData: Data = Data()

    /// All personas including deleted (for persistence)
    private var allPersonas: [Persona] {
        get {
            (try? JSONDecoder().decode([Persona].self, from: personasData)) ?? []
        }
        set {
            personasData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Active personas (excludes deleted), sorted by name
    var personas: [Persona] {
        get {
            allPersonas.filter { $0.state != .deleted }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        set {
            // Replace non-deleted entries, preserve deleted ones
            let deleted = allPersonas.filter { $0.state == .deleted }
            allPersonas = newValue + deleted
        }
    }

    @discardableResult
    func addPersona(name: String, instructions: String) -> Persona {
        let persona = Persona(name: name, instructions: instructions)
        var list = allPersonas
        list.append(persona)
        allPersonas = list
        return persona
    }

    func updatePersona(id: UUID, name: String, instructions: String) {
        var list = allPersonas
        if let index = list.firstIndex(where: { $0.id == id }) {
            list[index].name = name
            list[index].instructions = instructions
            allPersonas = list
        }
    }

    func removePersona(_ persona: Persona) {
        var list = allPersonas
        if persona.type == .system {
            // Soft delete: mark as deleted so it won't be re-installed
            if let index = list.firstIndex(where: { $0.id == persona.id }) {
                list[index].state = .deleted
                allPersonas = list
            }
        } else {
            // Hard delete user personas
            list.removeAll { $0.id == persona.id }
            allPersonas = list
        }
    }

    func persona(for id: UUID?) -> Persona? {
        guard let id else { return nil }
        return personas.first { $0.id == id }
    }

    // MARK: - Default Personas

    /// Default system personas shipped with Skwad.
    /// Uses fixed UUIDs so they can be matched across installs/updates.
    static let defaultPersonas: [Persona] = [
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!,
            name: "Kent Beck",
            instructions: "Write the simplest code that could possibly work, then refactor. Practice TDD religiously: red, green, refactor. Favor small steps and continuous feedback. Design emerges from refactoring, not upfront planning. Value communication, simplicity, and courage. When in doubt, write a test first.",
            type: .system
        ),
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000002")!,
            name: "Martin Fowler",
            instructions: "Prioritize code readability above all - code is read far more than it is written. Apply established design patterns where they clarify intent. Refactor continuously to improve internal structure without changing behavior. Name things precisely. Favor clear abstractions and well-defined interfaces. Avoid clever code; prefer obvious code.",
            type: .system
        ),
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000003")!,
            name: "Linus Torvalds",
            instructions: "Keep it simple and stupid. Performance matters - think about what the machine actually does. Reject unnecessary abstraction layers. Good taste in code means seeing the simple solution. Be direct and opinionated about bad design. Prefer pragmatic solutions over theoretically elegant ones. Data structures matter more than algorithms.",
            type: .system
        ),
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000004")!,
            name: "Uncle Bob",
            instructions: "Follow SOLID principles strictly. Functions should do one thing and do it well. Keep them small - extract until you can't extract anymore. Clean code reads like well-written prose. Names should reveal intent. Dependencies point inward. Discipline and professionalism are non-negotiable. Leave the code cleaner than you found it.",
            type: .system
        ),
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000005")!,
            name: "John Carmack",
            instructions: "Focus deeply on the technical problem at hand. Optimize ruthlessly where it matters - understand the hardware and the data. Prefer straightforward, linear code over complex abstractions. Static analysis and assertions catch bugs early. Write code that is easy to reason about locally. Pragmatism over dogma. Ship working software and iterate.",
            type: .system
        ),
        Persona(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000006")!,
            name: "Dave Farley",
            instructions: "Design for continuous delivery: every change should be deployable. Write tests at every level - unit, integration, acceptance. Work in small, incremental steps that keep the system always releasable. Decouple components to enable independent deployment. Automate everything that can be automated. Favor evolutionary design over big upfront architecture. Fast feedback loops are essential.",
            type: .system
        ),
    ]

    /// Install default personas on startup.
    /// Inserts missing defaults, skips already existing (by ID), respects deleted state.
    func installDefaultPersonas() {
        var list = allPersonas
        let existingIds = Set(list.map { $0.id })
        var changed = false
        for persona in Self.defaultPersonas {
            if !existingIds.contains(persona.id) {
                list.append(persona)
                changed = true
            }
        }
        if changed {
            allPersonas = list
        }
    }

    /// Restore default personas: reset system personas to their original state
    /// (name, instructions, state=enabled) and keep user personas untouched.
    func restoreDefaultPersonas() {
        var list = allPersonas
        let defaultsById = Dictionary(uniqueKeysWithValues: Self.defaultPersonas.map { ($0.id, $0) })

        // Reset existing system personas to defaults
        for i in list.indices {
            if let original = defaultsById[list[i].id] {
                list[i] = original
            }
        }

        // Add any missing defaults
        let existingIds = Set(list.map { $0.id })
        for persona in Self.defaultPersonas where !existingIds.contains(persona.id) {
            list.append(persona)
        }

        allPersonas = list
    }

    // Bench agents (user-curated agent templates)
    @AppStorage("benchAgentsData") private var benchAgentsData: Data = Data()

    var benchAgents: [BenchAgent] {
        get {
            let agents = (try? JSONDecoder().decode([BenchAgent].self, from: benchAgentsData)) ?? []
            return agents.sorted { ($0.name.lowercased(), $0.folder) < ($1.name.lowercased(), $1.folder) }
        }
        set {
            benchAgentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func addToBench(_ agent: Agent) {
        var bench = benchAgents
        // Replace if same folder already exists
        bench.removeAll { $0.folder == agent.folder }
        let entry = BenchAgent(from: agent)
        bench.append(entry)
        benchAgents = bench
    }

    func removeFromBench(_ benchAgent: BenchAgent) {
        var bench = benchAgents
        bench.removeAll { $0.id == benchAgent.id }
        benchAgents = bench
    }

    func updateBenchAgent(id: UUID, name: String) {
        var bench = benchAgents
        if let index = bench.firstIndex(where: { $0.id == id }) {
            bench[index].name = name
            benchAgents = bench
        }
    }

    // Voice Input
    @AppStorage("voiceEnabled") var voiceEnabled: Bool = false
    @AppStorage("voiceEngine") var voiceEngine: String = "apple"  // Only "apple" for now
    @AppStorage("voicePushToTalkKey") var voicePushToTalkKey: Int = 60  // Right Shift keyCode
    @AppStorage("voiceAutoInsert") var voiceAutoInsert: Bool = true

    // Autopilot
    @AppStorage("aiInputDetectionEnabled") var autopilotEnabled: Bool = false
    @AppStorage("aiProvider") var aiProvider: String = "openai"  // "openai", "anthropic", "google"
    @AppStorage("aiApiKey") var aiApiKey: String = ""
    @AppStorage("aiInputDetectionAction") var autopilotAction: String = "mark"  // "mark", "ask", "continue", "custom"
    @AppStorage("autopilotCustomPrompt") var autopilotCustomPrompt: String = ""

    /// Hardcoded model for each AI provider (cheapest/fastest options)
    static func aiModel(for provider: String) -> String {
        switch provider {
        case "openai": return "gpt-5-mini"
        case "anthropic": return "claude-haiku-4-5"
        case "google": return "gemini-flash-lite-latest"
        default: return ""
        }
    }

    // Markdown Preview
    @AppStorage("markdownFontSize") var markdownFontSize: Int = 14

    // Mermaid Diagrams
    @AppStorage("mermaidTheme") var mermaidTheme: String = "auto"
    @AppStorage("mermaidScale") var mermaidScale: Double = 1.0

    // Notifications
    @AppStorage("desktopNotificationsEnabled") var desktopNotificationsEnabled: Bool = true

    // MCP Server
    @AppStorage("mcpServerPort") var mcpServerPort: Int = 8766
    @AppStorage("mcpServerEnabled") var mcpServerEnabled: Bool = true

    var mcpServerURL: String {
        "http://127.0.0.1:\(mcpServerPort)/mcp"
    }

    var savedAgents: [SavedAgent] {
        get {
            (try? JSONDecoder().decode([SavedAgent].self, from: savedAgentsData)) ?? []
        }
        set {
            savedAgentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func saveAgents(_ agents: [Agent]) {
        savedAgents = agents.map { SavedAgent(id: $0.id, name: $0.name, avatar: $0.avatar ?? "🤖", folder: $0.folder, agentType: $0.agentType, createdBy: $0.createdBy, isCompanion: $0.isCompanion, shellCommand: $0.shellCommand, personaId: $0.personaId) }
    }

    func loadSavedAgents() -> [Agent] {
        savedAgents.map {
            var agent = Agent(id: $0.id, name: $0.name, avatar: $0.avatar, folder: $0.folder, agentType: $0.agentType, createdBy: $0.createdBy, isCompanion: $0.isCompanion, shellCommand: $0.shellCommand, personaId: $0.personaId)
            // Shell agents restored from persistence get deferred startup
            agent.isPendingStart = agent.isShell
            return agent
        }
    }

    // MARK: - Workspaces

    @AppStorage("savedWorkspacesData") private var savedWorkspacesData: Data = Data()
    @AppStorage("currentWorkspaceId") private var currentWorkspaceIdString: String = ""

    var savedWorkspaces: [Workspace] {
        get {
            (try? JSONDecoder().decode([Workspace].self, from: savedWorkspacesData)) ?? []
        }
        set {
            savedWorkspacesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var currentWorkspaceId: UUID? {
        get {
            guard !currentWorkspaceIdString.isEmpty else { return nil }
            return UUID(uuidString: currentWorkspaceIdString)
        }
        set {
            currentWorkspaceIdString = newValue?.uuidString ?? ""
        }
    }

    func saveWorkspaces(_ workspaces: [Workspace]) {
        savedWorkspaces = workspaces
    }

    func loadWorkspaces() -> [Workspace] {
        savedWorkspaces
    }

    // Coding - default open with app (Cmd+Shift+O)
    @AppStorage("defaultOpenWithApp") var defaultOpenWithApp: String = ""

    // Coding - per-agent options
    @AppStorage("agentOptions_claude") var agentOptions_claude: String = ""
    @AppStorage("agentOptions_codex") var agentOptions_codex: String = ""
    @AppStorage("agentOptions_opencode") var agentOptions_opencode: String = ""
    @AppStorage("agentOptions_gemini") var agentOptions_gemini: String = ""

    // Custom agents (command + options)
    @AppStorage("customAgent1Command") var customAgent1Command: String = ""
    @AppStorage("customAgent1Options") var customAgent1Options: String = ""
    @AppStorage("customAgent2Command") var customAgent2Command: String = ""
    @AppStorage("customAgent2Options") var customAgent2Options: String = ""

    // Legacy settings (kept for migration, will be removed later)
    @AppStorage("agentCommand") var agentCommand: String = "claude"
    @AppStorage("agentCommandOptions") var agentCommandOptions: String = ""

    /// Get the command for an agent type
    func getCommand(for agentType: String) -> String {
        switch agentType {
        case "custom1": return customAgent1Command
        case "custom2": return customAgent2Command
        default: return agentType  // Predefined agents use their ID as command
        }
    }

    /// Get the options for an agent type
    func getOptions(for agentType: String) -> String {
        switch agentType {
        case "claude": return agentOptions_claude
        case "codex": return agentOptions_codex
        case "opencode": return agentOptions_opencode
        case "gemini": return agentOptions_gemini
        case "custom1": return customAgent1Options
        case "custom2": return customAgent2Options
        default: return ""
        }
    }

    /// Set the options for an agent type
    func setOptions(_ options: String, for agentType: String) {
        switch agentType {
        case "claude": agentOptions_claude = options
        case "codex": agentOptions_codex = options
        case "opencode": agentOptions_opencode = options
        case "gemini": agentOptions_gemini = options
        case "custom1": customAgent1Options = options
        case "custom2": customAgent2Options = options
        default: break
        }
    }

    /// Get the full command (command + options) for an agent type
    /// NOTE: This only returns user-visible command + options
    /// For actual execution, use TerminalCommandBuilder.buildAgentCommand()
    func getFullCommand(for agentType: String) -> String {
        let cmd = getCommand(for: agentType)
        let opts = getOptions(for: agentType)
        if cmd.isEmpty {
            return ""
        }
        
        var fullCommand = cmd
        if !opts.isEmpty {
            fullCommand += " \(opts)"
        }
        
        return fullCommand
    }

    // Terminal
    @AppStorage("terminalFontName") var terminalFontName: String = "SF Mono"
    @AppStorage("terminalFontSize") var terminalFontSize: Double = 13

    @AppStorage("terminalBackgroundColor") private var backgroundColorHex: String = "#1E1E1E"
    @AppStorage("terminalForegroundColor") private var foregroundColorHex: String = "#FFFFFF"

    var terminalBackgroundColor: Color {
        get { Color(hex: backgroundColorHex) ?? .black }
        set { backgroundColorHex = newValue.toHex() ?? "#1E1E1E" }
    }

    var terminalForegroundColor: Color {
        get { Color(hex: foregroundColorHex) ?? .white }
        set { foregroundColorHex = newValue.toHex() ?? "#FFFFFF" }
    }

    var terminalFont: NSFont {
        NSFont(name: terminalFontName, size: terminalFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: terminalFontSize, weight: .regular)
    }

    var terminalNSBackgroundColor: NSColor {
        NSColor(terminalBackgroundColor)
    }

    var terminalNSForegroundColor: NSColor {
        NSColor(terminalForegroundColor)
    }

    var sidebarBackgroundColor: Color {
        // In previews, no terminal is running — use system colors so SwiftUI color scheme works
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil else {
            return Color(nsColor: .windowBackgroundColor)
        }
        switch AppearanceMode(rawValue: appearanceMode) {
        case .light, .dark, .system:
            return Color(nsColor: .windowBackgroundColor)
        case .auto, .none:
            return effectiveBackgroundColor.darkened(by: 0.05)
        }
    }

    /// Returns the effective background color based on terminal engine and appearance mode
    var effectiveBackgroundColor: Color {
        // In previews, no terminal is running — use system colors so SwiftUI color scheme works
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil else {
            return Color(nsColor: .controlBackgroundColor)
        }
        switch AppearanceMode(rawValue: appearanceMode) {
        case .light, .dark, .system:
            return Color(nsColor: .controlBackgroundColor)
        case .auto, .none:
            if terminalEngine == "ghostty" {
                return ghosttyBackgroundColor ?? defaultGhosttyBackground
            }
            return terminalBackgroundColor
        }
    }

    /// Default dark background for Ghostty mode
    private var defaultGhosttyBackground: Color {
        Color(hex: "#1C1C1C") ?? .black
    }

    /// Parse background color from user's Ghostty config
    var ghosttyBackgroundColor: Color? {
        let configPath = NSHomeDirectory() + "/.config/ghostty/config"
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }

        // Parse each line looking for "background = <color>"
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }  // Skip comments

            if trimmed.hasPrefix("background") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let colorValue = parts[1].trimmingCharacters(in: .whitespaces)
                    // Handle hex colors (with or without #)
                    if let color = Color(hex: colorValue) {
                        return color
                    }
                }
            }
        }
        return nil
    }

    /// Path to user's Ghostty config (for display)
    var ghosttyConfigPath: String {
        "~/.config/ghostty/config"
    }
}

// MARK: - Color Hex Conversion

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func darkened(by amount: Double) -> Color {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components else {
            return self
        }
        let r = max(0, components[0] - amount)
        let g = max(0, components[1] - amount)
        let b = max(0, components[2] - amount)
        return Color(red: r, green: g, blue: b)
    }

    func lightened(by amount: Double) -> Color {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components else {
            return self
        }
        let r = min(1, components[0] + amount)
        let g = min(1, components[1] + amount)
        let b = min(1, components[2] + amount)
        return Color(red: r, green: g, blue: b)
    }

    /// Determine if this color is "light" using relative luminance
    /// Uses the formula: 0.299*R + 0.587*G + 0.114*B > 0.5
    var isLight: Bool {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components,
              components.count >= 3 else {
            return false  // Default to dark if we can't determine
        }
        let luminance = 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
        return luminance > 0.5
    }

    /// Adjust color to add contrast - darkens light colors, lightens dark colors
    func withAddedContrast(by amount: Double) -> Color {
        if isLight {
            return darkened(by: amount)
        } else {
            return lightened(by: amount)
        }
    }
}
