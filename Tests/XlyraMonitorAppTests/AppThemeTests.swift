import AppKit
import SwiftUI
import Testing
@testable import XlyraMonitorApp

@Suite("AppThemeTests")
struct AppThemeTests {
    @Test
    func automaticThemeUsesEffectiveAppearanceWhenAvailable() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ))
        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ) == false)
    }

    @Test
    func automaticThemePrefersSystemInterfaceStyle() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!

        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        ))
        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ))
    }

    @Test
    func automaticThemeResolvesConcreteSceneColors() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let darkAppearance = NSAppearance(named: .darkAqua)!

        #expect(AppThemeMode.automatic.resolvedColorScheme(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        ) == .dark)
        #expect(AppThemeMode.automatic.resolvedNSAppearance(
            systemColorScheme: .light,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: lightAppearance
        )?.name == .darkAqua)
        #expect(AppThemeMode.automatic.resolvedColorScheme(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ) == .light)
        #expect(AppThemeMode.automatic.resolvedNSAppearance(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        )?.name == .darkAqua)
    }

    @Test
    func explicitThemeModesIgnoreEffectiveAppearance() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        #expect(AppThemeMode.light.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: "Dark",
            effectiveAppearance: darkAppearance
        ) == false)
        #expect(AppThemeMode.dark.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ))
    }

    @Test
    func automaticThemeFallsBackToSwiftUIColorScheme() {
        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: nil
        ))
        #expect(AppThemeMode.automatic.resolvesToDark(
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: nil
        ) == false)
    }

    @Test
    func menuThemeUsesEffectiveAppearanceForAutomaticMode() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let lightAppearance = NSAppearance(named: .aqua)!

        #expect(MenuTheme(
            mode: .automatic,
            systemColorScheme: .light,
            systemInterfaceStyle: nil,
            effectiveAppearance: darkAppearance
        ).isDark)
        #expect(MenuTheme(
            mode: .automatic,
            systemColorScheme: .dark,
            systemInterfaceStyle: nil,
            effectiveAppearance: lightAppearance
        ).isDark == false)
    }

    @Test
    func menuBarPaletteFollowsMenuBarColorScheme() {
        #expect(Self.redComponent(of: MenuBarPalette(isDarkBackground: false).text) < 0.05)
        #expect(Self.redComponent(of: MenuBarPalette(isDarkBackground: true).text) > 0.90)
    }

    private static func redComponent(of color: NSColor) -> CGFloat {
        color.usingColorSpace(.deviceRGB)?.redComponent ?? -1
    }
}
