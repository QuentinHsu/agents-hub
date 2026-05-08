import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    @State private var isShowingResetConfirmation = false

    var body: some View {
        SettingsPageContent(horizontalPadding: 22, verticalPadding: 18) {
            generalSettings
            storageSettings
        }
        .navigationTitle(L.string("ui.settings.title", using: lm))
        .confirmationDialog(
            L.string("ui.settings.reset_data", using: lm),
            isPresented: $isShowingResetConfirmation
        ) {
            Button(L.string("ui.settings.reset_data_confirm", using: lm), role: .destructive) {
                manager.resetState()
            }
            Button(L.string("ui.action.cancel", using: lm), role: .cancel) {}
        } message: {
            Text(L.string("ui.settings.reset_data_detail", using: lm))
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsItemRow(
                title: L.string("ui.settings.language", using: lm)
            ) {
                SettingsSelect(lm.currentLanguage.displayName, selection: Bindable(lm).currentLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }
        }
        .settingsCard(L.string("ui.settings.general", using: lm))
    }

    private var storageSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            SettingsDivider()
                .padding(.leading, 0)

            SettingsItemRow(
                title: L.string("ui.settings.reset_data", using: lm),
                detail: L.string("ui.settings.reset_data_detail", using: lm)
            ) {
                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(L.string("ui.settings.reset_data", using: lm))
            }
        }
        .settingsCard(L.string("ui.settings.storage", using: lm))
    }

    private func reveal(_ url: URL) {
        let directory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        NSWorkspace.shared.selectFile(url.path(), inFileViewerRootedAtPath: directory.deletingLastPathComponent().path())
    }
}
