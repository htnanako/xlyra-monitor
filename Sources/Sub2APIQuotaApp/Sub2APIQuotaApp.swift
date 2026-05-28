import SwiftUI
import Sub2APIQuotaCore

public enum Sub2APIQuotaAppMetadata {
    static let menuBarTitle = "xLyra"
    static let menuBarLabel = "xLyra 监控"
    static let systemImageName = "gauge.with.dots.needle.67percent"
    static let appIconName = "Sub2APIQuotaIcon"
}

@main
struct Sub2APIQuotaApp: App {
    @StateObject private var container = XlyraAppContainer()

    var body: some Scene {
        MenuBarExtra {
            XlyraStatusMenuView(
                state: container.state,
                preferences: container.appPreferences,
                monitorPreferences: container.monitorPreferences,
                monitor: container.monitor
            )
        } label: {
            ThemedSceneContent(preferences: container.appPreferences) {
                XlyraMenuBarLabel(state: container.state, preferences: container.appPreferences)
            }
        }
        .menuBarExtraStyle(.window)

        Window("xLyra 监控设置", id: "xlyra-settings") {
            ThemedSceneContent(preferences: container.appPreferences) {
                XlyraSettingsWindowView(
                    preferences: container.appPreferences,
                    monitorPreferences: container.monitorPreferences,
                    monitor: container.monitor,
                    loginItem: container.loginItem
                )
            }
        }
        .defaultSize(width: 460, height: 360)
    }
}
