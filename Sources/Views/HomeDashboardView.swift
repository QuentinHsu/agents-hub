import AppKit
import SwiftUI

struct HomeDashboardView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    @Binding var sidebarSelection: SidebarSelection?
    let refreshTrigger: Int

    @State private var endpointStatuses: [ProviderKind: AgentEndpointStatus] = [:]
    @State private var toolVersions: [LocalToolVersion] = []
    @State private var desktopVersions: [LocalAppVersion] = []
    @State private var isCheckingEndpoints = false
    @State private var isLoadingVersions = false

    var body: some View {
        SettingsPageContent {
            agentConfigurations
            localVersions
        }
        .task {
            await refreshAll()
        }
        .onChange(of: refreshTrigger) {
            Task {
                await refreshAll()
            }
        }
    }

    private var agentConfigurations: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ProviderKind.allCases) { provider in
                Button {
                    manager.selectedProvider = provider
                    sidebarSelection = .agent(provider)
                } label: {
                    agentStatusRow(for: provider)
                }
                .buttonStyle(.plain)

                if provider != ProviderKind.allCases.last {
                    SettingsDivider()
                }
            }
        }
        .settingsCard(L.string("ui.dashboard.agent_status", using: lm))
    }

    private var localVersions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(toolVersions, id: \.name) { tool in
                versionRow(
                    title: tool.name,
                    version: tool.displayVersion,
                    detail: tool.detail,
                    missing: tool.version == nil
                )
                SettingsDivider()
            }

            ForEach(Array(desktopVersions.enumerated()), id: \.element.name) { index, app in
                versionRow(
                    title: app.name,
                    version: app.displayVersion,
                    detail: app.path,
                    missing: app.version == nil
                )

                if index != desktopVersions.indices.last {
                    SettingsDivider()
                }
            }
        }
        .settingsCard(L.string("ui.dashboard.local_versions", using: lm))
    }

    private func agentStatusRow(for provider: ProviderKind) -> some View {
        let profile = manager.activeProfile(for: provider)
        let status = endpointStatuses[provider] ?? AgentEndpointStatus()

        return SettingsRow {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(provider.accentColor.opacity(0.14))
                    AgentLogo(provider: provider, size: 20)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(provider.displayName)
                            .font(.subheadline.weight(.semibold))
                        statusBadge(for: status)
                    }

                    Text(profileSummary(profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } trailing: {
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(status.localizedStatusText(using: lm))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(statusColor(for: status))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func versionRow(
        title: String,
        version: String,
        detail: String?,
        missing: Bool
    ) -> some View {
        SettingsRow {
            FieldLabel(
                title,
                detail: detail ?? L.string("ui.label.no_local_installation", using: lm),
                detailLineLimit: 1
            )
        } trailing: {
            Text(version)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(missing ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .trailing)
        }
    }

    private func statusBadge(for status: AgentEndpointStatus) -> some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 7, height: 7)
    }

    private func statusColor(for status: AgentEndpointStatus) -> Color {
        switch status.state {
        case .healthy:
            .green
        case .checking:
            .blue
        case .failed, .timeout:
            .red
        case .notConfigured:
            .orange
        case .idle:
            .secondary
        }
    }

    private func profileSummary(_ profile: APIProfile?) -> String {
        guard let profile else {
            return L.string("ui.label.no_current_configuration", using: lm)
        }

        let resolvedProfile = manager.resolvedProfile(profile)
        return "\(profile.name) · \(resolvedProfile.displayModel)"
    }

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await refreshEndpoints()
            }
            group.addTask {
                await refreshVersions()
            }
        }
    }

    private func refreshEndpoints() async {
        isCheckingEndpoints = true
        defer { isCheckingEndpoints = false }

        for provider in ProviderKind.allCases {
            endpointStatuses[provider] = AgentEndpointStatus(state: .checking)
        }

        await withTaskGroup(of: (ProviderKind, AgentEndpointStatus).self) { group in
            for provider in ProviderKind.allCases {
                let profile = manager.activeProfile(for: provider)
                group.addTask {
                    guard let profile else {
                        return (provider, AgentEndpointStatus(state: .notConfigured))
                    }

                    return (provider, await AgentDiagnostics.checkEndpoint(for: profile))
                }
            }

            for await (provider, status) in group {
                endpointStatuses[provider] = status
            }
        }
    }

    private func refreshVersions() async {
        isLoadingVersions = true
        defer { isLoadingVersions = false }

        async let tools = AgentDiagnostics.loadLocalToolVersions()
        let apps = AgentDiagnostics.loadDesktopVersions()

        toolVersions = await tools
        desktopVersions = apps
    }
}

private extension AgentEndpointStatus {
    @MainActor
    func localizedStatusText(using lm: LocalizationManager) -> String {
        switch state {
        case .idle:
            L.string("status.not_checked", using: lm)
        case .checking:
            L.string("status.checking", using: lm)
        case .healthy:
            if let latencyMilliseconds {
                L.string("status.ok_with_latency", Int64(latencyMilliseconds), using: lm)
            } else {
                L.string("status.ok", using: lm)
            }
        case .failed(let message):
            message
        case .timeout:
            L.string("status.timed_out", using: lm)
        case .notConfigured:
            L.string("status.not_configured", using: lm)
        }
    }
}
