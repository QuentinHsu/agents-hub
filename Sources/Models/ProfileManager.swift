import Foundation
import Observation

@MainActor
@Observable
final class ProfileManager {
    var profiles: [APIProfile]
    var apiProviders: [APIProvider] {
        didSet {
            rebuildIndexes()
        }
    }
    var skipClaudeCodeOnboarding: Bool
    var selectedProvider: ProviderKind = .claudeCode {
        didSet {
            ensureSelection(for: selectedProvider)
        }
    }
    var selectedProfileIDs: [ProviderKind: UUID] = [:]
    var selectedAPIProviderID: UUID?
    private(set) var feedbackRevision = 0
    var statusMessage: String? {
        didSet {
            if statusMessage != nil {
                feedbackRevision += 1
            }
        }
    }
    var errorMessage: String? {
        didSet {
            if errorMessage != nil {
                feedbackRevision += 1
            }
        }
    }

    private var apiProvidersByID: [UUID: APIProvider] = [:]
    private var keysByID: [UUID: APIProviderKey] = [:]

    private let store: ProfileStore
    private let writer: ConfigurationWriter

    init(store: ProfileStore = ProfileStore(), writer: ConfigurationWriter = ConfigurationWriter()) {
        self.store = store
        self.writer = writer
        let state = store.load()
        self.profiles = state.profiles
        self.apiProviders = state.apiProviders
        self.skipClaudeCodeOnboarding = state.skipClaudeCodeOnboarding

        rebuildIndexes()
        ensureDefaults()
        selectedProvider = profiles.first(where: \.isActive)?.provider ?? .claudeCode
        for provider in ProviderKind.allCases {
            ensureSelection(for: provider)
        }
        ensureProviderSelection()
    }

    private func rebuildIndexes() {
        apiProvidersByID = Dictionary(uniqueKeysWithValues: apiProviders.map { ($0.id, $0) })
        keysByID = Dictionary(
            uniqueKeysWithValues: apiProviders.flatMap { provider in
                provider.keys.map { ($0.id, $0) }
            }
        )
    }

