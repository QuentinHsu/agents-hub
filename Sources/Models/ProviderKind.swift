import Foundation
import SwiftUI

enum ProviderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case claudeCode
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.displayName
        case .codex: ProviderDefaults.Codex.displayName
        }
    }

    var shortName: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.shortName
        case .codex: ProviderDefaults.Codex.shortName
        }
    }

    var symbolName: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.symbolName
        case .codex: ProviderDefaults.Codex.symbolName
        }
    }

    var logoName: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.logoName
        case .codex: ProviderDefaults.Codex.logoName
        }
    }

    var accentColor: Color {
        switch self {
        case .claudeCode: Color(red: 0.83, green: 0.45, blue: 0.25)
        case .codex: Color(red: 0.12, green: 0.35, blue: 0.72)
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.baseURL
        case .codex: ProviderDefaults.Codex.baseURL
        }
    }

    var defaultModel: String {
        switch self {
        case .claudeCode: ProviderDefaults.ClaudeCode.defaultModel
        case .codex: ProviderDefaults.Codex.defaultModel
        }
    }
}
