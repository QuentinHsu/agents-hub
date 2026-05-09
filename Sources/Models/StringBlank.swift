import Foundation

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func redacted(emptyPlaceholder: String) -> String {
        guard let trimmed = nilIfBlank else { return emptyPlaceholder }
        guard trimmed.count > 8 else { return String(repeating: "•", count: trimmed.count) }
        return "\(trimmed.prefix(4))••••\(trimmed.suffix(4))"
    }
}