    private func handleOperation<T>(
        successMessage: String? = nil,
        operation: () throws -> T
    ) rethrows -> T {
        do {
            let result = try operation()
            statusMessage = successMessage
            errorMessage = nil
            return result
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func clearMessages() {
        statusMessage = nil
        errorMessage = nil
    }

    private func ensureDefaults() {
        var changed = false

        if apiProviders.isEmpty {
            let legacyProfile = profiles.first { $0.baseURL.nilIfBlank != nil }
            let baseURL = legacyProfile?.baseURL ?? ProviderKind.codex.defaultBaseURL
            let keys: [APIProviderKey]? = legacyProfile?.apiKey.nilIfBlank.map { [APIProviderKey(name: "Default", apiKey: $0)] }

            apiProviders.append(APIProvider(
                name: LocalizationManager.localize("api_provider.default_provider_name"),
                baseURL: baseURL,
                keys: keys ?? [APIProviderKey(name: "Default")]
            ))
            changed = true
        }

        for index in apiProviders.indices {
            let provider = apiProviders[index]
            let needsBaseURL = provider.baseURL.nilIfBlank == nil
            let needsKey = !provider.keys.contains { $0.isReady }

            guard needsBaseURL || needsKey else { continue }

            if let donorProfile = profiles.first(where: { $0.apiProviderID == provider.id && $0.baseURL.nilIfBlank != nil })
                ?? profiles.first(where: { $0.baseURL.nilIfBlank != nil })
            {
                if needsBaseURL {
                    apiProviders[index].baseURL = donorProfile.baseURL
                }
                if needsKey, let donorKey = donorProfile.apiKey.nilIfBlank {
                    if let firstKeyIndex = apiProviders[index].keys.firstIndex(where: { !$0.isReady }) {
                        apiProviders[index].keys[firstKeyIndex].apiKey = donorKey
                    } else {
                        apiProviders[index].keys.append(APIProviderKey(name: "Default", apiKey: donorKey))
                    }
                }
                apiProviders[index].updatedAt = .now
                changed = true
            }
        }

        for provider in ProviderKind.allCases where !profiles.contains(where: { $0.provider == provider }) {
            profiles.append(APIProfile(
                provider: provider,
                apiProviderID: apiProviders.first?.id,
                apiProviderKeyID: apiProviders.first?.keys.first?.id,
                name: provider.displayName
            ))
            changed = true
        }

        for index in profiles.indices where profiles[index].apiProviderID == nil {
            profiles[index].apiProviderID = apiProviders.first?.id
            profiles[index].apiProviderKeyID = apiProviders.first?.keys.first?.id
            changed = true
        }

        for index in profiles.indices where profiles[index].apiProviderKeyID == nil {
            profiles[index].apiProviderKeyID = apiProvider(for: profiles[index])?.keys.first?.id
            changed = true
        }

        if changed {
            save()
        }
    }

    private func ensureSelection(for provider: ProviderKind) {
        let providerProfiles = profiles.filter { $0.provider == provider }
        guard !providerProfiles.isEmpty else {
            selectedProfileIDs[provider] = nil
            return
        }

        if let selectedID = selectedProfileIDs[provider],
           providerProfiles.contains(where: { $0.id == selectedID })
        {
            return
        }

        selectedProfileIDs[provider] = providerProfiles.first(where: \.isActive)?.id ?? providerProfiles.first?.id
    }

    private func ensureProviderSelection() {
        guard !apiProviders.isEmpty else {
            selectedAPIProviderID = nil
            return
        }

        if let selectedAPIProviderID,
           apiProviders.contains(where: { $0.id == selectedAPIProviderID })
        {
            return
        }

        selectedAPIProviderID = sortedAPIProviders().first?.id
    }

    private func save() {
        do {
            try store.save(AgentsHubState(
                profiles: profiles,
                apiProviders: apiProviders,
                skipClaudeCodeOnboarding: skipClaudeCodeOnboarding
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Profile Queries
extension ProfileManager {
    var selectedProfile: APIProfile? {
        selectedProfile(for: selectedProvider)
    }

    func profiles(for provider: ProviderKind) -> [APIProfile] {
        profiles
            .filter { $0.provider == provider }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func activeProfile(for provider: ProviderKind) -> APIProfile? {
        guard let profile = profiles.first(where: { $0.provider == provider && $0.isActive }) else { return nil }
        return resolvedProfile(profile)
    }

    func selectedProfile(for provider: ProviderKind) -> APIProfile? {
        ensureSelection(for: provider)
        guard let selectedID = selectedProfileIDs[provider] else { return nil }
        return profiles.first { $0.id == selectedID && $0.provider == provider }
    }

    func isProfileReady(_ profile: APIProfile) -> Bool {
        resolvedProfile(profile).isReady
    }
}

// MARK: - Profile Management
extension ProfileManager {
    func selectProfile(_ profile: APIProfile) {
        selectedProvider = profile.provider
        selectedProfileIDs[profile.provider] = profile.id
    }

    func updateSelectedProfile(_ update: (inout APIProfile) -> Void) {
        ensureSelection(for: selectedProvider)
        guard let selectedID = selectedProfileIDs[selectedProvider],
              let index = profiles.firstIndex(where: { $0.id == selectedID })
        else { return }

        var updatedProfile = profiles[index]
        update(&updatedProfile)
        guard updatedProfile != profiles[index] else { return }

        updatedProfile.updatedAt = .now
        profiles[index] = updatedProfile

        if updatedProfile.isActive {
            do {
                try writer.apply(resolvedProfile(updatedProfile))
                statusMessage = String(
                    format: LocalizationManager.localize(LocalizationKeys.statusProfileSavedAndApplied),
                    updatedProfile.name,
                    updatedProfile.provider.displayName
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            statusMessage = String(
                format: LocalizationManager.localize(LocalizationKeys.statusProfileSaved),
                updatedProfile.name
            )
            errorMessage = nil
        }
        save()
    }

    func updateProfile(id: UUID, _ update: (inout APIProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }

        selectedProvider = profiles[index].provider
        selectedProfileIDs[profiles[index].provider] = id
        updateSelectedProfile(update)
    }

    func addProfile(for provider: ProviderKind? = nil) {
        let provider = provider ?? selectedProvider
        ensureProviderSelection()
        let selectedAPIProvider = selectedAPIProvider()
        let count = profiles.filter { $0.provider == provider }.count + 1
        let profile = APIProfile(
            provider: provider,
            apiProviderID: selectedAPIProvider?.id,
            apiProviderKeyID: selectedAPIProvider?.keys.first?.id,
            name: String(
                format: LocalizationManager.localize(LocalizationKeys.profileDefaultName),
                provider.shortName,
                Int64(count)
            )
        )
        profiles.append(profile)
        selectedProvider = provider
        selectedProfileIDs[provider] = profile.id
        clearMessages()
        save()
    }

    func duplicateSelectedProfile() {
        guard var selectedProfile else { return }
        selectedProfile.id = UUID()
        selectedProfile.name = String(
            format: LocalizationManager.localize(LocalizationKeys.profileCopyName),
            selectedProfile.name
        )
        selectedProfile.isActive = false
        selectedProfile.updatedAt = .now
        profiles.append(selectedProfile)
        selectedProfileIDs[selectedProfile.provider] = selectedProfile.id
        clearMessages()
        save()
    }

    func removeSelectedProfile() {
        ensureSelection(for: selectedProvider)
        let provider = selectedProvider
        let providerProfiles = profiles(for: provider)
        guard providerProfiles.count > 1,
              let selectedID = selectedProfileIDs[provider]
        else { return }

        profiles.removeAll { $0.id == selectedID }
        selectedProfileIDs[provider] = nil
        ensureSelection(for: provider)
        statusMessage = nil
        errorMessage = nil
        save()
    }

    func applySelectedProfile() {
        guard let selectedProfile else { return }

        do {
            try writer.apply(resolvedProfile(selectedProfile))
            for index in profiles.indices {
                if profiles[index].provider == selectedProfile.provider {
                    profiles[index].isActive = profiles[index].id == selectedProfile.id
                }
            }
            statusMessage = String(
                format: LocalizationManager.localize("status.profile_applied"),
                selectedProfile.name,
                selectedProfile.provider.displayName
            )
            errorMessage = nil
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - API Provider Queries
extension ProfileManager {
    func sortedAPIProviders() -> [APIProvider] {
        apiProviders
            .sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
    }

    func selectedAPIProvider() -> APIProvider? {
        ensureProviderSelection()
        guard let selectedAPIProviderID else { return nil }
        return apiProvidersByID[selectedAPIProviderID]
    }

    func apiProvider(for profile: APIProfile) -> APIProvider? {
        if let apiProviderID = profile.apiProviderID,
           let apiProvider = apiProvidersByID[apiProviderID]
        {
            return apiProvider
        }

        return sortedAPIProviders().first
    }

    func apiProviderKey(for profile: APIProfile) -> APIProviderKey? {
        guard let apiProvider = apiProvider(for: profile) else { return nil }
        if let keyID = profile.apiProviderKeyID,
           let key = keysByID[keyID]
        {
            return key
        }

        return apiProvider.keys.first
    }

    func resolvedProfile(_ profile: APIProfile) -> APIProfile {
        profile.resolved(with: apiProvider(for: profile), key: apiProviderKey(for: profile))
    }
}

// MARK: - API Provider Management
extension ProfileManager {
    func selectAPIProvider(_ apiProvider: APIProvider) {
        selectedAPIProviderID = apiProvider.id
    }

    func addAPIProvider() {
        let count = apiProviders.count + 1
        let apiProvider = APIProvider(
            name: String(
                format: LocalizationManager.localize(LocalizationKeys.apiProviderDefaultName),
                Int64(count)
            )
        )
        apiProviders.append(apiProvider)
        selectedAPIProviderID = apiProvider.id
        clearMessages()
        save()
    }

    func duplicateSelectedAPIProvider() {
        guard var apiProvider = selectedAPIProvider() else { return }
        apiProvider.id = UUID()
        apiProvider.keys = apiProvider.keys.map { key in
            var key = key
            key.id = UUID()
            return key
        }
        apiProvider.name = String(
            format: LocalizationManager.localize(LocalizationKeys.profileCopyName),
            apiProvider.name
        )
        apiProvider.updatedAt = .now
        apiProviders.append(apiProvider)
        selectedAPIProviderID = apiProvider.id
        clearMessages()
        save()
    }

    func removeSelectedAPIProvider() {
        guard apiProviders.count > 1,
              let selectedID = selectedAPIProviderID
        else { return }

        apiProviders.removeAll { $0.id == selectedID }
        selectedAPIProviderID = nil
        ensureProviderSelection()
        let fallbackProvider = selectedAPIProvider()
        for index in profiles.indices where profiles[index].apiProviderID == selectedID {
            profiles[index].apiProviderID = fallbackProvider?.id
            profiles[index].apiProviderKeyID = fallbackProvider?.keys.first?.id
            profiles[index].updatedAt = .now
        }
        statusMessage = nil
        errorMessage = nil
        save()
    }

    func updateAPIProvider(id: UUID, _ update: (inout APIProvider) -> Void) {
        guard let index = apiProviders.firstIndex(where: { $0.id == id }) else { return }

        selectedAPIProviderID = id
        var updatedProvider = apiProviders[index]
        update(&updatedProvider)
        if updatedProvider.keys.isEmpty {
            updatedProvider.keys = [APIProviderKey(name: "Default")]
        }
        guard updatedProvider != apiProviders[index] else { return }

        updatedProvider.updatedAt = .now
        apiProviders[index] = updatedProvider
        statusMessage = String(
            format: LocalizationManager.localize("status.api_provider_saved"),
            updatedProvider.name
        )
        errorMessage = nil

        for profile in profiles where profile.apiProviderID == id && profile.isActive {
            do {
                try writer.apply(resolvedProfile(profile))
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        save()
    }

    func addKey(to apiProviderID: UUID) {
        guard let index = apiProviders.firstIndex(where: { $0.id == apiProviderID }) else { return }

        let count = apiProviders[index].keys.count + 1
        apiProviders[index].keys.append(APIProviderKey(
            name: String(
                format: LocalizationManager.localize("api_provider.key_default_name"),
                Int64(count)
            )
        ))
        apiProviders[index].updatedAt = .now
        selectedAPIProviderID = apiProviderID
        clearMessages()
        save()
    }

    func removeKey(_ keyID: UUID, from apiProviderID: UUID) {
        guard let providerIndex = apiProviders.firstIndex(where: { $0.id == apiProviderID }),
              apiProviders[providerIndex].keys.count > 1
        else { return }

        apiProviders[providerIndex].keys.removeAll { $0.id == keyID }
        apiProviders[providerIndex].updatedAt = .now
        let fallbackKeyID = apiProviders[providerIndex].keys.first?.id
        for index in profiles.indices where profiles[index].apiProviderID == apiProviderID && profiles[index].apiProviderKeyID == keyID {
            profiles[index].apiProviderKeyID = fallbackKeyID
            profiles[index].updatedAt = .now
        }
        selectedAPIProviderID = apiProviderID
        clearMessages()
        save()
    }
}

// MARK: - Settings Management
extension ProfileManager {
    func updateSkipClaudeCodeOnboarding(_ enabled: Bool) {
        guard skipClaudeCodeOnboarding != enabled else { return }

        skipClaudeCodeOnboarding = enabled
        do {
            try writer.syncClaudeOnboarding(skip: enabled)
            statusMessage = LocalizationManager.localize("status.claude_onboarding_updated")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        save()
    }

    func resetState() {
        let state = AgentsHubState.empty
        profiles = state.profiles
        apiProviders = state.apiProviders
        skipClaudeCodeOnboarding = state.skipClaudeCodeOnboarding
        selectedProvider = .claudeCode
        selectedProfileIDs.removeAll()
        selectedAPIProviderID = nil

        for provider in ProviderKind.allCases {
            ensureSelection(for: provider)
        }
        ensureProviderSelection()

        statusMessage = LocalizationManager.localize(LocalizationKeys.statusStateReset)
        errorMessage = nil
        save()
    }
}
