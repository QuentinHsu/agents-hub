import Foundation

struct APIProvider: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var baseURL: String
    var providerWebsiteURL: String
    var keys: [APIProviderKey]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String = "",
        providerWebsiteURL: String = "",
        keys: [APIProviderKey] = [APIProviderKey(name: "Default")],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.providerWebsiteURL = providerWebsiteURL
        self.keys = keys.isEmpty ? [APIProviderKey(name: "Default")] : keys
        self.updatedAt = updatedAt
    }

    var redactedKey: String {
        keys.first?.redactedKey ?? LocalizationManager.localize(LocalizationKeys.noKey)
    }

    var isReady: Bool {
        baseURL.nilIfBlank != nil && keys.contains { $0.isReady }
    }
}

struct APIProviderKey: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var apiKey: String

    init(
        id: UUID = UUID(),
        name: String,
        apiKey: String = ""
    ) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
    }

    var redactedKey: String {
        apiKey.redacted(emptyPlaceholder: LocalizationManager.localize(LocalizationKeys.noKey))
    }

    var isReady: Bool {
        apiKey.nilIfBlank != nil
    }

}
