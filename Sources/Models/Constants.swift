import Foundation

// MARK: - Claude Models

enum ClaudeModels {
    static let opus = "claude-opus"
    static let sonnet = "claude-sonnet"
    static let haiku = "claude-haiku"
}

// MARK: - Environment Variables

enum EnvironmentVariables {
    static let anthropicAuthToken = "ANTHROPIC_AUTH_TOKEN"
    static let anthropicAPIKey = "ANTHROPIC_API_KEY"
    static let anthropicBaseURL = "ANTHROPIC_BASE_URL"
    static let anthropicModel = "ANTHROPIC_MODEL"
    static let anthropicDefaultOpusModel = "ANTHROPIC_DEFAULT_OPUS_MODEL"
    static let anthropicDefaultSonnetModel = "ANTHROPIC_DEFAULT_SONNET_MODEL"
    static let anthropicDefaultHaikuModel = "ANTHROPIC_DEFAULT_HAIKU_MODEL"
    static let openAIAPIKey = "OPENAI_API_KEY"
}

// MARK: - Localization Keys

enum LocalizationKeys {
    static let noKey = "ui.label.no_key"
    static let noBaseURL = "ui.label.no_base_url"
    static let profileDefaultName = "profile.default_name"
    static let profileCopyName = "profile.copy_name"
    static let apiProviderDefaultName = "api_provider.default_name"
    static let statusProfileSaved = "status.profile_saved"
    static let statusProfileSavedAndApplied = "status.profile_saved_and_applied"
    static let statusStateReset = "status.state_reset"
}

// MARK: - Provider Defaults

enum ProviderDefaults {
    enum ClaudeCode {
        static let displayName = "Claude Code"
        static let shortName = "Claude"
        static let symbolName = "brain.head.profile"
        static let logoName = "claude"
        static let baseURL = "https://api.anthropic.com"
        static let defaultModel = ClaudeModels.sonnet
    }

    enum Codex {
        static let displayName = "Codex"
        static let shortName = "Codex"
        static let symbolName = "terminal.fill"
        static let logoName = "codex"
        static let baseURL = "https://api.openai.com/v1"
        static let defaultModel = "gpt-5.5"
    }
}
