import Foundation
import XCTest
@testable import XlyraMonitorApp

@MainActor
final class AppPreferencesTests: XCTestCase {
    func testDefaultImportDirectoryIsDownloads() {
        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

        XCTAssert(preferences.importDirectoryPath.hasSuffix("/Downloads"))
    }

    func testSavesCustomImportDirectory() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.updateImportDirectoryPath("/tmp/imports")

        let reloaded = AppPreferences(userDefaults: defaults)
        XCTAssert(reloaded.importDirectoryPath == "/tmp/imports")
    }

    func testSavesThemeMode() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.update(
            refreshIntervalSeconds: 60,
            oauthRefreshIntervalSeconds: 120,
            showsMenuBarNumbers: true,
            themeMode: .dark
        )

        let reloaded = AppPreferences(userDefaults: defaults)
        XCTAssert(reloaded.themeMode == .dark)
        XCTAssert(reloaded.refreshIntervalSeconds == 60)
        XCTAssert(reloaded.oauthRefreshIntervalSeconds == 120)
        XCTAssert(reloaded.showsMenuBarNumbers)
    }

    func testUpdatesThemeModeIndependently() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = AppPreferences(userDefaults: defaults)

        preferences.updateThemeMode(.dark)

        let reloaded = AppPreferences(userDefaults: defaults)
        XCTAssert(preferences.themeMode == .dark)
        XCTAssert(reloaded.themeMode == .dark)
        XCTAssert(reloaded.refreshIntervalSeconds == 30)
        XCTAssert(reloaded.oauthRefreshIntervalSeconds == 300)
        XCTAssert(reloaded.showsMenuBarNumbers == false)
    }
}
