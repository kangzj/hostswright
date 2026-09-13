import AppKit
import SwiftUI

@main
struct HostswrightApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Hostswright", id: MainWindow.id) {
            MainWindow()
                .environment(appDelegate.model)
        }
        .defaultSize(width: 800, height: 520)
        .defaultLaunchBehavior(appDelegate.model.opensWindowAtLaunch ? .presented : .suppressed)
        .restorationBehavior(.disabled)
        .commands { AppCommands(model: appDelegate.model) }

        MenuBarExtra {
            MenuBarMenu()
                .environment(appDelegate.model)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockPresence.observeWindows()
        if model.opensWindowAtLaunch {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshHelperStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveNow()
    }
}
