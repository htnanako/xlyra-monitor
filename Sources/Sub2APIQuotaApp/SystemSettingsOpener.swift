import AppKit
import Foundation

protocol SystemSettingsOpening {
    func openNotificationSettings()
}

struct SystemSettingsOpener: SystemSettingsOpening {
    func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for urlString in urls {
            guard let url = URL(string: urlString) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
