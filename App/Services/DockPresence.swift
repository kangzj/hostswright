import AppKit

/// A menu bar app that only shows a Dock icon while one of its windows is open.
@MainActor
enum DockPresence {
    static func observeWindows() {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { notification in
            let closing = notification.object as? NSWindow
            MainActor.assumeIsolated {
                let remaining = NSApp.windows.filter { $0 !== closing && $0.isVisible && $0.styleMask.contains(.titled) }
                if remaining.isEmpty { NSApp.setActivationPolicy(.accessory) }
            }
        }
    }

    static func present(_ open: () -> Void) {
        NSApp.setActivationPolicy(.regular)
        open()
        NSApp.activate()
    }
}
