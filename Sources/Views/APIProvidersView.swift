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
    }

    private var apiProviderList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldTitle(
                    L.string("ui.api_providers.title", using: lm),
                    detail: L.string(
                        "ui.api_providers.saved_count",
                        Int64(manager.apiProviders.count),
                        using: lm
                    )
                )
            } trailing: {
                Button {
                    manager.addAPIProvider()
                    if let apiProviderID = manager.selectedAPIProviderID {
                        path.append(.apiProvider(apiProviderID))
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(L.string("ui.hint.add_api_provider", using: lm))
            }

            SettingsDivider()

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
                Text(apiProvider.name)
                    .font(.subheadline.weight(.semibold))

                Text(keySummary(for: apiProvider))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } trailing: {
            HStack(spacing: 12) {
                Text(apiProvider.baseURL.nilIfBlank ?? L.string("ui.label.no_base_url", using: lm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func keySummary(for apiProvider: APIProvider) -> String {
        L.string("ui.api_provider.keys_count", Int64(apiProvider.keys.count), using: lm)
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
