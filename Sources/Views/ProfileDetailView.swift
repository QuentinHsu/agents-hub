import SwiftUI

struct ProfileDetailView: View {
    @Environment(LocalizationManager.self) private var lm

    private let formFieldWidth: CGFloat = 330
    private let apiKeyFieldWidth: CGFloat = 286

    @Bindable var manager: ProfileManager
    var profileID: UUID?
    @State private var revealKey = false

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
        }
        .onChange(of: profileID) {
            selectRoutedProfile()
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
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.base_url", using: lm), detail: defaultURLText(for: profile.provider))
            } trailing: {
                TextField(L.string("ui.profile.base_url", using: lm), text: binding(for: \.baseURL))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
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
                        } else {
                            SecureField(L.string("ui.profile.api_key", using: lm), text: binding(for: \.apiKey))
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
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_sonnet_model", using: lm), detail: "ANTHROPIC_DEFAULT_SONNET_MODEL")
            } trailing: {
                TextField("sonnet", text: claudeModelBinding(for: \.defaultSonnetModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(L.string("ui.profile.default_haiku_model", using: lm), detail: "ANTHROPIC_DEFAULT_HAIKU_MODEL")
            } trailing: {
                TextField("haiku", text: claudeModelBinding(for: \.defaultHaikuModel))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: formFieldWidth)
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<APIProfile, String>) -> Binding<String> {
        Binding {
            profile?[keyPath: keyPath] ?? ""
        } set: { newValue in
            manager.updateSelectedProfile { profile in
                profile[keyPath: keyPath] = newValue
            }
        }
    }

    private func claudeModelBinding(
        for keyPath: WritableKeyPath<ClaudeCodeModelConfiguration, String>
    ) -> Binding<String> {
        Binding {
            profile?.claudeCodeModels[keyPath: keyPath] ?? ""
        } set: { newValue in
            manager.updateSelectedProfile { profile in
                profile.claudeCodeModels[keyPath: keyPath] = newValue
            }
        }
    }

    private func codexProviderNameModeBinding() -> Binding<CodexProviderNameMode> {
        Binding {
            profile?.codexProviderNameMode ?? .agentsHub
        } set: { newValue in
            manager.updateSelectedProfile { profile in
                profile.codexProviderNameMode = newValue
            }
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
