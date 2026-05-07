import AppKit
import SwiftUI

@main
struct AgentsHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var localizationManager = LocalizationManager()
    @State private var manager = ProfileManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
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
                        .applicationVersion: "0.1.0"
                    ])
                }
            }
        }
    }
}

private enum AppMetadata {
    static let displayName = "Agents Hub"
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
