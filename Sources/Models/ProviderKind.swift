import Foundation
import SwiftUI

enum ProviderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case claudeCode
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }

    var shortName: String {
        switch self {
        case .claudeCode: "Claude"
        case .codex: "Codex"
        }
    }

    var symbolName: String {
        switch self {
        case .claudeCode: "brain.head.profile"
        case .codex: "terminal.fill"
        }
    }

    var logoName: String {
        switch self {
        case .claudeCode: "claude"
        case .codex: "codex"
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
        case .claudeCode: "https://api.anthropic.com"
        case .codex: "https://api.openai.com/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .claudeCode: "sonnet"
        case .codex: "gpt-5.1-codex"
        }
    }
}
