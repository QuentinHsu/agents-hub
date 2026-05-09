import AppKit
import SwiftUI

struct AgentProfilesView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    let provider: ProviderKind
    @Binding var path: [DetailRoute]
    @State private var sessionManager: SessionManager
    @State private var profilePendingDelete: APIProfile?

    init(manager: ProfileManager, provider: ProviderKind, path: Binding<[DetailRoute]>) {
        self.manager = manager
        self.provider = provider
        self._path = path
        self._sessionManager = State(initialValue: SessionManager(provider: provider))
    }

    var body: some View {
        SettingsPageContent {
            if provider == .claudeCode {
                claudeSharedSettings
            }
            profilesList
            AgentSessionsView(sessionManager: sessionManager, provider: provider)
            targetFiles
        }
        .navigationTitle(provider.displayName)
        .task {
            await sessionManager.loadSessions()
        }
        .confirmationDialog(
            L.string("ui.confirm.delete_configuration", using: lm),
            isPresented: deleteConfirmationBinding(for: $profilePendingDelete)
        ) {
            Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                if let profilePendingDelete {
                    manager.selectProfile(profilePendingDelete)
                    manager.removeSelectedProfile()
                    path.removeAll()
                    self.profilePendingDelete = nil
                }
            }
            Button(L.string("ui.action.cancel", using: lm), role: .cancel) {
                profilePendingDelete = nil
            }
        } message: {
            Text(L.string("ui.confirm.delete_configuration_detail", using: lm))
        }
    }

    private var sortedProfiles: [APIProfile] {
        manager.profiles(for: provider)
    }

    private var profilesList: some View {
        let profiles = sortedProfiles
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(profiles) { profile in
                Button {
                    manager.selectProfile(profile)
                    path.append(.profile(profile.id))
                } label: {
                    profileRow(profile)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(L.string("ui.action.set_current", using: lm)) {
                        manager.selectProfile(profile)
                        manager.applySelectedProfile()
                    }
                    .disabled(!manager.isProfileReady(profile))

                    Button(L.string("ui.action.duplicate", using: lm)) {
                        manager.selectProfile(profile)
                        manager.duplicateSelectedProfile()
                    }

                    Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                        profilePendingDelete = profile
                    }
                    .disabled(profiles.count <= 1)
                }

                if profile.id != profiles.last?.id {
                    SettingsDivider()
                }
            }
        }
        .settingsCard(L.string("ui.agent_profiles.configurations", using: lm))
    }

    private var claudeSharedSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.skip_claude_onboarding", using: lm),
                    detail: L.string("ui.profile.skip_claude_onboarding_detail", using: lm),
                    detailLineLimit: 1
                )
            } trailing: {
                Toggle("", isOn: skipClaudeOnboardingBinding())
                    .labelsHidden()
            }
        }
        .settingsCard(L.string("ui.agent_profiles.shared_settings", using: lm))
    }

    private var targetFiles: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(targetURLs, id: \.self) { url in
                SettingsRow {
                    Text(url.path())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } trailing: {
                    Button {
                        reveal(url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(L.string("ui.action.reveal_in_finder", using: lm))
                }
            }
        }
        .settingsCard(L.string("ui.profile.apply_target", using: lm), subtitle: targetDescription)
    }

    private func profileRow(_ profile: APIProfile) -> some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(.subheadline.weight(.semibold))
                    if profile.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .help(L.string("ui.label.current", using: lm))
                    }
                }

                Text(profileDetailText(profile))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func profileDetailText(_ profile: APIProfile) -> String {
        guard let apiProvider = manager.apiProvider(for: profile) else {
            return L.string("ui.api_provider.no_provider", using: lm)
        }

        let key = manager.apiProviderKey(for: profile)
        let keyName = apiProvider.keys.count > 1 ? " · \(key?.name ?? "")" : ""
        let keyValue = key?.redactedKey ?? L.string("ui.label.no_key", using: lm)
        return "\(apiProvider.name)\(keyName) · \(profile.displayModel) · \(keyValue)"
    }

    private var targetURLs: [URL] {
        switch provider {
        case .claudeCode:
            [AppPaths.claudeSettingsURL]
        case .codex:
            [AppPaths.codexConfigURL, AppPaths.codexAuthURL]
        }
    }

    private var targetDescription: String {
        switch provider {
        case .claudeCode:
            L.string("ui.profile.target_claude_detail", using: lm)
        case .codex:
            L.string("ui.profile.target_codex_detail", using: lm)
        }
    }

    private func skipClaudeOnboardingBinding() -> Binding<Bool> {
        Binding {
            manager.skipClaudeCodeOnboarding
        } set: { newValue in
            manager.updateSkipClaudeCodeOnboarding(newValue)
        }
    }

    private func reveal(_ url: URL) {
        let directory = url.deletingLastPathComponent()
        NSWorkspace.shared.selectFile(url.path(), inFileViewerRootedAtPath: directory.path())
    }
}
