import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(LocalizationManager.self) private var lm
    let appUpdater: AppUpdater

    var body: some View {
        SettingsPageContent(horizontalPadding: 22, verticalPadding: 18) {
            appHeader

            VStack(alignment: .leading, spacing: 0) {
                SettingsRow {
                    AboutRowTitle(L.string("ui.settings.version", using: lm))
                } trailing: {
                    Text(AppInfo.versionDisplay)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                SettingsDivider()

                SettingsRow {
                    AboutRowTitle(L.string("ui.settings.source_repository", using: lm))
                } trailing: {
                    Link(
                        AppInfo.sourceRepository.absoluteString,
                        destination: AppInfo.sourceRepository
                    )
                    .font(.caption)
                }

                SettingsDivider()

                SettingsRow {
                    AboutRowTitle(L.string("ui.app.updates", using: lm))
                } trailing: {
                    Button {
                        appUpdater.checkForUpdates()
                    } label: {
                        Label(L.string("ui.app.check_for_updates", using: lm), systemImage: "arrow.down.circle")
                    }
                    .font(.caption)
                    .controlSize(.small)
                }
            }
            .settingsCard()
        }
        .navigationTitle(L.string("ui.settings.about", using: lm))
    }

    private var appHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: AppInfo.appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppInfo.displayName)
                    .font(.subheadline.weight(.semibold))

                L.text("ui.settings.about_subtitle", using: lm)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCard()
    }
}

private struct AboutRowTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
    }
}
