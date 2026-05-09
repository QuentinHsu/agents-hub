import AppKit
import SwiftUI

enum DetailRoute: Hashable {
    case profile(UUID)
    case apiProvider(UUID)
}

struct ContentView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var manager: ProfileManager
    let appUpdater: AppUpdater
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var sidebarSelection: SidebarSelection? = .overview
    @State private var detailPath: [DetailRoute] = []
    @State private var overviewRefreshTrigger = 0
    @State private var visibleFeedback: AppFeedback?
    @State private var feedbackDismissTask: Task<Void, Never>?
    @State private var profilePendingDelete: APIProfile?
    @State private var apiProviderPendingDelete: APIProvider?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(manager: manager, selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            NavigationStack(path: $detailPath) {
                detailRoot
                    .id(sidebarSelection)
                    .navigationDestination(for: DetailRoute.self) { route in
                        switch route {
                        case .profile(let id):
                            ProfileDetailView(manager: manager, profileID: id)
                        case .apiProvider(let id):
                            APIProviderDetailView(manager: manager, apiProviderID: id)
                        }
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let visibleFeedback {
                FeedbackToast(feedback: visibleFeedback)
                    .padding(.bottom, 16)
                    .padding(.trailing, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: visibleFeedback)
        .onChange(of: sidebarSelection) { _, selection in
            switch selection {
            case .overview, .apiProviders, .settings, .about, .none:
                detailPath.removeAll()
            case .agent(let provider):
                manager.selectedProvider = provider
                detailPath.removeAll()
            }
        }
        .onChange(of: manager.feedbackRevision) { _, _ in
            showLatestFeedback()
        }
        .toolbar {
            if isOverview {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        overviewRefreshTrigger += 1
                    } label: {
                        L.label("ui.action.refresh", systemImage: "arrow.clockwise", using: lm)
                    }
                    .help(L.string("ui.hint.refresh_dashboard", using: lm))
                }
            }

            if isShowingAgentList {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        manager.addProfile(for: currentProvider)
                        if let profileID = manager.selectedProfileIDs[manager.selectedProvider] {
                            detailPath = [.profile(profileID)]
                        }
                    } label: {
                        L.label("ui.action.add_configuration", systemImage: "plus", using: lm)
                    }
                    .help(L.string("ui.hint.add_configuration_selected_agent", using: lm))
                }
            }

            if isShowingAPIProviderList {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        manager.addAPIProvider()
                        if let apiProviderID = manager.selectedAPIProviderID {
                            detailPath = [.apiProvider(apiProviderID)]
                        }
                    } label: {
                        L.label("ui.action.add_api_provider", systemImage: "plus", using: lm)
                    }
                    .help(L.string("ui.hint.add_api_provider", using: lm))
                }
            }

            if isEditingProfile {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        manager.duplicateSelectedProfile()
                        if let profileID = manager.selectedProfileIDs[manager.selectedProvider] {
                            detailPath = [.profile(profileID)]
                        }
                    } label: {
                        L.label("ui.action.duplicate", systemImage: "doc.on.doc", using: lm)
                    }
                    .help(L.string("ui.hint.duplicate_configuration", using: lm))

                    Button(role: .destructive) {
                        profilePendingDelete = manager.selectedProfile
                    } label: {
                        L.label("ui.action.delete", systemImage: "trash", using: lm)
                            .foregroundStyle(.red)
                    }
                    .disabled(manager.profiles(for: manager.selectedProvider).count <= 1)
                    .help(L.string("ui.hint.delete_configuration", using: lm))

                    Button {
                        manager.applySelectedProfile()
                    } label: {
                        if isSelectedProfileActive {
                            L.label("ui.action.set_current", systemImage: "checkmark.circle", using: lm)
                                .foregroundStyle(.green)
                        } else {
                            L.label("ui.action.set_current", systemImage: "checkmark.circle", using: lm)
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(manager.selectedProfile.map { manager.isProfileReady($0) } != true)
                    .help(L.string("ui.hint.set_current_configuration", using: lm))
                }
            }

            if isEditingAPIProvider {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        manager.duplicateSelectedAPIProvider()
                        if let apiProviderID = manager.selectedAPIProviderID {
                            detailPath = [.apiProvider(apiProviderID)]
                        }
                    } label: {
                        L.label("ui.action.duplicate", systemImage: "doc.on.doc", using: lm)
                    }
                    .help(L.string("ui.hint.duplicate_api_provider", using: lm))

                    Button(role: .destructive) {
                        apiProviderPendingDelete = manager.selectedAPIProvider()
                    } label: {
                        L.label("ui.action.delete", systemImage: "trash", using: lm)
                            .foregroundStyle(.red)
                    }
                    .disabled(manager.apiProviders.count <= 1)
                    .help(L.string("ui.hint.delete_api_provider", using: lm))
                }
            }
        }
        .confirmationDialog(
            L.string("ui.confirm.delete_configuration", using: lm),
            isPresented: profileDeleteConfirmationBinding
        ) {
            Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                if let profilePendingDelete {
                    manager.selectProfile(profilePendingDelete)
                    manager.removeSelectedProfile()
                    detailPath.removeAll()
                    self.profilePendingDelete = nil
                }
            }
            Button(L.string("ui.action.cancel", using: lm), role: .cancel) {
                profilePendingDelete = nil
            }
        } message: {
            Text(L.string("ui.confirm.delete_configuration_detail", using: lm))
        }
        .confirmationDialog(
            L.string("ui.confirm.delete_api_provider", using: lm),
            isPresented: apiProviderDeleteConfirmationBinding
        ) {
            Button(L.string("ui.action.delete", using: lm), role: .destructive) {
                if let apiProviderPendingDelete {
                    manager.selectAPIProvider(apiProviderPendingDelete)
                    manager.removeSelectedAPIProvider()
                    detailPath.removeAll()
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

    @ViewBuilder
    private var detailRoot: some View {
        switch sidebarSelection {
        case .apiProviders:
            APIProvidersView(manager: manager, path: $detailPath)
        case .agent(let provider):
            AgentProfilesView(manager: manager, provider: provider, path: $detailPath)
        case .settings:
            SettingsView(manager: manager)
        case .about:
            AboutView(appUpdater: appUpdater)
        case .overview, .none:
            HomeDashboardView(
                manager: manager,
                sidebarSelection: $sidebarSelection,
                refreshTrigger: overviewRefreshTrigger
            )
        }
    }

    private var currentProvider: ProviderKind? {
        switch sidebarSelection {
        case .agent(let provider):
            provider
        case .overview, .apiProviders, .settings, .about, .none:
            nil
        }
    }

    private var isEditingProfile: Bool {
        if case .profile = detailPath.last {
            return true
        }

        return false
    }

    private var isEditingAPIProvider: Bool {
        if case .apiProvider = detailPath.last {
            return true
        }

        return false
    }

    private var isOverview: Bool {
        switch sidebarSelection {
        case .overview, .none:
            true
        case .apiProviders, .agent, .settings, .about:
            false
        }
    }

    private var isShowingAgentList: Bool {
        currentProvider != nil && detailPath.isEmpty
    }

    private var isShowingAPIProviderList: Bool {
        sidebarSelection == .apiProviders && detailPath.isEmpty
    }

    private var isSelectedProfileActive: Bool {
        manager.selectedProfile?.isActive == true
    }

    private var profileDeleteConfirmationBinding: Binding<Bool> {
        Binding {
            profilePendingDelete != nil
        } set: { isPresented in
            if !isPresented {
                profilePendingDelete = nil
            }
        }
    }

    private var apiProviderDeleteConfirmationBinding: Binding<Bool> {
        Binding {
            apiProviderPendingDelete != nil
        } set: { isPresented in
            if !isPresented {
                apiProviderPendingDelete = nil
            }
        }
    }

    private func showLatestFeedback() {
        guard let feedback = AppFeedback(status: manager.statusMessage, error: manager.errorMessage) else {
            return
        }

        feedbackDismissTask?.cancel()
        visibleFeedback = feedback
        feedbackDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                visibleFeedback = nil
            }
        }
    }
}

private struct AppFeedback: Equatable {
    let message: String
    let style: Style

    init?(status: String?, error: String?) {
        if let error {
            self.message = error
            self.style = .error
        } else if let status {
            self.message = status
            self.style = .success
        } else {
            return nil
        }
    }

    enum Style: Equatable {
        case success
        case error

        var iconName: String {
            switch self {
            case .success:
                "checkmark.circle.fill"
            case .error:
                "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success:
                .green
            case .error:
                .red
            }
        }
    }
}

private struct FeedbackToast: View {
    let feedback: AppFeedback

    var body: some View {
        Label {
            Text(feedback.message)
                .font(.caption.weight(.medium))
                .lineLimit(2)
        } icon: {
            Image(systemName: feedback.style.iconName)
                .foregroundStyle(feedback.style.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 280, alignment: .leading)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.13), radius: 16, y: 8)
        .allowsHitTesting(false)
    }
}
