import Foundation

struct CLISession: Identifiable, Hashable {
    let id: String
    let provider: ProviderKind
    let name: String?
    let summary: String
    let projectPath: String
    let messageCount: Int
    let gitBranch: String?
    let createdAt: Date?
    let updatedAt: Date?
    let filePath: URL

    var displayName: String {
        name?.nilIfBlank ?? summary.nilIfBlank ?? id
    }

    var displayProjectPath: String {
        if projectPath.hasPrefix("/") {
            return projectPath.abbreviatingHome
        }
        return projectPath
    }

    var displayFileSize: String? {
        guard let size = try? filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
