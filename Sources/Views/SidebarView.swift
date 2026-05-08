import SwiftUI

enum SidebarSelection: Hashable {
    case overview
    case apiProviders
    case agent(ProviderKind)
    case settings
    case about
}

struct SidebarView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: sidebarSelection) {
            Section {
                L.label("ui.sidebar.overview", systemImage: "gauge.with.dots.needle.50percent", using: lm)
                    .tag(SidebarSelection.overview)
                L.label("ui.sidebar.api_providers", systemImage: "server.rack", using: lm)
                    .tag(SidebarSelection.apiProviders)
            }

            Section {
                ForEach(ProviderKind.allCases) { provider in
                    AgentSidebarRow(
                        provider: provider,
                        activeProfile: manager.activeProfile(for: provider)
                    )
                    .tag(SidebarSelection.agent(provider))
                }
            } header: {
                L.text("ui.label.agents", using: lm)
            }

            Section {
                L.label("ui.sidebar.settings", systemImage: "gearshape", using: lm)
                    .tag(SidebarSelection.settings)
                L.label("ui.sidebar.about", systemImage: "info.circle", using: lm)
                    .tag(SidebarSelection.about)
            }
        }
        .listStyle(.sidebar)
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding {
            selection
        } set: { selection in
            guard let selection else { return }
            self.selection = selection

            switch selection {
            case .overview, .apiProviders, .settings, .about:
                break
            case .agent(let provider):
                manager.selectedProvider = provider
            }
        }
    }
}

private struct AgentSidebarRow: View {
    @Environment(LocalizationManager.self) private var lm

    let provider: ProviderKind
    let activeProfile: APIProfile?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(provider.accentColor.opacity(0.14))
                AgentLogo(provider: provider, size: 18)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if let activeProfile {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)

                        Text(activeProfile.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(L.string("ui.label.no_current_configuration", using: lm))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
