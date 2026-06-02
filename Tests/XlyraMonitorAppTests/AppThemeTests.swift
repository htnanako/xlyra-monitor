import AppKit
import SwiftUI
import XCTest
@testable import XlyraMonitorApp

final class AppThemeTests: XCTestCase {
    func testAutomaticThemeUsesEffectiveAppearanceWhenAvailable() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ))
        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ) == false)
    }

    func testAutomaticThemePrefersSystemInterfaceStyle() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!

        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        ))
        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ))
    }

    func testAutomaticThemeResolvesConcreteSceneColors() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!

        XCTAssert(AppThemeMode.automatic.resolvedColorScheme(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        ) == .dark)
        XCTAssert(AppThemeMode.automatic.resolvedNSAppearance(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        )?.name == .darkAqua)
        XCTAssert(AppThemeMode.automatic.resolvedColorScheme(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ) == .light)
        XCTAssert(AppThemeMode.automatic.resolvedNSAppearance(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        )?.name == .darkAqua)
    }

    func testExplicitThemeModesIgnoreEffectiveAppearance() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        XCTAssert(AppThemeMode.light.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: darkAppearance
        ) == false)
        XCTAssert(AppThemeMode.dark.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ))
    }

    func testAutomaticThemeFallsBackToSwiftUIColorScheme() {
        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: nil
        ))
        XCTAssert(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: nil
        ) == false)
    }

    func testMenuThemeUsesEffectiveAppearanceForAutomaticMode() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        XCTAssert(MenuTheme(
            mode: .automatic,
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ).isDark)
        XCTAssert(MenuTheme(
            mode: .automatic,
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ).isDark == false)
    }

    func testMenuBarPaletteUsesReadableTextForMenuBarBackground() {
        XCTAssert(Self.redComponent(of: MenuBarPalette(isDarkBackground: false).text) < 0.05)
        XCTAssert(Self.redComponent(of: MenuBarPalette(isDarkBackground: true).text) > 0.90)
    }

    @MainActor
    func testMenuBarLabelRenderingKeepsSemanticStatusColors() {
        let state = XlyraMonitorState()
        let fallbackImage = XlyraMenuBarImageRenderer.image(
            state: state,
            palette: MenuBarPalette(isDarkBackground: false)
        )

        XCTAssert(fallbackImage.isTemplate == false)

        state.applySuccess(XlyraSnapshot(
            generatedAt: "2026-06-01T08:00:00.000Z",
            sites: XlyraSiteSummary(total: 1, healthy: 1, rows: []),
            oauth: XlyraOAuthSummary(total: 2, healthy: 2, limited: 0, rows: [
                Self.oauthRow(id: "oauth-1", fiveHourUsedPercent: 20, weeklyUsedPercent: 85),
                Self.oauthRow(id: "oauth-2", fiveHourUsedPercent: 60, weeklyUsedPercent: 95)
            ]),
            apiKeys: XlyraAPIKeySummary(total: 1, active: 1, exhausted: 0, rows: []),
            requests: XlyraRequestSummary(
                total: 100,
                lastHour: 10,
                last24h: 100,
                ok24h: 100,
                failed24h: 0,
                avgLatency24h: nil
            ),
            usage: XlyraUsageSummary(tokens24h: 0, cost24h: 0),
            errors: [],
            cooldowns: XlyraCooldownSummary(active: 0)
        ))

        let connectedImage = XlyraMenuBarImageRenderer.image(
            state: state,
            palette: MenuBarPalette(isDarkBackground: false)
        )

        XCTAssert(connectedImage.isTemplate == false)
        Self.assertImageContainsSemanticColor(connectedImage, minimumX: 30)
    }

    private static func assertImageContainsSemanticColor(
        _ image: NSImage,
        minimumX: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            XCTFail("Expected a bitmap-backed semantic menu bar image", file: file, line: line)
            return
        }

        var foundSemanticColor = false
        for y in 0..<bitmap.pixelsHigh {
            for x in max(0, minimumX)..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.01 else {
                    continue
                }
                let redGreenDelta = abs(color.redComponent - color.greenComponent)
                let greenBlueDelta = abs(color.greenComponent - color.blueComponent)
                if redGreenDelta > 0.08 || greenBlueDelta > 0.08 {
                    foundSemanticColor = true
                    break
                }
            }
        }

        XCTAssert(
            foundSemanticColor,
            "Menu bar semantic status shapes should keep their risk colors.",
            file: file,
            line: line
        )
    }

    private static func oauthRow(
        id: String,
        fiveHourUsedPercent: Double,
        weeklyUsedPercent: Double
    ) -> XlyraOAuthRow {
        XlyraOAuthRow(
            id: id,
            provider: "codex",
            siteName: nil,
            siteSlug: nil,
            status: "connected",
            accountID: id,
            email: "\(id)@example.com",
            planType: nil,
            available: true,
            limitReached: false,
            fiveHourUsedPercent: fiveHourUsedPercent,
            fiveHourRemainingPercent: nil,
            fiveHourResetAt: nil,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyRemainingPercent: nil,
            weeklyResetAt: nil,
            creditsBalance: nil,
            creditsUnlimited: nil,
            lastRefreshAt: nil,
            lastSyncAt: nil,
            expiresAt: nil,
            tokens24h: 0,
            cost24h: 0
        )
    }

    private static func redComponent(of color: NSColor) -> CGFloat {
        color.usingColorSpace(.deviceRGB)?.redComponent ?? -1
    }
}
