import Foundation
import Testing
@testable import Sub2APIQuotaApp
@testable import Sub2APIQuotaCore

@Suite("StatusWindowViewModelTests")
@MainActor
struct StatusWindowViewModelTests {
    @Test
    func defaultThresholdValueIsTen() {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )

        #expect(model.thresholdText == "10")
        #expect(model.refreshIntervalText == "30")
        #expect(model.showsMenuBarNumbers == false)
        #expect(model.themeMode == .automatic)
        #expect(model.passwordPlaceholder == "登录密码")
    }

    @Test
    func loadsSavedConfigurationWithoutShowingPassword() {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(
                loadResult: .success(StoredConfiguration(
                    serviceRoot: URL(string: "https://example.com")!,
                    quotaURL: URL(string: "https://example.com/api/quota")!,
                    email: "admin@example.com",
                    apiKey: "secret",
                    threshold: Decimal(3)
                ))
            ),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(isEnabled: true),
            systemSettings: FakeSystemSettings()
        )

        #expect(model.serviceURLText == "https://example.com")
        #expect(model.emailText == "admin@example.com")
        #expect(model.apiKeyText == "")
        #expect(model.thresholdText == "3")
        #expect(model.hasSavedAPIKey)
        #expect(model.launchAtLogin)
        #expect(model.passwordPlaceholder == "已保存密码，留空则不修改")
    }

    @Test
    func savedPasswordCanBeKeptWhenSavingOtherSettings() async {
        let store = FakeSavingCredentialStore(
            loadResult: .success(StoredConfiguration(
                serviceRoot: URL(string: "https://example.com")!,
                quotaURL: URL(string: "https://example.com/api/quota")!,
                email: "admin@example.com",
                apiKey: "secret",
                threshold: Decimal(3)
            ))
        )
        let monitor = FakeConfigurationMonitor()
        let model = SettingsViewModel(
            credentialStore: store,
            monitor: monitor,
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.thresholdText = "5"

        await model.save()

        #expect(store.savedServiceURL == "https://example.com")
        #expect(store.savedEmail == "admin@example.com")
        #expect(store.savedAPIKey == nil)
        #expect(store.savedThreshold == Decimal(5))
        #expect(monitor.configurationChangeCount == 1)
        #expect(model.successMessage == "已保存配置")
    }

    @Test
    func rejectsServiceURLWithoutProtocol() async {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"

        await model.save()

        #expect(model.errorMessage == "服务地址必须以 http:// 或 https:// 开头")
    }

    @Test
    func rejectsThresholdWithMoreThanTwoDecimalPlaces() async {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"
        model.thresholdText = "1.234"

        await model.save()

        #expect(model.errorMessage == "阈值最多保留 2 位小数")
    }

    @Test
    func keychainWriteFailureIsUserFacing() async {
        let store = FakeSavingCredentialStore(saveError: QuotaErrorKind.credentialWriteFailed)
        let model = SettingsViewModel(
            credentialStore: store,
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"

        await model.save()

        #expect(model.errorMessage == "密码保存失败")
    }

    @Test
    func successfulSaveTriggersConfigurationRefresh() async {
        let store = FakeSavingCredentialStore()
        let monitor = FakeConfigurationMonitor()
        let model = SettingsViewModel(
            credentialStore: store,
            monitor: monitor,
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"
        model.thresholdText = "3"

        await model.save()

        #expect(store.savedServiceURL == "https://example.com")
        #expect(store.savedEmail == "admin@example.com")
        #expect(store.savedAPIKey == "secret")
        #expect(store.savedThreshold == Decimal(3))
        #expect(monitor.configurationChangeCount == 1)
        #expect(model.successMessage == "已保存配置")
    }

    @Test
    func savesClientDisplayPreferences() async {
        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = FakeSavingCredentialStore()
        let loginItem = FakeLoginItem()
        let model = SettingsViewModel(
            credentialStore: store,
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: preferences,
            loginItem: loginItem,
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"
        model.thresholdText = "3"
        model.refreshIntervalText = "60"
        model.showsMenuBarNumbers = true
        model.themeMode = .dark
        model.launchAtLogin = true

        await model.save()

        #expect(preferences.refreshIntervalSeconds == 60)
        #expect(preferences.showsMenuBarNumbers)
        #expect(preferences.themeMode == .dark)
        #expect(loginItem.setEnabledCalls == [true])
    }

    @Test
    func themeModeUpdatesImmediatelyBeforeSaving() {
        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: preferences,
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )

        model.themeMode = .dark
        model.updateThemeMode(model.themeMode)

        #expect(preferences.themeMode == .dark)
    }

    @Test
    func loginItemFailureIsUserFacing() async {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(updateError: LoginItemError.updateFailed),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"
        model.launchAtLogin = true

        await model.save()

        #expect(model.errorMessage == "开机自启动设置失败")
    }

    @Test
    func rejectsInvalidRefreshInterval() async {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )
        model.serviceURLText = "https://example.com"
        model.emailText = "admin@example.com"
        model.apiKeyText = "secret"
        model.refreshIntervalText = "2"

        await model.save()

        #expect(model.errorMessage == "刷新间隔必须是 5 到 3600 秒的整数")
    }

    @Test
    func deniedNotificationHintIsShown() {
        let model = SettingsViewModel(
            credentialStore: FakeSavingCredentialStore(),
            monitor: FakeConfigurationMonitor(),
            notificationStatus: FakeNotificationStatus(isAuthorizationDenied: true),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            loginItem: FakeLoginItem(),
            systemSettings: FakeSystemSettings()
        )

        #expect(model.notificationDeniedHint == "通知权限已关闭，低额度提醒不会弹出。")
    }
}

private final class FakeSavingCredentialStore: CredentialLoading, CredentialSaving {
    var savedServiceURL: String?
    var savedEmail: String?
    var savedAPIKey: String?
    var savedThreshold: Decimal?
    private let loadResult: Result<StoredConfiguration?, Error>
    private let saveError: Error?

    init(
        loadResult: Result<StoredConfiguration?, Error> = .success(nil),
        saveError: Error? = nil
    ) {
        self.loadResult = loadResult
        self.saveError = saveError
    }

    func load() throws -> StoredConfiguration? {
        try loadResult.get()
    }

    func save(serviceURL: String, email: String, apiKey: String, threshold: Decimal) throws {
        try update(
            serviceURL: serviceURL,
            email: email,
            apiKey: apiKey,
            inspectedAPIKey: nil,
            threshold: threshold
        )
    }

    func update(
        serviceURL: String,
        email: String,
        apiKey: String?,
        inspectedAPIKey: String?,
        threshold: Decimal
    ) throws {
        if let saveError {
            throw saveError
        }

        savedServiceURL = serviceURL
        savedEmail = email
        savedAPIKey = apiKey
        savedThreshold = threshold
    }
}

private final class FakeConfigurationMonitor: ConfigurationRefreshing {
    private(set) var configurationChangeCount = 0

    func configurationDidChange() async {
        configurationChangeCount += 1
    }
}

private struct FakeNotificationStatus: NotificationAuthorizationStatusProviding {
    var isAuthorizationDenied: Bool = false

    func requestAuthorization() async -> Bool {
        isAuthorizationDenied == false
    }

    func refreshAuthorizationStatus() async -> Bool {
        isAuthorizationDenied == false
    }
}

private final class FakeLoginItem: LoginItemManaging {
    var isEnabled: Bool
    private(set) var setEnabledCalls: [Bool] = []
    private let updateError: Error?

    init(isEnabled: Bool = false, updateError: Error? = nil) {
        self.isEnabled = isEnabled
        self.updateError = updateError
    }

    func setEnabled(_ isEnabled: Bool) throws {
        setEnabledCalls.append(isEnabled)
        if let updateError {
            throw updateError
        }

        self.isEnabled = isEnabled
    }
}

private final class FakeSystemSettings: SystemSettingsOpening {
    private(set) var openNotificationSettingsCallCount = 0

    func openNotificationSettings() {
        openNotificationSettingsCallCount += 1
    }
}
