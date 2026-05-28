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

    func resolvesToDark(systemColorScheme: ColorScheme) -> Bool {
        switch self {
        case .automatic:
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

struct ThemedSceneContent<Content: View>: View {
    @ObservedObject var preferences: AppPreferences
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .preferredColorScheme(preferences.themeMode.preferredColorScheme)
            .background(WindowAppearanceUpdater(themeMode: preferences.themeMode))
    }
}

private struct WindowAppearanceUpdater: NSViewRepresentable {
    let themeMode: AppThemeMode

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
        view.window?.appearance = themeMode.nsAppearance
    }
}
