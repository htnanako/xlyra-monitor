import AppKit

enum WindowFocusHelper {
    static func focusWindow(title: String) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            NSApplication.shared.windows
                .first { $0.title == title }
                .map { window in
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
        }
    }
}
