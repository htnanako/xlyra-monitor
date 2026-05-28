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
}

struct ThemedSceneContent<Content: View>: View {
    @ObservedObject var preferences: AppPreferences
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .preferredColorScheme(preferences.themeMode.preferredColorScheme)
    }
}
