import SwiftUI

struct APIProviderDetailView: View {
    @Environment(LocalizationManager.self) private var lm

    @Bindable var manager: ProfileManager
    var apiProviderID: UUID?
    @State private var revealKeyIDs: Set<UUID> = []
    @State private var draftAPIProvider: APIProvider?
    @FocusState private var focusedField: APIProviderField?

    private var apiProvider: APIProvider? {
        if let apiProviderID {
            return manager.apiProviders.first { $0.id == apiProviderID }
        }

        return manager.selectedAPIProvider()
    }

    var body: some View {
        Group {
            if let apiProvider {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        providerForm(for: apiProvider)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(apiProvider.name)
            } else {
                ContentUnavailableView(L.string("ui.api_provider.no_provider", using: lm), systemImage: "server.rack")
            }
        }
        .onAppear {
            selectRoutedProvider()
            syncDraftProvider()
        }
        .onChange(of: apiProviderID) {
            commitDraftProvider()
            selectRoutedProvider()
            syncDraftProvider()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil && oldValue != newValue {
                commitDraftProvider()
            }
        }
        .onDisappear {
            commitDraftProvider()
        }
    }

    private func providerForm(for apiProvider: APIProvider) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            providerBasics(for: apiProvider)
            keysCard(for: apiProvider)
        }
    }

    private func providerBasics(for apiProvider: APIProvider) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldLabel(
                    L.string("ui.api_provider.name", using: lm),
                    detail: L.string("ui.api_provider.name_detail", using: lm)
                )
            } trailing: {
                TextField(L.string("ui.api_provider.name_placeholder", using: lm), text: binding(for: \.name))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
                    .focused($focusedField, equals: .providerName)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.base_url", using: lm),
                    detail: L.string("ui.api_provider.base_url_detail", using: lm)
                )
            } trailing: {
                TextField(L.string("ui.profile.base_url", using: lm), text: binding(for: \.baseURL))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.fieldWidth)
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
                    .frame(width: FormConstants.apiKeyFieldWidth)
                    .focused($focusedField, equals: .providerWebsiteURL)

                    Button {
                        openProviderWebsite()
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.borderless)
                    .disabled(providerWebsiteURL(for: apiProvider) == nil)
                    .help(L.string("ui.hint.open_provider_website", using: lm))
                }
                .frame(width: FormConstants.fieldWidth, alignment: .leading)
            }
        }
        .settingsCard(apiProvider.name)
    }

    private func keysCard(for apiProvider: APIProvider) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                Text(L.string("ui.api_provider.keys_detail", using: lm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } trailing: {
                Button {
                    commitDraftProvider()
                    manager.addKey(to: apiProvider.id)
                    syncDraftProvider()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(L.string("ui.hint.add_api_provider_key", using: lm))
            }

            ForEach(apiProvider.keys) { key in
                SettingsDivider()
                keyEditor(key, in: apiProvider)
            }
        }
        .settingsCard(L.string("ui.api_provider.keys", using: lm))
    }

    private func keyEditor(_ key: APIProviderKey, in apiProvider: APIProvider) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldLabel(
                    L.string("ui.api_provider.key_name", using: lm),
                    detail: key.redactedKey
                )
            } trailing: {
                HStack(spacing: 8) {
                    TextField(
                        L.string("ui.api_provider.key_name_placeholder", using: lm),
                        text: keyBinding(keyID: key.id, for: \.name)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.apiKeyFieldWidth)
                    .focused($focusedField, equals: .keyName(key.id))

                    Button {
                        commitDraftProvider()
                        manager.removeKey(key.id, from: apiProvider.id)
                        syncDraftProvider()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(apiProvider.keys.count <= 1)
                    .help(L.string("ui.hint.delete_api_provider_key", using: lm))
                }
                .frame(width: FormConstants.fieldWidth, alignment: .leading)
            }

            SettingsDivider()

            SettingsRow {
                FieldLabel(
                    L.string("ui.profile.api_key", using: lm),
                    detail: L.string("ui.api_provider.key_api_key_detail", using: lm)
                )
            } trailing: {
                HStack(spacing: 8) {
                    Group {
                        if revealKeyIDs.contains(key.id) {
                            TextField(L.string("ui.profile.api_key", using: lm), text: keyBinding(keyID: key.id, for: \.apiKey))
                                .focused($focusedField, equals: .apiKey(key.id))
                        } else {
                            SecureField(L.string("ui.profile.api_key", using: lm), text: keyBinding(keyID: key.id, for: \.apiKey))
                                .focused($focusedField, equals: .apiKey(key.id))
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: FormConstants.apiKeyFieldWidth)

                    Button {
                        toggleReveal(for: key.id)
                    } label: {
                        Image(systemName: revealKeyIDs.contains(key.id) ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(revealKeyIDs.contains(key.id) ? L.string("ui.hint.hide_api_key", using: lm) : L.string("ui.hint.show_api_key", using: lm))
                }
                .frame(width: FormConstants.fieldWidth, alignment: .leading)
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<APIProvider, String>) -> Binding<String> {
        Binding {
            draftAPIProvider?[keyPath: keyPath] ?? apiProvider?[keyPath: keyPath] ?? ""
        } set: { newValue in
            ensureDraftProvider()
            draftAPIProvider?[keyPath: keyPath] = newValue
        }
    }

    private func keyBinding(keyID: UUID, for keyPath: WritableKeyPath<APIProviderKey, String>) -> Binding<String> {
        Binding {
            keyValue(keyID: keyID, keyPath: keyPath)
        } set: { newValue in
            ensureDraftProvider()
            guard let index = draftAPIProvider?.keys.firstIndex(where: { $0.id == keyID }) else { return }
            draftAPIProvider?.keys[index][keyPath: keyPath] = newValue
        }
    }

    private func keyValue(keyID: UUID, keyPath: KeyPath<APIProviderKey, String>) -> String {
        draftAPIProvider?.keys.first { $0.id == keyID }?[keyPath: keyPath] ??
            apiProvider?.keys.first { $0.id == keyID }?[keyPath: keyPath] ??
            ""
    }

    private func openProviderWebsite() {
        guard let apiProvider,
              let url = providerWebsiteURL(for: apiProvider)
        else { return }

        NSWorkspace.shared.open(url)
    }

    private func providerWebsiteURL(for apiProvider: APIProvider) -> URL? {
        guard let trimmed = apiProvider.providerWebsiteURL.nilIfBlank else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false
        else { return nil }

        return url
    }

    private func selectRoutedProvider() {
        guard let apiProviderID,
              let apiProvider = manager.apiProviders.first(where: { $0.id == apiProviderID })
        else { return }

        manager.selectAPIProvider(apiProvider)
    }

    private func ensureDraftProvider() {
        guard draftAPIProvider == nil else { return }
        syncDraftProvider()
    }

    private func syncDraftProvider() {
        draftAPIProvider = apiProvider
    }

    private func commitDraftProvider() {
        guard let draftAPIProvider else { return }

        manager.updateAPIProvider(id: draftAPIProvider.id) { apiProvider in
            apiProvider.name = draftAPIProvider.name
            apiProvider.baseURL = draftAPIProvider.baseURL
            apiProvider.providerWebsiteURL = draftAPIProvider.providerWebsiteURL
            apiProvider.keys = draftAPIProvider.keys
        }
        syncDraftProvider()
    }

    private func toggleReveal(for keyID: UUID) {
        if revealKeyIDs.contains(keyID) {
            revealKeyIDs.remove(keyID)
        } else {
            revealKeyIDs.insert(keyID)
        }
    }
}

private enum APIProviderField: Hashable {
    case providerName
    case baseURL
    case providerWebsiteURL
    case keyName(UUID)
    case apiKey(UUID)
}
