import SwiftUI

struct AgentSessionsView: View {
    @Environment(LocalizationManager.self) private var lm
    @Bindable var sessionManager: SessionManager
    let provider: ProviderKind

    var body: some View {
        if sessionManager.isLoading {
            sessionsLoading
        } else if sessionManager.sessions.isEmpty {
            sessionsEmpty
        } else {
            groupedSessionsList
        }
    }

    // MARK: - Loading

    private var sessionsLoading: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L.string("ui.sessions.loading", using: lm))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingsCard(L.string("ui.sessions.title", using: lm))
    }

    // MARK: - Empty

    private var sessionsEmpty: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow {
                Text(L.string("ui.sessions.empty", using: lm))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsCard(L.string("ui.sessions.title", using: lm))
    }

    // MARK: - Grouped List

    struct ProjectGroup: Identifiable {
        let id: String
        let projectPath: String
        let displayName: String
        let displayPath: String?
        var sessions: [CLISession]
        let latestDate: Date?
    }

    private var projectGroups: [ProjectGroup] {
        let grouped = Dictionary(grouping: sessionManager.sessions) { session in
            session.projectPath.isEmpty ? "" : session.projectPath
        }

        let all = grouped.map { key, sessions in
            let sorted = sessions.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            let displayName: String
            let displayPath: String?
            if key.isEmpty {
                displayName = L.string("ui.sessions.unknown_project", using: lm)
                displayPath = nil
            } else {
                displayName = projectName(for: key)
                displayPath = abbreviateHome(key)
            }
            return ProjectGroup(
                id: key.isEmpty ? "__unknown__" : key,
                projectPath: key,
                displayName: displayName,
                displayPath: displayPath,
                sessions: sorted,
                latestDate: sorted.first?.updatedAt
            )
        }
        .sorted { ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast) }

        // Known projects first (sorted by date), unknown project last
        var known = all.filter { !$0.projectPath.isEmpty }
        let unknown = all.filter { $0.projectPath.isEmpty }
        known.append(contentsOf: unknown)
        return known
    }

    private var groupedSessionsList: some View {
        let groups = projectGroups
        let totalCount = sessionManager.sessions.count
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                ProjectGroupSection(
                    group: group,
                    sessionManager: sessionManager,
                    lm: lm
                )
                .id(group.id)
                if group.id != groups.last?.id {
                    SettingsDivider()
                }
            }
        }
        .settingsCard(
            L.string("ui.sessions.title", using: lm),
            subtitle: String(format: L.string("ui.sessions.count", using: lm), totalCount)
        )
    }

    // MARK: - Helpers

    private func abbreviateHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func projectName(for path: String) -> String {
        path.components(separatedBy: "/").last { !$0.isEmpty } ?? path
    }
}

// MARK: - Project Group Section

private struct ProjectGroupSection: View {
    let group: AgentSessionsView.ProjectGroup
    let sessionManager: SessionManager
    let lm: LocalizationManager
    @State private var isExpanded = false
    @State private var sessionPendingDelete: CLISession?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — entire row is tappable
            Button {
                isExpanded.toggle()
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(group.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if let displayPath = group.displayPath {
                            Text(displayPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Text("\(group.sessions.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Sessions
            if isExpanded {
                ForEach(group.sessions) { session in
                    SettingsDivider()
                    sessionRow(session)
                }
            }
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: CLISession) -> some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let metadata = sessionMetadata(session) {
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } trailing: {
            HStack(spacing: 2) {
                Button {
                    sessionManager.copyResumeCommand(for: session)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L.string("ui.sessions.copy_resume_command", using: lm))

                Button(role: .destructive) {
                    sessionPendingDelete = session
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L.string("ui.sessions.delete", using: lm))
            }
        }
        .contextMenu {
            Button(L.string("ui.sessions.copy_resume_command", using: lm)) {
                sessionManager.copyResumeCommand(for: session)
            }

            Divider()

            Button(L.string("ui.sessions.delete", using: lm), role: .destructive) {
                sessionPendingDelete = session
            }
        }
        .confirmationDialog(
            L.string("ui.sessions.delete_confirmation", using: lm),
            isPresented: deleteConfirmationBinding
        ) {
            Button(L.string("ui.sessions.delete", using: lm), role: .destructive) {
                if let sessionPendingDelete {
                    sessionManager.deleteSession(sessionPendingDelete)
                    self.sessionPendingDelete = nil
                }
            }
            Button(L.string("ui.action.cancel", using: lm), role: .cancel) {
                sessionPendingDelete = nil
            }
        } message: {
            Text(L.string("ui.sessions.delete_confirmation_detail", using: lm))
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            sessionPendingDelete != nil
        } set: { isPresented in
            if !isPresented {
                sessionPendingDelete = nil
            }
        }
    }

    private func sessionMetadata(_ session: CLISession) -> String? {
        var parts: [String] = []

        if let date = session.updatedAt {
            parts.append(date.formatted(.relative(presentation: .numeric)))
        }

        if let branch = session.gitBranch?.nilIfBlank {
            parts.append(branch)
        }

        if let fileSize = session.displayFileSize {
            parts.append(fileSize)
        }

        if parts.isEmpty, session.messageCount > 0 {
            parts.append(String(format: L.string("ui.sessions.message_count", using: lm), session.messageCount))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
