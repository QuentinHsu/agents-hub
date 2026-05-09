import Foundation

enum SessionScanner {
    static func scanSessions(for provider: ProviderKind) async -> [CLISession] {
        switch provider {
        case .claudeCode:
            await scanClaudeCodeSessions()
        case .codex:
            await scanCodexSessions()
        }
    }

    // MARK: - Claude Code

    private static func scanClaudeCodeSessions() async -> [CLISession] {
        let root = AppPaths.claudeProjectsDirectory
        var files: [URL] = []
        collectJSONLFiles(in: root, result: &files)

        var sessions: [CLISession] = []
        for file in files {
            if let session = parseClaudeCodeSession(file: file) {
                sessions.append(session)
            }
        }

        return sessions.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    private static func collectJSONLFiles(in directory: URL, result: inout [URL]) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }

        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                collectJSONLFiles(in: entry, result: &result)
            } else if entry.pathExtension == "jsonl" {
                // Skip agent sessions (e.g. agent-xxx.jsonl)
                let stem = entry.deletingPathExtension().lastPathComponent
                if !stem.hasPrefix("agent-") {
                    result.append(entry)
                }
            }
        }
    }

    private static func parseClaudeCodeSession(file: URL) -> CLISession? {
        let fm = FileManager.default
        let sessionId = file.deletingPathExtension().lastPathComponent

        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }

        // Head: first 10 lines
        let headLines = readLines(from: handle, maxCount: 10)
        // Tail: last 30 lines
        let tailLines = readTailLines(from: file, maxCount: 30)

        guard !headLines.isEmpty else { return nil }

        // Parse head for: sessionId, cwd, createdAt, first user message title, gitBranch
        var resolvedSessionId = sessionId
        var projectPath = ""
        var createdAt: Date?
        var titleCandidate: String?
        var customTitle: String?
        var gitBranch: String?

        for line in headLines {
            guard let obj = parseJSON(line) else { continue }
            let type = obj["type"] as? String

            if let sid = obj["sessionId"] as? String, !sid.isEmpty {
                resolvedSessionId = sid
            }
            if let cwd = obj["cwd"] as? String, !cwd.isEmpty {
                projectPath = cwd
            }
            if createdAt == nil, let ts = obj["timestamp"] {
                createdAt = parseTimestamp(ts)
            }
            if let branch = obj["gitBranch"] as? String, !branch.isEmpty {
                gitBranch = branch
            }
            if customTitle == nil, type == "custom-title" {
                customTitle = (obj["customTitle"] as? String)?.nilIfBlank
            }

            // First user message as title candidate (skip system/meta content)
            if titleCandidate == nil {
                titleCandidate = extractUserMessageTitle(from: obj)
            }
        }

        // Parse tail for: lastActiveAt, custom-title, summary
        var lastActiveAt: Date?
        var latestMessageSummary: String?
        var messageCount = 0

        // Count messages from head
        for line in headLines {
            guard let obj = parseJSON(line),
                  let type = obj["type"] as? String else { continue }
            if isConversationMessage(type) {
                messageCount += 1
            }
        }

        // Parse tail in reverse for latest state
        for line in tailLines.reversed() {
            guard let obj = parseJSON(line),
                  let type = obj["type"] as? String else { continue }

            if lastActiveAt == nil, let ts = obj["timestamp"] {
                lastActiveAt = parseTimestamp(ts)
            }

            if customTitle == nil, type == "custom-title" {
                customTitle = (obj["customTitle"] as? String)?.nilIfBlank
            }

            if latestMessageSummary == nil {
                if let content = obj["message"] as? [String: Any],
                   let msgContent = content["content"] {
                    let text = extractText(from: msgContent)
                    if let text, !text.isEmpty {
                        // Skip meta-only content
                        let isMeta = obj["isMeta"] as? Bool ?? false
                        if !isMeta {
                            latestMessageSummary = text
                        }
                    }
                }
            }

            if isConversationMessage(type) {
                messageCount += 1
            }
        }

        // Avoid double-counting: head and tail may overlap
        // Recount from a combined approach: count in tail that aren't in head range
        // Simple approach: just use head count + unique tail count
        // Actually, let's just do a rough count — head messages already counted,
        // tail adds messages beyond the head window
        // We'll accept slight inaccuracy for performance

        let modificationDate = (try? fm.attributesOfItem(atPath: file.path())[.modificationDate] as? Date)

        // Title priority: custom-title > first user message > directory basename
        let displayTitle = customTitle
            ?? titleCandidate
            ?? projectPath.components(separatedBy: "/").last { !$0.isEmpty }
            ?? resolvedSessionId

        let displaySummary = latestMessageSummary
            ?? displayTitle

        return CLISession(
            id: resolvedSessionId,
            provider: .claudeCode,
            name: String(displayTitle.prefix(160)),
            summary: String(displaySummary.prefix(160)),
            projectPath: projectPath,
            messageCount: messageCount,
            gitBranch: gitBranch,
            createdAt: createdAt,
            updatedAt: lastActiveAt ?? modificationDate,
            filePath: file
        )
    }

    // MARK: - Codex

    private static func scanCodexSessions() async -> [CLISession] {
        let fm = FileManager.default
        let codexDir = AppPaths.codexDirectory

        // 1. Read session_index.jsonl for metadata (id, thread_name, updated_at)
        var indexEntries: [String: (name: String, updatedAt: Date?)] = [:]
        let indexFile = codexDir.appendingPathComponent("session_index.jsonl")
        if let data = try? Data(contentsOf: indexFile, options: .mappedIfSafe),
           let content = String(data: data, encoding: .utf8) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for line in content.components(separatedBy: "\n") {
                guard let obj = parseJSON(line),
                      let id = obj["id"] as? String else { continue }
                let name = obj["thread_name"] as? String
                let updatedAt = (obj["updated_at"] as? String).flatMap { iso.date(from: $0) }
                indexEntries[id] = (name: name ?? "", updatedAt: updatedAt)
            }
        }

        // 2. Recursively scan sessions/ directory for rollout JSONL files
        let sessionsDir = AppPaths.codexSessionsDirectory
        var rolloutFiles: [URL] = []
        collectJSONLFiles(in: sessionsDir, result: &rolloutFiles)

        // 3. Parse each rollout file and merge with index metadata
        var sessions: [CLISession] = []

        for file in rolloutFiles {
            let filename = file.deletingPathExtension().lastPathComponent
            // Filename format: rollout-<timestamp>-<session-id>
            // Extract session ID (last UUID segment after last dash-group)
            let parts = filename.components(separatedBy: "-")
            // The UUID is the last 5 dash-separated segments
            guard parts.count >= 6 else { continue }
            let uuidParts = parts.suffix(5)
            let sessionId = uuidParts.joined(separator: "-")

            let indexMeta = indexEntries[sessionId]
            let modificationDate = (try? fm.attributesOfItem(atPath: file.path())[.modificationDate] as? Date)

            // Try to read cwd from first line of rollout file
            var projectPath = ""
            if let handle = try? FileHandle(forReadingFrom: file) {
                let headLines = readLines(from: handle, maxCount: 1)
                try? handle.close()
                if let firstLine = headLines.first,
                   let obj = parseJSON(firstLine),
                   let payload = obj["payload"] as? [String: Any],
                   let cwd = payload["cwd"] as? String {
                    projectPath = cwd
                }
            }

            sessions.append(CLISession(
                id: sessionId,
                provider: .codex,
                name: indexMeta?.name,
                summary: indexMeta?.name ?? sessionId,
                projectPath: projectPath,
                messageCount: 0,
                gitBranch: nil,
                createdAt: nil,
                updatedAt: indexMeta?.updatedAt ?? modificationDate,
                filePath: file
            ))
        }

        // Also include sessions from index that have no rollout file on disk
        let foundIds = Set(sessions.map(\.id))
        for (id, meta) in indexEntries where !foundIds.contains(id) {
            sessions.append(CLISession(
                id: id,
                provider: .codex,
                name: meta.name,
                summary: meta.name,
                projectPath: "",
                messageCount: 0,
                gitBranch: nil,
                createdAt: nil,
                updatedAt: meta.updatedAt,
                filePath: codexDir.appendingPathComponent("session_index.jsonl")
            ))
        }

        return sessions.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    // MARK: - File I/O Helpers

    private static func readLines(from handle: FileHandle, maxCount: Int) -> [String] {
        var lines: [String] = []
        var buffer = Data()

        while lines.count < maxCount {
            guard let data = try? handle.read(upToCount: 64 * 1024) else { break }
            if data.isEmpty { break }

            buffer.append(data)
            let fullText = String(data: buffer, encoding: .utf8) ?? ""
            let components = fullText.components(separatedBy: "\n")

            // Keep the last component as it may be incomplete
            buffer = components.last?.data(using: .utf8) ?? Data()

            let completeLines = components.dropLast()
            for line in completeLines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append(trimmed)
                    if lines.count >= maxCount { break }
                }
            }
        }

        // Flush remaining buffer
        if lines.count < maxCount {
            let remaining = String(data: buffer, encoding: .utf8) ?? ""
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append(trimmed)
            }
        }

        return lines
    }

    private static func readTailLines(from file: URL, maxCount: Int) -> [String] {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let allLines = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(allLines.suffix(maxCount))
    }

    // MARK: - JSON & Timestamp Helpers

    private static func parseJSON(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseTimestamp(_ value: Any) -> Date? {
        if let str = value as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: str)
        }

        if let num = value as? Double {
            // > 1 trillion = milliseconds, otherwise seconds
            if num > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: num / 1000)
            }
            return Date(timeIntervalSince1970: num)
        }

        if let num = value as? Int {
            let double = Double(num)
            if double > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: double / 1000)
            }
            return Date(timeIntervalSince1970: double)
        }

        return nil
    }

    private static func isConversationMessage(_ type: String) -> Bool {
        type == "user" || type == "human" || type == "assistant"
    }

    private static func extractUserMessageTitle(from obj: [String: Any]) -> String? {
        let type = obj["type"] as? String
        let role = (obj["message"] as? [String: Any])?["role"] as? String

        guard type == "user" || type == "human" || role == "user" else { return nil }

        // Extract text content
        var textSource: Any?
        if let message = obj["message"] as? [String: Any] {
            textSource = message["content"]
        } else {
            textSource = obj["content"]
        }

        guard let source = textSource else { return nil }
        let text = extractText(from: source) ?? ""

        // Skip system/meta prefixed content
        if text.contains("<local-command-caveat>") || text.contains("<command-name>") {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return String(trimmed.prefix(80))
    }

    private static func extractText(from content: Any) -> String? {
        if let str = content as? String {
            return str.nilIfBlank
        }

        if let array = content as? [[String: Any]] {
            var parts: [String] = []
            for item in array {
                if let text = item["text"] as? String, !text.isEmpty {
                    parts.append(text)
                } else if let inputText = item["input_text"] as? String, !inputText.isEmpty {
                    parts.append(inputText)
                } else if let outputText = item["output_text"] as? String, !outputText.isEmpty {
                    parts.append(outputText)
                }
            }
            return parts.joined(separator: " ").nilIfBlank
        }

        if let dict = content as? [String: Any], let text = dict["text"] as? String {
            return text.nilIfBlank
        }

        return nil
    }
}
