import SwiftUI

struct APIProvidersView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    @Binding var path: [DetailRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                apiProviderList
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L.string("ui.api_providers.title", using: lm))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    manager.addAPIProvider()
                    if let apiProviderID = manager.selectedAPIProviderID {
                        path.append(.apiProvider(apiProviderID))
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help(L.string("ui.hint.add_api_provider", using: lm))
            }
        }
    }

    private var apiProviderList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(manager.sortedAPIProviders()) { apiProvider in
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
                        manager.selectAPIProvider(apiProvider)
                        manager.removeSelectedAPIProvider()
                    }
                    .disabled(manager.apiProviders.count <= 1)
                }

                if apiProvider.id != manager.sortedAPIProviders().last?.id {
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
                .disabled(providerWebsiteURL(for: apiProvider) == nil)
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
        guard let url = providerWebsiteURL(for: apiProvider) else { return }
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
}

private struct FieldTitle: View {
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
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
