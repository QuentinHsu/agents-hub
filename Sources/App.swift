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
                Button("\(L.string("ui.settings.about", using: localizationManager)) \(AppInfo.displayName)") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: AppInfo.displayName,
                        .applicationVersion: AppInfo.versionDisplay,
                        .version: ""
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
        NSApplication.shared.mainMenu?.items.first?.title = AppInfo.displayName
    }
}
