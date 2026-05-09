import Foundation

enum AppPaths {
    static let configDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/agents-hub", isDirectory: true)

    static let stateURL = configDirectory.appendingPathComponent("profiles.json")

    static let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    static let claudeUserConfigURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude.json")

    static let codexConfigURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/config.toml")

    static let codexAuthURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/auth.json")

    static let claudeProjectsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)

    static let codexSessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true)

    static let codexDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)
}
