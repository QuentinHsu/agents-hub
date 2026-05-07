import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(LocalizationManager.self) private var lm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                generalSettings
                storageSettings
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(L.string("ui.settings.title", using: lm))
    }

    private var generalSettings: some View {
        SettingsSectionCard(title: L.string("ui.settings.general", using: lm)) {
            SettingsItemRow(
                title: L.string("ui.settings.language", using: lm)
            ) {
                Picker("", selection: Bindable(lm).currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
            }
        }
    }

    private var storageSettings: some View {
        SettingsSectionCard(title: L.string("ui.settings.storage", using: lm)) {
            SettingsItemRow(
                title: L.string("ui.settings.config_path", using: lm)
            ) {
                Button {
                    reveal(AppPaths.configDirectory)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(L.string("ui.action.reveal_in_finder", using: lm))
            }

            SettingsDivider()
                .padding(.leading, 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppPaths.configDirectory.path())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reveal(_ url: URL) {
        let directory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        NSWorkspace.shared.selectFile(url.path(), inFileViewerRootedAtPath: directory.deletingLastPathComponent().path())
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 7)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SettingsItemRow<Trailing: View>: View {
    let title: String
    let detail: String?
    let trailing: Trailing

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
