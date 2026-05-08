import Foundation
import Observation

@MainActor
@Observable
final class ProfileManager {
    var profiles: [APIProfile]
    var skipClaudeCodeOnboarding: Bool
    var selectedProvider: ProviderKind = .claudeCode {
        didSet {
            ensureSelection(for: selectedProvider)
        }
    }
    var selectedProfileIDs: [ProviderKind: UUID] = [:]
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

    private let store: ProfileStore
    private let writer: ConfigurationWriter

    init(store: ProfileStore = ProfileStore(), writer: ConfigurationWriter = ConfigurationWriter()) {
        self.store = store
        self.writer = writer
        let state = store.load()
        self.profiles = state.profiles
        self.skipClaudeCodeOnboarding = state.skipClaudeCodeOnboarding

        ensureDefaultProfiles()
        selectedProvider = profiles.first(where: \.isActive)?.provider ?? .claudeCode
        for provider in ProviderKind.allCases {
            ensureSelection(for: provider)
        }
    }

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
        profiles.first { $0.provider == provider && $0.isActive }
    }

    func selectedProfile(for provider: ProviderKind) -> APIProfile? {
        ensureSelection(for: provider)
        guard let selectedID = selectedProfileIDs[provider] else { return nil }
        return profiles.first { $0.id == selectedID && $0.provider == provider }
    }

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
                try writer.apply(updatedProfile)
                statusMessage = String(
                    format: LocalizationManager.localize("status.profile_saved_and_applied"),
                    updatedProfile.name,
                    updatedProfile.provider.displayName
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            statusMessage = String(
                format: LocalizationManager.localize("status.profile_saved"),
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
        let count = profiles.filter { $0.provider == provider }.count + 1
        let profile = APIProfile(
            provider: provider,
            name: String(
                format: LocalizationManager.localize("profile.default_name"),
                provider.shortName,
                Int64(count)
            )
        )
        profiles.append(profile)
        selectedProvider = provider
        selectedProfileIDs[provider] = profile.id
        statusMessage = nil
        errorMessage = nil
        save()
    }

    func duplicateSelectedProfile() {
        guard var selectedProfile else { return }
        selectedProfile.id = UUID()
        selectedProfile.name = String(
            format: LocalizationManager.localize("profile.copy_name"),
            selectedProfile.name
        )
        selectedProfile.isActive = false
        selectedProfile.updatedAt = .now
        profiles.append(selectedProfile)
        selectedProfileIDs[selectedProfile.provider] = selectedProfile.id
        statusMessage = nil
        errorMessage = nil
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
            try writer.apply(selectedProfile)
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

    private func ensureDefaultProfiles() {
        var changed = false

        for provider in ProviderKind.allCases where !profiles.contains(where: { $0.provider == provider }) {
            profiles.append(APIProfile(provider: provider, name: provider.displayName))
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

    private func save() {
        do {
            try store.save(AgentsHubState(
                profiles: profiles,
                skipClaudeCodeOnboarding: skipClaudeCodeOnboarding
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
