import AppKit
import SwiftUI

extension AppThemeMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func resolvedColorScheme(
        systemColorScheme: ColorScheme,
        systemInterfaceStyle: String? = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"),
        effectiveAppearance: NSAppearance? = NSApp.effectiveAppearance
    ) -> ColorScheme {
        resolvesToDark(
            systemColorScheme: systemColorScheme,
            systemInterfaceStyle: systemInterfaceStyle,
            effectiveAppearance: effectiveAppearance
        ) ? .dark : .light
    }

    func resolvedNSAppearance(
        systemColorScheme: ColorScheme,
        systemInterfaceStyle: String? = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"),
        effectiveAppearance: NSAppearance? = NSApp.effectiveAppearance
    ) -> NSAppearance? {
        switch resolvedColorScheme(
            systemColorScheme: systemColorScheme,
            systemInterfaceStyle: systemInterfaceStyle,
            effectiveAppearance: effectiveAppearance
        ) {
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        @unknown default:
            return nil
        }
    }

    func resolvesToDark(
        systemColorScheme: ColorScheme,
        systemInterfaceStyle: String? = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"),
        effectiveAppearance: NSAppearance? = NSApp.effectiveAppearance
    ) -> Bool {
        switch self {
        case .automatic:
            if let systemInterfaceStyle {
                return systemInterfaceStyle.caseInsensitiveCompare("Dark") == .orderedSame
            }
            if let isDarkAppearance = effectiveAppearance?.isDarkAppearance {
                return isDarkAppearance
            }
            return systemColorScheme == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .automatic:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

private extension NSAppearance {
    var isDarkAppearance: Bool? {
        guard let match = bestMatch(from: [.darkAqua, .aqua]) else {
            return nil
        }
        return match == .darkAqua
    }
}

struct ThemedSceneContent<Content: View>: View {
    @ObservedObject var preferences: AppPreferences
    let usesSolidWindowBackground: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var systemColorScheme

    init(
        preferences: AppPreferences,
        usesSolidWindowBackground: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.preferences = preferences
        self.usesSolidWindowBackground = usesSolidWindowBackground
        self.content = content
    }

    var body: some View {
        let resolvedColorScheme = preferences.themeMode.resolvedColorScheme(
            systemColorScheme: systemColorScheme
        )

        content()
            .environment(\.colorScheme, resolvedColorScheme)
            .preferredColorScheme(resolvedColorScheme)
            .background {
                if usesSolidWindowBackground {
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                }
            }
            .background(
                WindowAppearanceUpdater(
                    themeMode: preferences.themeMode,
                    systemColorScheme: systemColorScheme
                )
            )
    }
}

private struct WindowAppearanceUpdater: NSViewRepresentable {
    let themeMode: AppThemeMode
    let systemColorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = true
        updateAppearance(for: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            updateAppearance(for: view)
        }
    }

    private func updateAppearance(for view: NSView) {
        view.window?.appearance = themeMode.resolvedNSAppearance(systemColorScheme: systemColorScheme)
    }
}
