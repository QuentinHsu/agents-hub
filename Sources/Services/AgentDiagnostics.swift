import AppKit
import Foundation

struct AgentEndpointStatus: Equatable {
    enum State: Equatable {
        case idle
        case checking
        case healthy
        case failed(String)
        case timeout
        case notConfigured
    }

    var state: State = .idle
    var latencyMilliseconds: Int?
    var checkedAt: Date?

    var statusText: String {
        switch state {
        case .idle:
            LocalizationManager.localize("status.not_checked")
        case .checking:
            LocalizationManager.localize("status.checking")
        case .healthy:
            if let latencyMilliseconds {
                String(
                    format: LocalizationManager.localize("status.ok_with_latency"),
                    Int64(latencyMilliseconds)
                )
            } else {
                LocalizationManager.localize("status.ok")
            }
        case .failed(let message):
            message
        case .timeout:
            LocalizationManager.localize("status.timed_out")
        case .notConfigured:
            LocalizationManager.localize("status.not_configured")
        }
    }
}

struct LocalAppVersion: Equatable {
    let name: String
    let version: String?
    let path: String?

    var displayVersion: String {
        version ?? LocalizationManager.localize("ui.label.not_installed")
    }
}

struct LocalToolVersion: Equatable {
    let name: String
    let version: String?
    let detail: String?

    var displayVersion: String {
        version ?? LocalizationManager.localize("ui.label.not_found")
    }
}

enum AgentDiagnostics {
    static func checkEndpoint(for profile: APIProfile) async -> AgentEndpointStatus {
        let baseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AgentEndpointStatus(state: .notConfigured)
        }

        guard var components = URLComponents(string: baseURL), let host = components.host, !host.isEmpty else {
            return AgentEndpointStatus(state: .failed(LocalizationManager.localize("error.invalid_url")))
        }

        components.path = normalizedHealthPath(for: profile.provider, existingPath: components.path)
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            return AgentEndpointStatus(state: .failed(LocalizationManager.localize("error.invalid_url")))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6
        request.setValue("AgentsHub/0.1", forHTTPHeaderField: "User-Agent")
        applyHeaders(for: profile, request: &request)

        let startedAt = ContinuousClock.now

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = startedAt.duration(to: .now)
            let latency = Int(Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15)

            if let httpResponse = response as? HTTPURLResponse {
                if (200..<500).contains(httpResponse.statusCode) {
                    return AgentEndpointStatus(state: .healthy, latencyMilliseconds: latency, checkedAt: .now)
                }

                return AgentEndpointStatus(
                    state: .failed("HTTP \(httpResponse.statusCode)"),
                    latencyMilliseconds: latency,
                    checkedAt: .now
                )
            }

            return AgentEndpointStatus(state: .healthy, latencyMilliseconds: latency, checkedAt: .now)
        } catch {
            if error.isTimeout {
                return AgentEndpointStatus(state: .timeout, checkedAt: .now)
            }

            return AgentEndpointStatus(
                state: .failed(error.localizedDescription),
                checkedAt: .now
            )
        }
    }

    static func loadLocalToolVersions() async -> [LocalToolVersion] {
        await withTaskGroup(of: LocalToolVersion.self) { group in
            group.addTask {
                await toolVersion(
                    name: "Claude Code CLI",
                    executable: "claude",
                    arguments: ["--version"]
                )
            }
            group.addTask {
                await toolVersion(
                    name: "Codex CLI",
                    executable: "codex",
                    arguments: ["--version"]
                )
            }

            var versions: [LocalToolVersion] = []
            for await version in group {
                versions.append(version)
            }
            return versions.sorted { $0.name < $1.name }
        }
    }

    static func loadDesktopVersions() -> [LocalAppVersion] {
        [
            appVersion(name: "Claude Desktop", bundleIdentifiers: [
                "com.anthropic.claudefordesktop",
                "com.anthropic.claude"
            ], fallbackNames: [
                "Claude.app"
            ]),
            appVersion(name: "Codex Desktop", bundleIdentifiers: [
                "com.openai.codex",
                "com.openai.codex-desktop"
            ], fallbackNames: [
                "Codex.app"
            ])
        ]
    }

    private static func normalizedHealthPath(for provider: ProviderKind, existingPath: String) -> String {
        switch provider {
        case .claudeCode:
            return "/v1/models"
        case .codex:
            let trimmed = existingPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if trimmed.isEmpty {
                return "/v1/models"
            }
            if trimmed == "v1" {
                return "/v1/models"
            }
            return existingPath
        }
    }

    private static func applyHeaders(for profile: APIProfile, request: inout URLRequest) {
        switch profile.provider {
        case .claudeCode:
            request.setValue(profile.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .codex:
            request.setValue("Bearer \(profile.apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func toolVersion(
        name: String,
        executable: String,
        arguments: [String]
    ) async -> LocalToolVersion {
        let executableURL = await resolveExecutable(executable)
        guard let executableURL else {
            return LocalToolVersion(name: name, version: nil, detail: nil)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = output?.components(separatedBy: .newlines).first
            return LocalToolVersion(
                name: name,
                version: firstLine?.nilIfBlank,
                detail: executableURL.path()
            )
        } catch {
            return LocalToolVersion(name: name, version: nil, detail: error.localizedDescription)
        }
    }

    private static func resolveExecutable(_ executable: String) async -> URL? {
        let commonPaths = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)",
            "/bin/\(executable)"
        ]

        if let path = commonPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(filePath: path)
        }

        return await which(executable)
    }

    private static func which(_ executable: String) async -> URL? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["which", executable]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else { return nil }
            return URL(filePath: path)
        } catch {
            return nil
        }
    }

    private static func appVersion(
        name: String,
        bundleIdentifiers: [String],
        fallbackNames: [String]
    ) -> LocalAppVersion {
        let workspace = NSWorkspace.shared

        for bundleIdentifier in bundleIdentifiers {
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier),
               let version = bundleVersion(at: url)
            {
                return LocalAppVersion(name: name, version: version, path: url.path())
            }
        }

        let searchDirectories = [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]

        for directory in searchDirectories {
            for fallbackName in fallbackNames {
                let url = directory.appendingPathComponent(fallbackName, isDirectory: true)
                if FileManager.default.fileExists(atPath: url.path()),
                   let version = bundleVersion(at: url)
                {
                    return LocalAppVersion(name: name, version: version, path: url.path())
                }
            }
        }

        return LocalAppVersion(name: name, version: nil, path: nil)
    }

    private static func bundleVersion(at url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion?.nilIfBlank, buildVersion?.nilIfBlank) {
        case (.some(let shortVersion), .some(let buildVersion)) where shortVersion != buildVersion:
            return "\(shortVersion) (\(buildVersion))"
        case (.some(let shortVersion), _):
            return shortVersion
        case (_, .some(let buildVersion)):
            return buildVersion
        default:
            return nil
        }
    }
}

private extension Error {
    var isTimeout: Bool {
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
            return true
        }

        return (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == NSURLErrorTimedOut
    }
}
