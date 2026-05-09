import AppKit
import Foundation

@MainActor
@Observable
final class SessionManager {
    var sessions: [CLISession] = []
    var isLoading = false

    private let provider: ProviderKind

    init(provider: ProviderKind) {
        self.provider = provider
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        sessions = await SessionScanner.scanSessions(for: provider)
    }

    func deleteSession(_ session: CLISession) {
        let fm = FileManager.default

        switch session.provider {
        case .claudeCode:
            // Remove sidecar directory (Claude Code creates a dir with same stem as .jsonl)
            if session.filePath.pathExtension == "jsonl" {
                let sidecar = session.filePath.deletingPathExtension()
                if fm.fileExists(atPath: sidecar.path()) {
                    try? fm.removeItem(at: sidecar)
                }
            }
            try? fm.removeItem(at: session.filePath)

        case .codex:
            // Only delete the rollout file, not session_index.jsonl (shared file)
            let isRolloutFile = session.filePath.lastPathComponent.hasPrefix("rollout-")
            if isRolloutFile {
                try? fm.removeItem(at: session.filePath)
            }
        }

        sessions.removeAll { $0.id == session.id }
    }

    func copyResumeCommand(for session: CLISession) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(resumeCommandText(for: session), forType: .string)
    }

    func resumeCommandText(for session: CLISession) -> String {
        let command = resumeCommand(for: session)
        guard let workingDirectory = workingDirectory(for: session) else {
            return command
        }
        return "cd \(shellEscape(workingDirectory.path())) && \(command)"
    }

    // MARK: - Private

    private func resumeCommand(for session: CLISession) -> String {
        switch session.provider {
        case .claudeCode:
            "claude --resume \(session.id)"
        case .codex:
            "codex resume \(session.id)"
        }
    }

    private func workingDirectory(for session: CLISession) -> URL? {
        if session.provider == .claudeCode, session.projectPath == session.id {
            return nil
        }
        return existingDirectory(from: session.projectPath)
    }

    private func existingDirectory(from path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let expanded = path.hasPrefix("~")
            ? path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path())
            : path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return URL(filePath: expanded)
    }

    private func shellEscape(_ path: String) -> String {
        let special = CharacterSet(charactersIn: " \\\"'`$!#&()[]{}|;<>?*~")
        if path.unicodeScalars.contains(where: { special.contains($0) }) {
            let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return path
    }
}
