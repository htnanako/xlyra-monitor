import Foundation

enum AppThemeMode: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            return "自动"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published private(set) var refreshIntervalSeconds: TimeInterval
    @Published private(set) var oauthRefreshIntervalSeconds: TimeInterval
    @Published private(set) var showsMenuBarNumbers: Bool
    @Published private(set) var importDirectoryPath: String
    @Published private(set) var themeMode: AppThemeMode

    private let userDefaults: UserDefaults
    private let refreshIntervalKey: String
    private let oauthRefreshIntervalKey: String
    private let showsMenuBarNumbersKey: String
    private let importDirectoryPathKey: String
    private let themeModeKey: String

    init(
        userDefaults: UserDefaults = .standard,
        refreshIntervalKey: String = "xlyra.refreshIntervalSeconds",
        oauthRefreshIntervalKey: String = "xlyra.oauthRefreshIntervalSeconds",
        showsMenuBarNumbersKey: String = "xlyra.showsMenuBarNumbers",
        importDirectoryPathKey: String = "xlyra.importDirectoryPath",
        themeModeKey: String = "xlyra.themeMode",
        defaultRefreshInterval: TimeInterval = 30,
        defaultOAuthRefreshInterval: TimeInterval = 300,
        defaultShowsMenuBarNumbers: Bool = false,
        defaultImportDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .path,
        defaultThemeMode: AppThemeMode = .automatic
    ) {
        self.userDefaults = userDefaults
        self.refreshIntervalKey = refreshIntervalKey
        self.oauthRefreshIntervalKey = oauthRefreshIntervalKey
        self.showsMenuBarNumbersKey = showsMenuBarNumbersKey
        self.importDirectoryPathKey = importDirectoryPathKey
        self.themeModeKey = themeModeKey

        let savedRefreshInterval = userDefaults.object(forKey: refreshIntervalKey) as? Double
        refreshIntervalSeconds = Self.clampedRefreshInterval(
            savedRefreshInterval ?? defaultRefreshInterval
        )
        let savedOAuthRefreshInterval = userDefaults.object(forKey: oauthRefreshIntervalKey) as? Double
        oauthRefreshIntervalSeconds = Self.clampedRefreshInterval(
            savedOAuthRefreshInterval ?? defaultOAuthRefreshInterval
        )

        if userDefaults.object(forKey: showsMenuBarNumbersKey) == nil {
            showsMenuBarNumbers = defaultShowsMenuBarNumbers
        } else {
            showsMenuBarNumbers = userDefaults.bool(forKey: showsMenuBarNumbersKey)
        }

        let savedImportDirectoryPath = userDefaults.string(forKey: importDirectoryPathKey)
        importDirectoryPath = savedImportDirectoryPath?.isEmpty == false
            ? savedImportDirectoryPath!
            : defaultImportDirectoryPath

        let savedThemeMode = userDefaults.string(forKey: themeModeKey).flatMap(AppThemeMode.init(rawValue:))
        themeMode = savedThemeMode ?? defaultThemeMode
    }

    func update(
        refreshIntervalSeconds: TimeInterval,
        oauthRefreshIntervalSeconds: TimeInterval? = nil,
        showsMenuBarNumbers: Bool,
        themeMode: AppThemeMode
    ) {
        let normalizedRefreshInterval = Self.clampedRefreshInterval(refreshIntervalSeconds)
        let normalizedOAuthRefreshInterval = Self.clampedRefreshInterval(
            oauthRefreshIntervalSeconds ?? self.oauthRefreshIntervalSeconds
        )
        self.refreshIntervalSeconds = normalizedRefreshInterval
        self.oauthRefreshIntervalSeconds = normalizedOAuthRefreshInterval
        self.showsMenuBarNumbers = showsMenuBarNumbers
        self.themeMode = themeMode
        userDefaults.set(normalizedRefreshInterval, forKey: refreshIntervalKey)
        userDefaults.set(normalizedOAuthRefreshInterval, forKey: oauthRefreshIntervalKey)
        userDefaults.set(showsMenuBarNumbers, forKey: showsMenuBarNumbersKey)
        userDefaults.set(themeMode.rawValue, forKey: themeModeKey)
    }

    func updateThemeMode(_ themeMode: AppThemeMode) {
        self.themeMode = themeMode
        userDefaults.set(themeMode.rawValue, forKey: themeModeKey)
    }

    func updateImportDirectoryPath(_ path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        importDirectoryPath = trimmedPath
        userDefaults.set(trimmedPath, forKey: importDirectoryPathKey)
    }

    private static func clampedRefreshInterval(_ value: TimeInterval) -> TimeInterval {
        min(3600, max(5, value.rounded()))
    }
}
