import SwiftUI

struct ProfileDetailView: View {
    @Environment(LocalizationManager.self) private var lm

    private let formFieldWidth: CGFloat = 330
    private let apiKeyFieldWidth: CGFloat = 286

    @Bindable var manager: ProfileManager
    var profileID: UUID?
    @State private var revealKey = false
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
                    .frame(width: formFieldWidth)
                    .focused($focusedField, equals: .name)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.base_url", using: lm), detail: defaultURLText(for: profile.provider))
            } trailing: {
                TextField(L.string("ui.profile.base_url", using: lm), text: binding(for: \.baseURL))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
                    .focused($focusedField, equals: .baseURL)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.provider_website", using: lm),
                    detail: L.string("ui.profile.provider_website_detail", using: lm)
                )
            } trailing: {
                HStack(spacing: 8) {
                    TextField(
                        L.string("ui.profile.provider_website_placeholder", using: lm),
                        text: binding(for: \.providerWebsiteURL)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: apiKeyFieldWidth)
                    .focused($focusedField, equals: .providerWebsiteURL)

                    Button {
                        openProviderWebsite()
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.borderless)
                    .disabled(providerWebsiteURL(for: profile) == nil)
                    .help(L.string("ui.hint.open_provider_website", using: lm))
                }
                .frame(width: formFieldWidth, alignment: .leading)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.api_key", using: lm),
                    detail: L.string("ui.profile.api_key_detail", using: lm)
                )
            } trailing: {
                HStack(spacing: 8) {
                    Group {
                        if revealKey {
                            TextField(L.string("ui.profile.api_key", using: lm), text: binding(for: \.apiKey))
                                .focused($focusedField, equals: .apiKey)
                        } else {
                            SecureField(L.string("ui.profile.api_key", using: lm), text: binding(for: \.apiKey))
                                .focused($focusedField, equals: .apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: apiKeyFieldWidth)

                    Button {
                        revealKey.toggle()
                    } label: {
                        Image(systemName: revealKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(revealKey ? L.string("ui.hint.hide_api_key", using: lm) : L.string("ui.hint.show_api_key", using: lm))
                }
                .frame(width: formFieldWidth, alignment: .leading)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.model", using: lm), detail: modelDetail(for: profile.provider))
            } trailing: {
                TextField(L.string("ui.profile.model", using: lm), text: binding(for: \.model))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
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
            .frame(width: formFieldWidth, alignment: .leading)
        }
    }

    private func claudeModelFields() -> some View {
        VStack(spacing: 0) {
            SettingsRow {
                FieldLabel(L.string("ui.profile.default_opus_model", using: lm), detail: "ANTHROPIC_DEFAULT_OPUS_MODEL")
            } trailing: {
                TextField("opus", text: claudeModelBinding(for: \.defaultOpusModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
                    .focused($focusedField, equals: .defaultOpusModel)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_sonnet_model", using: lm), detail: "ANTHROPIC_DEFAULT_SONNET_MODEL")
            } trailing: {
                TextField("sonnet", text: claudeModelBinding(for: \.defaultSonnetModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
                    .focused($focusedField, equals: .defaultSonnetModel)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_haiku_model", using: lm), detail: "ANTHROPIC_DEFAULT_HAIKU_MODEL")
            } trailing: {
                TextField("haiku", text: claudeModelBinding(for: \.defaultHaikuModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
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

    private func codexProviderNameModeBinding() -> Binding<CodexProviderNameMode> {
        Binding {
            draftProfile?.codexProviderNameMode ?? profile?.codexProviderNameMode ?? .agentsHub
        } set: { newValue in
            ensureDraftProfile()
            draftProfile?.codexProviderNameMode = newValue
            commitDraftProfile()
        }
    }

    private func defaultURLText(for provider: ProviderKind) -> String {
        L.string("ui.profile.default_url", provider.defaultBaseURL, using: lm)
    }

    private func modelDetail(for provider: ProviderKind) -> String {
        switch provider {
        case .claudeCode:
            L.string("ui.profile.model_detail_claude", using: lm)
        case .codex:
            L.string("ui.profile.model_detail_codex", using: lm)
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

    private func openProviderWebsite() {
        guard let profile,
              let url = providerWebsiteURL(for: profile)
        else { return }

        NSWorkspace.shared.open(url)
    }

    private func providerWebsiteURL(for profile: APIProfile) -> URL? {
        let trimmed = profile.providerWebsiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false
        else { return nil }

        return url
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
            profile.baseURL = draftProfile.baseURL
            profile.providerWebsiteURL = draftProfile.providerWebsiteURL
            profile.apiKey = draftProfile.apiKey
            profile.model = draftProfile.model
            profile.codexProviderNameMode = draftProfile.codexProviderNameMode
            profile.claudeCodeModels = draftProfile.claudeCodeModels
        }
        syncDraftProfile()
    }
}

private enum ProfileField: Hashable {
    case name
    case baseURL
    case providerWebsiteURL
    case apiKey
    case model
    case defaultOpusModel
    case defaultSonnetModel
    case defaultHaikuModel
}

private struct FieldLabel: View {
    let title: String
    let detail: String

    init(_ title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
