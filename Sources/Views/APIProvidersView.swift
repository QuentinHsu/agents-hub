import SwiftUI

struct APIProvidersView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    @Binding var path: [DetailRoute]
    @State private var apiProviderPendingDelete: APIProvider?

    var body: some View {
        SettingsPageContent {
            apiProviderList
        }
        .navigationTitle(L.string("ui.api_providers.title", using: lm))
        .confirmationDialog(
            L.string("ui.confirm.delete_api_provider", using: lm),
            isPresented: deleteConfirmationBinding(for: $apiProviderPendingDelete)
        ) {
            Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                if let apiProviderPendingDelete {
                    manager.selectAPIProvider(apiProviderPendingDelete)
                    manager.removeSelectedAPIProvider()
                    path.removeAll()
                    self.apiProviderPendingDelete = nil
                }
            }
            Button(L.string("ui.action.cancel", using: lm), role: .cancel) {
                apiProviderPendingDelete = nil
            }
        } message: {
            Text(L.string("ui.confirm.delete_api_provider_detail", using: lm))
        }
    }

    private var apiProviderList: some View {
        let providers = manager.sortedAPIProviders()
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(providers) { apiProvider in
                Button {
                    manager.selectAPIProvider(apiProvider)
                    path.append(.apiProvider(apiProvider.id))
                } label: {
                    apiProviderRow(apiProvider)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(L.string("ui.action.duplicate", using: lm)) {
                        manager.selectAPIProvider(apiProvider)
                        manager.duplicateSelectedAPIProvider()
                    }

                    Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                        apiProviderPendingDelete = apiProvider
                    }
                    .disabled(manager.apiProviders.count <= 1)
                }

                if apiProvider.id != providers.last?.id {
                    SettingsDivider()
                }
            }
        }
        .settingsCard()
    }

    private func apiProviderRow(_ apiProvider: APIProvider) -> some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(apiProvider.name)
                        .font(.subheadline.weight(.semibold))

                    if apiProvider.isReady {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .help(L.string("ui.label.ready", using: lm))
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                            .help(L.string("ui.label.incomplete", using: lm))
                    }
                }

                Text(providerDetailText(apiProvider))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } trailing: {
            HStack(spacing: 12) {
                Button {
                    openProviderWebsite(apiProvider)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .disabled(apiProvider.websiteURL == nil)
                .help(L.string("ui.hint.open_provider_website", using: lm))

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func providerDetailText(_ apiProvider: APIProvider) -> String {
        let baseURL = apiProvider.baseURL.nilIfBlank ?? L.string("ui.label.no_base_url", using: lm)
        let keyNames = apiProvider.keys.map { $0.name }.joined(separator: ", ")
        let keysDisplay = keyNames.isEmpty ? L.string("ui.label.no_key", using: lm) : keyNames

        return "\(baseURL) · \(keysDisplay)"
    }

    private func openProviderWebsite(_ apiProvider: APIProvider) {
        guard let url = apiProvider.websiteURL else { return }
        NSWorkspace.shared.open(url)
    }
}
