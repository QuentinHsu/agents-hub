import Foundation

struct APIProfile: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var provider: ProviderKind
    var apiProviderID: UUID?
    var apiProviderKeyID: UUID?
    var name: String
    var baseURL: String
    var providerWebsiteURL: String
    var apiKey: String
    var model: String
    var codexProviderNameMode: CodexProviderNameMode
    var claudeCodeModels: ClaudeCodeModelConfiguration
    var isActive: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        provider: ProviderKind,
        apiProviderID: UUID? = nil,
        apiProviderKeyID: UUID? = nil,
        name: String,
        baseURL: String? = nil,
        providerWebsiteURL: String = "",
        apiKey: String = "",
        model: String? = nil,
        codexProviderNameMode: CodexProviderNameMode = .agentsHub,
        claudeCodeModels: ClaudeCodeModelConfiguration? = nil,
        isActive: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.provider = provider
        self.apiProviderID = apiProviderID
        self.apiProviderKeyID = apiProviderKeyID
        self.name = name
        self.baseURL = baseURL ?? provider.defaultBaseURL
        self.providerWebsiteURL = providerWebsiteURL
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
        case apiProviderID
        case apiProviderKeyID
        case name
        case baseURL
        case providerWebsiteURL
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

        // Migration: if apiProviderID is missing, keep it nil so ProfileManager can assign defaults
        apiProviderID = try container.decodeIfPresent(UUID.self, forKey: .apiProviderID)
        apiProviderKeyID = try container.decodeIfPresent(UUID.self, forKey: .apiProviderKeyID)

        name = try container.decodeIfPresent(String.self, forKey: .name) ?? provider.displayName
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? provider.defaultBaseURL
        providerWebsiteURL = try container.decodeIfPresent(String.self, forKey: .providerWebsiteURL) ?? ""
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
        apiKey.redacted(emptyPlaceholder: LocalizationManager.localize(LocalizationKeys.noKey))
    }

    var isReady: Bool {
        baseURL.nilIfBlank != nil && apiKey.nilIfBlank != nil
    }

    var displayModel: String {
        model.nilIfBlank ?? provider.defaultModel
    }

    var codexProviderDisplayName: String {
        switch codexProviderNameMode {
        case .agentsHub:
            "Agents Hub"
        case .profileName:
            name.nilIfBlank ?? provider.displayName
        }
    }

    func resolved(with apiProvider: APIProvider?, key: APIProviderKey?) -> APIProfile {
        guard let apiProvider else { return self }

        var profile = self

        if let providerBaseURL = apiProvider.baseURL.nilIfBlank {
            profile.baseURL = mergedBaseURL(providerBase: providerBaseURL, profileURL: self.baseURL)
        }

        profile.providerWebsiteURL = apiProvider.providerWebsiteURL

        if let key, let keyValue = key.apiKey.nilIfBlank {
            profile.apiKey = keyValue
        }

        return profile
    }

    private func mergedBaseURL(providerBase: String, profileURL: String) -> String {
        guard let profileURL = URL(string: profileURL),
              let providerURL = URL(string: providerBase)
        else {
            return providerBase
        }

        let profilePath = profileURL.path
        let providerPath = providerURL.path

        if !profilePath.isEmpty && profilePath != "/" && (providerPath.isEmpty || providerPath == "/") {
            return providerBase.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + profilePath
        }

        return providerBase
    }
}

enum CodexProviderNameMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case agentsHub
    case profileName

    var id: String { rawValue }
}

struct ClaudeCodeModelConfiguration: Hashable, Codable, Sendable {
    var defaultOpusModel: String
    var defaultSonnetModel: String
    var defaultHaikuModel: String

    init(
        defaultOpusModel: String = ClaudeModels.opus,
        defaultSonnetModel: String = ClaudeModels.sonnet,
        defaultHaikuModel: String = ClaudeModels.haiku
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
    var apiProviders: [APIProvider]
    var skipClaudeCodeOnboarding: Bool

    init(
        profiles: [APIProfile],
        apiProviders: [APIProvider],
        skipClaudeCodeOnboarding: Bool = false
    ) {
        self.profiles = profiles
        self.apiProviders = apiProviders
        self.skipClaudeCodeOnboarding = skipClaudeCodeOnboarding
    }

    enum CodingKeys: String, CodingKey {
        case profiles
        case apiProviders
        case skipClaudeCodeOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([APIProfile].self, forKey: .profiles) ?? []
        apiProviders = try container.decodeIfPresent([APIProvider].self, forKey: .apiProviders) ?? []
        skipClaudeCodeOnboarding = try container.decodeIfPresent(Bool.self, forKey: .skipClaudeCodeOnboarding) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(apiProviders, forKey: .apiProviders)
        try container.encode(skipClaudeCodeOnboarding, forKey: .skipClaudeCodeOnboarding)
    }

    static let empty: AgentsHubState = {
        let defaultProvider = APIProvider(name: "Default", baseURL: "https://api.openai.com/v1")
        let defaultKeyID = defaultProvider.keys.first?.id

        return AgentsHubState(
            profiles: [
                APIProfile(
                    provider: .claudeCode,
                    apiProviderID: defaultProvider.id,
                    apiProviderKeyID: defaultKeyID,
                    name: "Claude Code"
                ),
                APIProfile(
                    provider: .codex,
                    apiProviderID: defaultProvider.id,
                    apiProviderKeyID: defaultKeyID,
                    name: "Codex"
                )
            ],
            apiProviders: [defaultProvider]
        )
    }()

}
