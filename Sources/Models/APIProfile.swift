import Foundation

struct APIProfile: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var provider: ProviderKind
    var name: String
    var baseURL: String
    var apiKey: String
    var model: String
    var codexProviderNameMode: CodexProviderNameMode
    var claudeCodeModels: ClaudeCodeModelConfiguration
    var isActive: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        provider: ProviderKind,
        name: String,
        baseURL: String? = nil,
        apiKey: String = "",
        model: String? = nil,
        codexProviderNameMode: CodexProviderNameMode = .agentsHub,
        claudeCodeModels: ClaudeCodeModelConfiguration? = nil,
        isActive: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.provider = provider
        self.name = name
        self.baseURL = baseURL ?? provider.defaultBaseURL
        self.apiKey = apiKey
        self.model = model ?? provider.defaultModel
        self.codexProviderNameMode = codexProviderNameMode
        self.claudeCodeModels = claudeCodeModels ?? ClaudeCodeModelConfiguration(provider: provider)
        self.isActive = isActive
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case name
        case baseURL
        case apiKey
        case model
        case codexProviderNameMode
        case claudeCodeModels
        case isActive
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(ProviderKind.self, forKey: .provider)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? provider.displayName
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? provider.defaultBaseURL
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? provider.defaultModel
        codexProviderNameMode = try container.decodeIfPresent(
            CodexProviderNameMode.self,
            forKey: .codexProviderNameMode
        ) ?? .agentsHub
        claudeCodeModels = try container.decodeIfPresent(
            ClaudeCodeModelConfiguration.self,
            forKey: .claudeCodeModels
        ) ?? ClaudeCodeModelConfiguration(provider: provider)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

    var redactedKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return LocalizationManager.localize("ui.label.no_key") }
        guard trimmed.count > 8 else { return String(repeating: "•", count: trimmed.count) }

        return "\(trimmed.prefix(4))••••\(trimmed.suffix(4))"
    }

    var isReady: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    var codexProviderDisplayName: String {
        switch codexProviderNameMode {
        case .agentsHub:
            "Agents Hub"
        case .profileName:
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? provider.displayName : name
        }
    }
}

enum CodexProviderNameMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case agentsHub
    case profileName

    var id: String { rawValue }
}

enum ClaudeCodeOnboardingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case leaveUnchanged
    case markCompleted
    case clearCompleted

    var id: String { rawValue }
}

struct ClaudeCodeModelConfiguration: Hashable, Codable, Sendable {
    var defaultOpusModel: String
    var defaultSonnetModel: String
    var defaultHaikuModel: String

    init(
        defaultOpusModel: String = "opus",
        defaultSonnetModel: String = "sonnet",
        defaultHaikuModel: String = "haiku"
    ) {
        self.defaultOpusModel = defaultOpusModel
        self.defaultSonnetModel = defaultSonnetModel
        self.defaultHaikuModel = defaultHaikuModel
    }

    init(provider: ProviderKind) {
        switch provider {
        case .claudeCode:
            self.init()
        case .codex:
            self.init(defaultOpusModel: "", defaultSonnetModel: "", defaultHaikuModel: "")
        }
    }
}

struct AgentsHubState: Codable, Sendable {
    var profiles: [APIProfile]
    var skipClaudeCodeOnboarding: Bool

    init(
        profiles: [APIProfile],
        skipClaudeCodeOnboarding: Bool = false
    ) {
        self.profiles = profiles
        self.skipClaudeCodeOnboarding = skipClaudeCodeOnboarding
    }

    enum CodingKeys: String, CodingKey {
        case profiles
        case skipClaudeCodeOnboarding
        case claudeCodeOnboardingMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([APIProfile].self, forKey: .profiles) ?? []
        if let value = try container.decodeIfPresent(Bool.self, forKey: .skipClaudeCodeOnboarding) {
            skipClaudeCodeOnboarding = value
        } else if let legacyMode = try container.decodeIfPresent(
            ClaudeCodeOnboardingMode.self,
            forKey: .claudeCodeOnboardingMode
        ) {
            skipClaudeCodeOnboarding = legacyMode == .markCompleted
        } else {
            skipClaudeCodeOnboarding = false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(skipClaudeCodeOnboarding, forKey: .skipClaudeCodeOnboarding)
    }

    static let empty = AgentsHubState(profiles: [
        APIProfile(provider: .claudeCode, name: "Claude Code"),
        APIProfile(provider: .codex, name: "Codex")
    ])
}
