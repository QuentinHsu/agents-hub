import Foundation

struct ConfigurationWriter: Sendable {
    func apply(_ profile: APIProfile) throws {
        try apply(AgentConfiguration(profile))
    }

    private func apply(_ configuration: AgentConfiguration) throws {
        switch configuration.provider {
        case .claudeCode:
            try applyClaude(configuration)
        case .codex:
            try applyCodex(configuration)
        }
    }

    private func applyClaude(_ configuration: AgentConfiguration) throws {
        var settings: [String: Any]
        do {
            settings = try loadJSONDictionary(from: AppPaths.claudeSettingsURL)
        } catch {
            settings = [:]
        }

        settings["apiKeyHelper"] = nil
        settings["model"] = configuration.model.nilIfBlank
        settings["env"] = mergedEnv(
            existing: settings["env"] as? [String: Any],
            values: [
                EnvironmentVariables.anthropicAuthToken: configuration.apiKey,
                EnvironmentVariables.anthropicBaseURL: configuration.baseURL,
                EnvironmentVariables.anthropicModel: configuration.model,
                EnvironmentVariables.anthropicDefaultOpusModel: configuration.claudeCodeModels.defaultOpusModel,
                EnvironmentVariables.anthropicDefaultSonnetModel: configuration.claudeCodeModels.defaultSonnetModel,
                EnvironmentVariables.anthropicDefaultHaikuModel: configuration.claudeCodeModels.defaultHaikuModel
            ],
            removing: [EnvironmentVariables.anthropicAPIKey]
        )

        try writeJSONDictionary(settings, to: AppPaths.claudeSettingsURL)
    }

    private func applyCodex(_ configuration: AgentConfiguration) throws {
        try writeCodexConfig(configuration)
        try writeCodexAuth(configuration)
    }

    private func writeCodexConfig(_ configuration: AgentConfiguration) throws {
        let existing: String
        do {
            existing = try loadText(from: AppPaths.codexConfigURL)
        } catch {
            existing = ""
        }
        let content = mergedCodexConfig(existing: existing, configuration: configuration)

        try FileManager.default.createDirectory(
            at: AppPaths.codexConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: AppPaths.codexConfigURL, atomically: true, encoding: .utf8)
    }

    private func writeCodexAuth(_ configuration: AgentConfiguration) throws {
        var payload: [String: Any]
        do {
            payload = try loadJSONDictionary(from: AppPaths.codexAuthURL)
        } catch {
            payload = [:]
        }
        payload[EnvironmentVariables.openAIAPIKey] = configuration.apiKey.nilIfBlank

        try writeJSONDictionary(payload, to: AppPaths.codexAuthURL)
    }

    private func mergedEnv(
        existing: [String: Any]?,
        values: [String: String],
        removing keysToRemove: Set<String> = []
    ) -> [String: String] {
        var env = existing?.compactMapValues { $0 as? String } ?? [:]

        for key in keysToRemove {
            env.removeValue(forKey: key)
        }

        for (key, value) in values {
            if let trimmed = value.nilIfBlank {
                env[key] = trimmed
            } else {
                env.removeValue(forKey: key)
            }
        }

        return env
    }

    private func loadJSONDictionary(from url: URL) throws -> [String: Any] {
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

    private func loadText(from url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
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

    private func mergedCodexConfig(existing: String, configuration: AgentConfiguration) -> String {
        var lines = parseLines(from: existing)
        lines = removingCodexProviderBlock(from: lines)
        lines = settingTopLevelCodexValue("model", to: configuration.model, in: lines)
        lines = settingTopLevelCodexValue("model_provider", to: codexModelProviderID, in: lines)
        lines = trimTrailingEmptyLines(lines)

        if !lines.isEmpty {
            lines.append("")
        }
        lines.append(contentsOf: codexProviderBlock(for: configuration))

        return lines.joined(separator: "\n") + "\n"
    }

    private func parseLines(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") {
            lines.removeLast()
        }
        return lines
    }

    private func trimTrailingEmptyLines(_ lines: [String]) -> [String] {
        var result = lines
        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeLast()
        }
        return result
    }

    private func removingCodexProviderBlock(from lines: [String]) -> [String] {
        var result: [String] = []
        var isSkippingManagedBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isTableHeader(trimmed) {
                isSkippingManagedBlock = trimmed == "[model_providers.\(codexModelProviderID)]" ||
                    trimmed.hasPrefix("[model_providers.\(codexModelProviderID).")
            }

            if !isSkippingManagedBlock {
                result.append(line)
            }
        }

        return result
    }

    private func settingTopLevelCodexValue(_ key: String, to value: String, in lines: [String]) -> [String] {
        let assignment = tomlAssignment(key: key, value: value)
        var result: [String] = []
        var hasSetValue = false
        var isInTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if isTableHeader(trimmed) {
                if !hasSetValue {
                    result.append(assignment)
                    hasSetValue = true
                }
                isInTable = true
                result.append(line)
                continue
            }

            if !isInTable && topLevelTOMLKey(in: trimmed) == key {
                if !hasSetValue {
                    result.append(assignment)
                    hasSetValue = true
                }
                continue
            }

            result.append(line)
        }

        if !hasSetValue {
            result.insert(assignment, at: insertionIndexForTopLevelCodexValues(in: result))
        }

        return result
    }

    private func tomlAssignment(key: String, value: String) -> String {
        "\(key) = \"\(tomlEscape(value))\""
    }

    private func codexProviderBlock(for configuration: AgentConfiguration) -> [String] {
        var block = [
            "[model_providers.\(codexModelProviderID)]",
            "name = \"\(tomlEscape(configuration.codexProviderDisplayName))\""
        ]

        if let baseURL = configuration.baseURL.nilIfBlank {
            block.append("base_url = \"\(tomlEscape(baseURL))\"")
        }

        block.append(contentsOf: [
            "wire_api = \"responses\"",
            "requires_openai_auth = true"
        ])

        return block
    }

    private func topLevelTOMLKey(in trimmedLine: String) -> String? {
        guard !trimmedLine.isEmpty,
              !trimmedLine.hasPrefix("#"),
              let equalsIndex = trimmedLine.firstIndex(of: "=")
        else { return nil }

        return String(trimmedLine[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func insertionIndexForTopLevelCodexValues(in lines: [String]) -> Int {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isTableHeader(trimmed) {
                return index
            }
        }

        return lines.count
    }

    private func isTableHeader(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]")
    }

    private var codexModelProviderID: String {
        "agents-hub"
    }
}

private struct AgentConfiguration: Sendable {
    var provider: ProviderKind
    var baseURL: String
    var apiKey: String
    var model: String
    var codexProviderDisplayName: String
    var claudeCodeModels: ClaudeCodeModelConfiguration

    init(_ profile: APIProfile) {
        provider = profile.provider
        baseURL = profile.baseURL
        apiKey = profile.apiKey
        model = profile.model
        codexProviderDisplayName = profile.codexProviderDisplayName
        claudeCodeModels = profile.claudeCodeModels
    }
}
