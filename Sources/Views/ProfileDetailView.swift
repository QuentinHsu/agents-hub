import SwiftUI

struct ProfileDetailView: View {
    @Environment(LocalizationManager.self) private var lm

    @Bindable var manager: ProfileManager
    var profileID: UUID?
    @State private var draftProfile: APIProfile?
    @FocusState private var focusedField: ProfileField?

    private var profile: APIProfile? {
        if let profileID {
            return manager.profiles.first { $0.id == profileID }
        }

        return manager.selectedProfile
    }

    var body: some View {
        Group {
            if let profile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profileForm(for: profile)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(L.string("ui.profile.no_profile", using: lm), systemImage: "switch.2")
            }
        }
        .onAppear {
            selectRoutedProfile()
            syncDraftProfile()
        }
        .onChange(of: profileID) {
            commitDraftProfile()
            selectRoutedProfile()
            syncDraftProfile()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil && oldValue != newValue {
                commitDraftProfile()
            }
        }
        .onDisappear {
            commitDraftProfile()
        }
    }

    private func profileForm(for profile: APIProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.profile_name", using: lm),
                    detail: L.string("ui.profile.profile_name_detail", using: lm)
                )
            } trailing: {
                TextField(L.string("ui.profile.name_placeholder", using: lm), text: binding(for: \.name))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .name)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.api_provider", using: lm),
                    detail: L.string("ui.profile.api_provider_detail", using: lm)
                )
            } trailing: {
                Picker("", selection: apiProviderBinding(for: profile)) {
                    ForEach(manager.sortedAPIProviders()) { apiProvider in
                        Text(apiProvider.name).tag(Optional(apiProvider.id))
                    }
                }
                .labelsHidden()
                .frame(width: FormConstants.fieldWidth, alignment: .leading)
            }

            SettingsDivider()

            if let apiProvider = manager.apiProvider(for: profile), apiProvider.keys.count > 1 {
                apiProviderKeyPicker(for: profile, apiProvider: apiProvider)

                SettingsDivider()
            }

            apiProviderSummary(for: profile)

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.model", using: lm), detail: modelDetail(for: profile.provider))
            } trailing: {
                TextField(L.string("ui.profile.model", using: lm), text: binding(for: \.model))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .model)
            }

            if profile.provider == .codex {
                SettingsDivider()
                codexProviderNameModeField()
            }

            if profile.provider == .claudeCode {
                SettingsDivider()
                claudeModelFields()
            }
        }
        .settingsCard()
    }

    private func apiProviderSummary(for profile: APIProfile) -> some View {
        let apiProvider = manager.apiProvider(for: profile)
        let key = manager.apiProviderKey(for: profile)

        return SettingsRow {
            FieldLabel(
                L.string("ui.profile.api_provider_data", using: lm),
                detail: providerKeySummary(apiProvider: apiProvider, key: key)
            )
        } trailing: {
            VStack(alignment: .trailing, spacing: 3) {
                Text(apiProvider?.baseURL.nilIfBlank ?? L.string("ui.label.no_base_url", using: lm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(key?.redactedKey ?? L.string("ui.label.no_key", using: lm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: FormConstants.fieldWidth, alignment: .trailing)
        }
    }

    private func apiProviderKeyPicker(for profile: APIProfile, apiProvider: APIProvider) -> some View {
        SettingsRow {
            FieldLabel(
                L.string("ui.profile.api_provider_key", using: lm),
                detail: L.string("ui.profile.api_provider_key_detail", using: lm)
            )
        } trailing: {
            Picker("", selection: apiProviderKeyBinding(for: profile, apiProvider: apiProvider)) {
                ForEach(apiProvider.keys) { key in
                    Text(key.name).tag(Optional(key.id))
                }
            }
            .labelsHidden()
            .frame(width: FormConstants.fieldWidth, alignment: .leading)
        }
    }

    private func codexProviderNameModeField() -> some View {
        SettingsRow {
            FieldLabel(
                L.string("ui.profile.codex_provider_name", using: lm),
                detail: L.string("ui.profile.codex_provider_name_detail", using: lm)
            )
        } trailing: {
            Picker(
                "",
                selection: codexProviderNameModeBinding()
            ) {
                ForEach(CodexProviderNameMode.allCases) { mode in
                    Text(codexProviderNameModeLabel(mode)).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: FormConstants.fieldWidth, alignment: .leading)
        }
    }

    private func claudeModelFields() -> some View {
        VStack(spacing: 0) {
            SettingsRow {
                FieldLabel(L.string("ui.profile.default_opus_model", using: lm), detail: "ANTHROPIC_DEFAULT_OPUS_MODEL")
            } trailing: {
                TextField("opus", text: claudeModelBinding(for: \.defaultOpusModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .defaultOpusModel)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_sonnet_model", using: lm), detail: "ANTHROPIC_DEFAULT_SONNET_MODEL")
            } trailing: {
                TextField("sonnet", text: claudeModelBinding(for: \.defaultSonnetModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .defaultSonnetModel)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_haiku_model", using: lm), detail: "ANTHROPIC_DEFAULT_HAIKU_MODEL")
            } trailing: {
                TextField("haiku", text: claudeModelBinding(for: \.defaultHaikuModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .defaultHaikuModel)
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<APIProfile, String>) -> Binding<String> {
        Binding {
            draftProfile?[keyPath: keyPath] ?? profile?[keyPath: keyPath] ?? ""
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?[keyPath: keyPath] = newValue
        }
    }

    private func claudeModelBinding(
        for keyPath: WritableKeyPath<ClaudeCodeModelConfiguration, String>
    ) -> Binding<String> {
        Binding {
            draftProfile?.claudeCodeModels[keyPath: keyPath] ?? profile?.claudeCodeModels[keyPath: keyPath] ?? ""
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?.claudeCodeModels[keyPath: keyPath] = newValue
        }
    }

    private func modelDetail(for provider: ProviderKind) -> String {
        switch provider {
        case .claudeCode:
            L.string("ui.profile.model_detail_claude", using: lm)
        case .codex:
            L.string("ui.profile.model_detail_codex", using: lm)
        }
    }

    private func codexProviderNameModeBinding() -> Binding<CodexProviderNameMode> {
        Binding {
            draftProfile?.codexProviderNameMode ?? profile?.codexProviderNameMode ?? .agentsHub
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?.codexProviderNameMode = newValue
            commitDraftProfile()
        }
    }

    private func codexProviderNameModeLabel(_ mode: CodexProviderNameMode) -> String {
        switch mode {
        case .agentsHub:
            L.string("ui.profile.codex_provider_name_agents_hub", using: lm)
        case .profileName:
            L.string("ui.profile.codex_provider_name_profile", using: lm)
        }
    }

    private func apiProviderBinding(for profile: APIProfile) -> Binding<UUID?> {
        Binding {
            draftProfile?.apiProviderID ?? profile.apiProviderID ?? manager.apiProvider(for: profile)?.id
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?.apiProviderID = newValue
            if let newValue,
               let apiProvider = manager.apiProviders.first(where: { $0.id == newValue })
            {
                draftProfile?.apiProviderKeyID = apiProvider.keys.first?.id
            } else {
                draftProfile?.apiProviderKeyID = nil
            }
            commitDraftProfile()
        }
    }

    private func apiProviderKeyBinding(for profile: APIProfile, apiProvider: APIProvider) -> Binding<UUID?> {
        Binding {
            draftProfile?.apiProviderKeyID ?? profile.apiProviderKeyID ?? apiProvider.keys.first?.id
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?.apiProviderKeyID = newValue
            commitDraftProfile()
        }
    }

    private func providerKeySummary(apiProvider: APIProvider?, key: APIProviderKey?) -> String {
        guard let apiProvider else { return L.string("ui.api_provider.no_provider", using: lm) }
        guard apiProvider.keys.count > 1, let key else { return apiProvider.name }
        return "\(apiProvider.name) · \(key.name)"
    }

    private func selectRoutedProfile() {
        guard let profileID,
              let profile = manager.profiles.first(where: { $0.id == profileID })
        else { return }

        manager.selectProfile(profile)
    }

    private func ensureDraftProfile() {
        guard draftProfile == nil else { return }
        syncDraftProfile()
    }

    private func syncDraftProfile() {
        draftProfile = profile
    }

    private func commitDraftProfile() {
        guard let draftProfile else { return }

        manager.updateProfile(id: draftProfile.id) { profile in
            profile.name = draftProfile.name
            profile.apiProviderID = draftProfile.apiProviderID
            profile.apiProviderKeyID = draftProfile.apiProviderKeyID
            profile.model = draftProfile.model
            profile.codexProviderNameMode = draftProfile.codexProviderNameMode
            profile.claudeCodeModels = draftProfile.claudeCodeModels
        }
        syncDraftProfile()
    }
}

private enum ProfileField: Hashable {
    case name
    case model
    case defaultOpusModel
    case defaultSonnetModel
    case defaultHaikuModel
}
