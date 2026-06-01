import SwiftUI

public enum XlyraMonitorAppMetadata {
    static let menuBarTitle = "xLyra"
    static let menuBarLabel = "xLyra 监控"
    static let systemImageName = "gauge.with.dots.needle.67percent"
    static let appIconName = "XlyraMonitorIcon"
    static let fallbackVersion = "0.1.10"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }
}

@main
struct XlyraMonitorApp: App {
    @StateObject private var container = XlyraAppContainer()

    var body: some Scene {
        MenuBarExtra {
            ThemedSceneContent(preferences: container.appPreferences) {
                XlyraStatusMenuView(
                    state: container.state,
                    preferences: container.appPreferences,
                    monitorPreferences: container.monitorPreferences,
                    monitor: container.monitor,
                    updateCoordinator: container.updateCoordinator
                )
            }
        } label: {
            XlyraMenuBarLabel(state: container.state)
        }
        .menuBarExtraStyle(.window)

        Window("xLyra 监控设置", id: "xlyra-settings") {
            ThemedSceneContent(preferences: container.appPreferences) {
                XlyraSettingsWindowView(
                    preferences: container.appPreferences,
                    monitorPreferences: container.monitorPreferences,
                    monitor: container.monitor,
                    loginItem: container.loginItem,
                    updateCoordinator: container.updateCoordinator
                )
            }
        }
        .defaultSize(width: 460, height: 440)

        Window("导入 OAuth 账号", id: "xlyra-oauth-import") {
            ThemedSceneContent(preferences: container.appPreferences) {
                XlyraOAuthImportWindowView(preferences: container.appPreferences, monitor: container.monitor)
            }
        }
        .defaultSize(width: 520, height: 320)
    }
}
