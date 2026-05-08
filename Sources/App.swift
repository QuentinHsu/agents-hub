import AppKit
import SwiftUI

@main
struct AgentsHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var localizationManager = LocalizationManager()
    @State private var manager = ProfileManager()
    @StateObject private var appUpdater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, appUpdater: appUpdater)
                .environment(localizationManager)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 540)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("\(L.string("ui.settings.about", using: localizationManager)) \(AppMetadata.displayName)") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: AppMetadata.displayName,
                        .applicationVersion: AppMetadata.versionDisplay
                    ])
                }
            }

            CommandGroup(after: .appInfo) {
                Button(L.string("ui.app.check_for_updates", using: localizationManager)) {
                    appUpdater.checkForUpdates()
                }
            }
        }
    }
}

private enum AppMetadata {
    static let displayName = "Agents Hub"

    static var versionDisplay: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String

        switch (version?.nilIfEmpty, build?.nilIfEmpty) {
        case let (.some(version), .some(build)) where build != version:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        case let (_, .some(build)):
            return build
        default:
            return "0.1.0"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.updateApplicationMenuTitle()
            await Task.yield()
            self?.updateApplicationMenuTitle()
        }
    }

    @MainActor
    private func updateApplicationMenuTitle() {
        NSApplication.shared.mainMenu?.items.first?.title = AppMetadata.displayName
    }
}
