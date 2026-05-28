import Foundation
import Testing
@testable import Sub2APIQuotaApp

@Suite("AppPreferencesTests")
@MainActor
struct AppPreferencesTests {
    @Test
    func defaultImportDirectoryIsDownloads() {
        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

        #expect(preferences.importDirectoryPath.hasSuffix("/Downloads"))
    }

    @Test
    func savesCustomImportDirectory() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.updateImportDirectoryPath("/tmp/imports")

        let reloaded = AppPreferences(userDefaults: defaults)
        #expect(reloaded.importDirectoryPath == "/tmp/imports")
    }

    @Test
    func savesThemeMode() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.update(refreshIntervalSeconds: 60, showsMenuBarNumbers: true, themeMode: .dark)

        let reloaded = AppPreferences(userDefaults: defaults)
        #expect(reloaded.themeMode == .dark)
        #expect(reloaded.refreshIntervalSeconds == 60)
        #expect(reloaded.showsMenuBarNumbers)
    }

    @Test
    func updatesThemeModeIndependently() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.updateThemeMode(.dark)

        let reloaded = AppPreferences(userDefaults: defaults)
        #expect(preferences.themeMode == .dark)
        #expect(reloaded.themeMode == .dark)
        #expect(reloaded.refreshIntervalSeconds == 30)
        #expect(reloaded.showsMenuBarNumbers == false)
    }
}
