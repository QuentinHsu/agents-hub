import Foundation

struct ConfigurationWriter: Sendable {
    func apply(_ profile: APIProfile) throws {
        switch profile.provider {
        case .claudeCode:
            try applyClaude(profile)
        case .codex:
            try applyCodex(profile)
        }
    }

    private func applyClaude(_ profile: APIProfile) throws {
        var settings = try loadJSONDictionary(from: AppPaths.claudeSettingsURL)

        settings["apiKeyHelper"] = nil
        settings["model"] = trimmedValue(profile.model)
        settings["env"] = mergedEnv(
            existing: settings["env"] as? [String: Any],
            values: [
                "ANTHROPIC_API_KEY": profile.apiKey,
                "ANTHROPIC_BASE_URL": profile.baseURL,
                "ANTHROPIC_MODEL": profile.model,
                "ANTHROPIC_DEFAULT_OPUS_MODEL": profile.claudeCodeModels.defaultOpusModel,
                "ANTHROPIC_DEFAULT_SONNET_MODEL": profile.claudeCodeModels.defaultSonnetModel,
                "ANTHROPIC_DEFAULT_HAIKU_MODEL": profile.claudeCodeModels.defaultHaikuModel
            ]
        )

        try writeJSONDictionary(settings, to: AppPaths.claudeSettingsURL)
    }

    private func applyCodex(_ profile: APIProfile) throws {
        try writeCodexConfig(profile)
        try writeCodexAuth(profile)
    }

    private func writeCodexConfig(_ profile: APIProfile) throws {
        let content = """
        model = "\(tomlEscape(profile.model))"
        model_provider = "agents-hub"

        [model_providers.agents-hub]
        name = "\(tomlEscape(profile.codexProviderDisplayName))"
        base_url = "\(tomlEscape(profile.baseURL))"
        wire_api = "responses"
        requires_openai_auth = true

        """

        try FileManager.default.createDirectory(
            at: AppPaths.codexConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: AppPaths.codexConfigURL, atomically: true, encoding: .utf8)
    }

    private func writeCodexAuth(_ profile: APIProfile) throws {
        let payload: [String: Any] = [
            "OPENAI_API_KEY": profile.apiKey
        ]

        try writeJSONDictionary(payload, to: AppPaths.codexAuthURL)
    }

    private func mergedEnv(existing: [String: Any]?, values: [String: String]) -> [String: String] {
        var env = existing?.compactMapValues { $0 as? String } ?? [:]

        for (key, value) in values {
            if let trimmed = trimmedValue(value) {
                env[key] = trimmed
            } else {
                env.removeValue(forKey: key)
            }
        }

        return env
    }

    private func trimmedValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadJSONDictionary(from url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func writeJSONDictionary(_ dictionary: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }

    func syncClaudeOnboarding(skip: Bool) throws {
        if skip {
            var config = try loadClaudeUserConfig()
            config["hasCompletedOnboarding"] = true
            try writeJSONDictionary(config, to: AppPaths.claudeUserConfigURL)
        } else {
            guard FileManager.default.fileExists(atPath: AppPaths.claudeUserConfigURL.path()) else {
                return
            }
            var config = try loadClaudeUserConfig()
            config["hasCompletedOnboarding"] = nil
            try writeJSONDictionary(config, to: AppPaths.claudeUserConfigURL)
        }
    }

    private func loadClaudeUserConfig() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: AppPaths.claudeUserConfigURL.path()) else {
            return [:]
        }

        let data = try Data(contentsOf: AppPaths.claudeUserConfigURL)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw NSError(
                domain: "AgentsHub.ConfigurationWriter",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "~/.claude.json root must be a JSON object."
                ]
            )
        }
        return dictionary
    }

    private func tomlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
