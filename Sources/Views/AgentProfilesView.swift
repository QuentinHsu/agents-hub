import AppKit
import SwiftUI

struct AgentProfilesView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    let provider: ProviderKind
    @Binding var path: [DetailRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if provider == .claudeCode {
                    claudeSharedSettings
                }
                profilesList
                targetFiles
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(provider.displayName)
    }

    private var profilesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldTitle(
                    L.string("ui.agent_profiles.configurations", using: lm),
                    detail: L.string(
                        "ui.agent_profiles.saved_count",
                        Int64(manager.profiles(for: provider).count),
                        using: lm
                    )
                )
            }

            SettingsDivider()

            ForEach(manager.profiles(for: provider)) { profile in
                Button {
                    manager.selectProfile(profile)
                    path.append(.profile(profile.id))
                } label: {
                    profileRow(profile)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(L.string("ui.action.set_current", using: lm)) {
                        manager.selectProfile(profile)
                        manager.applySelectedProfile()
                    }
                    .disabled(!profile.isReady)

                    Button(L.string("ui.action.duplicate", using: lm)) {
                        manager.selectProfile(profile)
                        manager.duplicateSelectedProfile()
                    }

                    Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                        manager.selectProfile(profile)
                        manager.removeSelectedProfile()
                    }
                    .disabled(manager.profiles(for: provider).count <= 1)
                }

                if profile.id != manager.profiles(for: provider).last?.id {
                    SettingsDivider()
                }
            }
        }
        .settingsCard()
    }

    private var claudeSharedSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldTitle(
                    L.string("ui.profile.skip_claude_onboarding", using: lm),
                    detail: L.string("ui.profile.skip_claude_onboarding_detail", using: lm)
                )
            } trailing: {
                Toggle("", isOn: skipClaudeOnboardingBinding())
                    .labelsHidden()
            }
        }
        .settingsCard(L.string("ui.agent_profiles.shared_settings", using: lm))
    }

    private var targetFiles: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                FieldTitle(L.string("ui.profile.configuration_files", using: lm), detail: targetDescription)
            }

            SettingsDivider()

            ForEach(targetURLs, id: \.self) { url in
                SettingsRow {
                    Text(url.path())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } trailing: {
                    Button {
                        reveal(url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(L.string("ui.action.reveal_in_finder", using: lm))
                }
            }
        }
        .settingsCard(L.string("ui.profile.apply_target", using: lm))
    }

    private func profileRow(_ profile: APIProfile) -> some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(.subheadline.weight(.semibold))
                    if profile.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .help(L.string("ui.label.current", using: lm))
                    }
                }

                Text("\(profile.displayModel) · \(profile.redactedKey)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } trailing: {
            HStack(spacing: 12) {
                Text(profile.baseURL.nilIfBlank ?? L.string("ui.label.no_base_url", using: lm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 240, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var targetURLs: [URL] {
        switch provider {
        case .claudeCode:
            [AppPaths.claudeSettingsURL]
        case .codex:
            [AppPaths.codexConfigURL, AppPaths.codexAuthURL]
        }
    }

    private var targetDescription: String {
        switch provider {
        case .claudeCode:
            L.string("ui.profile.target_claude_detail", using: lm)
        case .codex:
            L.string("ui.profile.target_codex_detail", using: lm)
        }
    }

    private func skipClaudeOnboardingBinding() -> Binding<Bool> {
        Binding {
            manager.skipClaudeCodeOnboarding
        } set: { newValue in
            manager.updateSkipClaudeCodeOnboarding(newValue)
        }
    }

    private func reveal(_ url: URL) {
        let directory = url.deletingLastPathComponent()
        NSWorkspace.shared.selectFile(url.path(), inFileViewerRootedAtPath: directory.path())
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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
