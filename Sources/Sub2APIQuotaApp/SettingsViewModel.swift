import Foundation
import Sub2APIQuotaCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var serviceURLText = ""
    @Published var emailText = ""
    @Published var apiKeyText = ""
    @Published var inspectedAPIKeyText = ""
    @Published var modelCheckBaseURLText = ""
    @Published var modelCheckAPIKeyText = ""
    @Published var modelCheckModelText = ""
    @Published var thresholdText = "10"
    @Published var refreshIntervalText = "30"
    @Published var showsMenuBarNumbers = false
    @Published var themeMode: AppThemeMode = .automatic
    @Published var launchAtLogin = false
    @Published private(set) var isRefreshingNotificationPermission = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    @Published private(set) var isSaving = false
    @Published private(set) var isRunningModelCheck = false
    @Published private(set) var hasSavedAPIKey = false
    @Published private(set) var hasSavedInspectedAPIKey = false
    @Published private(set) var hasSavedModelCheckAPIKey = false

    private let credentialStore: CredentialLoading & CredentialSaving
    private let modelCheckStore: (ModelCheckConfigurationLoading & ModelCheckConfigurationSaving & ModelCheckPreferenceLoading & ModelCheckPreferenceSaving)?
    private let modelChecker: ModelDegradationChecking?
    private let accountModelChecker: AccountModelDegradationChecking?
    private let appState: AppState?
    private let monitor: ConfigurationRefreshing
    private let notificationStatus: NotificationAuthorizationStatusProviding
    private let preferences: AppPreferences
    private let loginItem: LoginItemManaging
    private let systemSettings: SystemSettingsOpening

    init(
        credentialStore: CredentialLoading & CredentialSaving,
        modelCheckStore: (ModelCheckConfigurationLoading & ModelCheckConfigurationSaving & ModelCheckPreferenceLoading & ModelCheckPreferenceSaving)? = nil,
        modelChecker: ModelDegradationChecking? = nil,
        accountModelChecker: AccountModelDegradationChecking? = nil,
        appState: AppState? = nil,
        monitor: ConfigurationRefreshing,
        notificationStatus: NotificationAuthorizationStatusProviding,
        preferences: AppPreferences,
        loginItem: LoginItemManaging,
        systemSettings: SystemSettingsOpening
    ) {
        self.credentialStore = credentialStore
        self.modelCheckStore = modelCheckStore
        self.modelChecker = modelChecker
        self.accountModelChecker = accountModelChecker
        self.appState = appState
        self.monitor = monitor
        self.notificationStatus = notificationStatus
        self.preferences = preferences
        self.loginItem = loginItem
        self.systemSettings = systemSettings
        loadSavedConfiguration()
        loadSavedModelCheckConfiguration()
        loadPreferences()
        launchAtLogin = loginItem.isEnabled
    }

    var notificationDeniedHint: String? {
        notificationStatus.isAuthorizationDenied
            ? "通知权限已关闭，低额度提醒不会弹出。"
            : nil
    }

    var passwordPlaceholder: String {
        hasSavedAPIKey ? "已保存密码，留空则不修改" : "登录密码"
    }

    var inspectedAPIKeyPlaceholder: String {
        hasSavedInspectedAPIKey ? "已保存检查 Key，留空则不修改" : "sk-..."
    }

    var modelCheckAPIKeyPlaceholder: String {
        hasSavedModelCheckAPIKey ? "已保存检测 Key，留空则不修改" : "sk-..."
    }

    func save() async {
        errorMessage = nil
        successMessage = nil

        let threshold: Decimal
        let refreshIntervalSeconds: TimeInterval
        do {
            _ = try ServiceURLNormalizer.normalize(serviceURLText)
            threshold = try ThresholdValidator.parse(thresholdText)
            refreshIntervalSeconds = try Self.parseRefreshInterval(refreshIntervalText)
        } catch ServiceURLValidationError.invalidServiceRoot {
            errorMessage = "服务地址必须以 http:// 或 https:// 开头"
            return
        } catch ThresholdValidationError.tooManyFractionDigits {
            errorMessage = "阈值最多保留 2 位小数"
            return
        } catch ThresholdValidationError.invalidNumber {
            errorMessage = "阈值必须是非负数字"
            return
        } catch RefreshIntervalValidationError.invalid {
            errorMessage = "刷新间隔必须是 5 到 3600 秒的整数"
            return
        } catch {
            errorMessage = "配置格式不正确"
            return
        }

        guard emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            errorMessage = "邮箱不能为空"
            return
        }

        let trimmedAPIKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInspectedAPIKey = inspectedAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAPIKey.isEmpty == false || hasSavedAPIKey else {
            errorMessage = "密码不能为空"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try credentialStore.update(
                serviceURL: serviceURLText,
                email: emailText,
                apiKey: trimmedAPIKey.isEmpty ? nil : apiKeyText,
                inspectedAPIKey: trimmedInspectedAPIKey.isEmpty ? nil : inspectedAPIKeyText,
                threshold: threshold
            )
            try saveModelCheckConfigurationIfComplete()
            preferences.update(
                refreshIntervalSeconds: refreshIntervalSeconds,
                showsMenuBarNumbers: showsMenuBarNumbers,
                themeMode: themeMode
            )
            try loginItem.setEnabled(launchAtLogin)
            await monitor.configurationDidChange()
            hasSavedAPIKey = true
            if trimmedInspectedAPIKey.isEmpty == false {
                hasSavedInspectedAPIKey = true
            }
            apiKeyText = ""
            inspectedAPIKeyText = ""
            modelCheckAPIKeyText = ""
            successMessage = "已保存配置"
        } catch LoginItemError.updateFailed {
            errorMessage = "开机自启动设置失败"
        } catch ModelCheckError.invalidConfiguration {
            errorMessage = "模型检测配置不完整"
        } catch QuotaErrorKind.credentialWriteFailed {
            errorMessage = "密码保存失败"
        } catch {
            errorMessage = "保存失败"
        }
    }

    func updateThemeMode(_ themeMode: AppThemeMode) {
        preferences.updateThemeMode(themeMode)
    }

    func runModelCheck() async {
        errorMessage = nil
        successMessage = nil

        guard let modelChecker, let appState else {
            errorMessage = "检测服务未初始化"
            return
        }

        let configuration: ModelCheckConfiguration
        do {
            configuration = try makeModelCheckConfigurationForRun()
            try modelCheckStore?.saveModelCheckConfiguration(
                baseURL: configuration.baseURL.absoluteString,
                apiKey: configuration.apiKey,
                model: configuration.model
            )
            hasSavedModelCheckAPIKey = true
            modelCheckAPIKeyText = ""
        } catch {
            errorMessage = "模型检测配置不完整"
            appState.applyModelCheckError("模型检测配置不完整")
            return
        }

        isRunningModelCheck = true
        appState.setModelCheckInFlight(true)
        defer { isRunningModelCheck = false }

        do {
            let result = try await modelChecker.runCheck(configuration: configuration)
            appState.applyModelCheckResult(result)
            successMessage = "模型检测完成：\(result.status.rawValue) \(result.scoreKind.rawValue) \(result.score)%"
        } catch {
            appState.applyModelCheckError("模型检测请求失败")
            errorMessage = "模型检测请求失败"
        }
    }

    func runModelCheck(accountID: Int, name: String, platform: String) async {
        errorMessage = nil
        successMessage = nil

        guard let accountModelChecker, let appState else {
            errorMessage = "检测服务未初始化"
            return
        }

        let storedConfiguration: StoredConfiguration
        do {
            guard let loadedConfiguration = try credentialStore.load() else {
                errorMessage = "请先保存 Sub2API 登录配置"
                appState.applyModelCheckError("请先保存登录配置", accountID: accountID)
                return
            }
            storedConfiguration = loadedConfiguration
        } catch {
            errorMessage = "读取配置失败"
            appState.applyModelCheckError("读取配置失败", accountID: accountID)
            return
        }

        let model: String
        do {
            model = try modelCheckModelForRun()
        } catch {
            errorMessage = "模型检测配置不完整"
            appState.applyModelCheckError("请先在设置里填写目标模型", accountID: accountID)
            return
        }

        let credential = LoginCredential(email: storedConfiguration.email, password: storedConfiguration.apiKey)
        let serviceConfiguration = ServiceConfiguration(
            serviceRoot: storedConfiguration.serviceRoot,
            quotaURL: storedConfiguration.quotaURL
        )
        let target = AccountModelCheckTarget(id: accountID, name: name, platform: platform)

        appState.setModelCheckInFlight(true, accountID: accountID)
        do {
            try modelCheckStore?.saveModelCheckModel(model)
            let result = try await accountModelChecker.runCheck(
                configuration: serviceConfiguration,
                credential: credential,
                target: target,
                model: model
            )
            appState.applyModelCheckResult(result, accountID: accountID)
        } catch {
            appState.applyModelCheckError("模型检测请求失败", accountID: accountID)
        }
    }

    func openNotificationSettings() async {
        systemSettings.openNotificationSettings()
        isRefreshingNotificationPermission = true
        defer { isRefreshingNotificationPermission = false }
        _ = await notificationStatus.refreshAuthorizationStatus()
    }

    func requestNotificationPermission() async {
        isRefreshingNotificationPermission = true
        defer { isRefreshingNotificationPermission = false }
        let authorized = await notificationStatus.requestAuthorization()
        if authorized {
            successMessage = "已允许通知"
            errorMessage = nil
        } else if notificationStatus.isAuthorizationDenied {
            errorMessage = "通知已被系统拒绝，请打开系统通知设置允许 Sub2API Quota。"
        }
    }

    private func loadSavedConfiguration() {
        do {
            guard let configuration = try credentialStore.load() else {
                return
            }

            serviceURLText = configuration.serviceRoot.absoluteString
            emailText = configuration.email
            thresholdText = NSDecimalNumber(decimal: configuration.threshold).stringValue
            hasSavedAPIKey = configuration.apiKey.isEmpty == false
            hasSavedInspectedAPIKey = configuration.inspectedAPIKey?.isEmpty == false
        } catch {
            errorMessage = "读取配置失败"
        }
    }

    private func loadSavedModelCheckConfiguration() {
        do {
            guard let configuration = try modelCheckStore?.loadModelCheckConfiguration() else {
                if let model = try modelCheckStore?.loadModelCheckModel() {
                    modelCheckModelText = model
                }
                return
            }

            modelCheckBaseURLText = configuration.baseURL.absoluteString
            modelCheckModelText = configuration.model
            hasSavedModelCheckAPIKey = configuration.apiKey.isEmpty == false
        } catch {
            errorMessage = "读取模型检测配置失败"
        }
    }

    private func loadPreferences() {
        refreshIntervalText = String(Int(preferences.refreshIntervalSeconds))
        showsMenuBarNumbers = preferences.showsMenuBarNumbers
        themeMode = preferences.themeMode
    }

    private static func parseRefreshInterval(_ text: String) throws -> TimeInterval {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seconds = Int(trimmedText),
              seconds >= 5,
              seconds <= 3600 else {
            throw RefreshIntervalValidationError.invalid
        }

        return TimeInterval(seconds)
    }

    private func saveModelCheckConfigurationIfComplete() throws {
        let baseURL = modelCheckBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = modelCheckAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelCheckModelText.trimmingCharacters(in: .whitespacesAndNewlines)

        if baseURL.isEmpty && apiKey.isEmpty && model.isEmpty {
            return
        }

        if baseURL.isEmpty && apiKey.isEmpty {
            try modelCheckStore?.saveModelCheckModel(model)
            return
        }

        if apiKey.isEmpty,
           hasSavedModelCheckAPIKey,
           let savedConfiguration = try modelCheckStore?.loadModelCheckConfiguration() {
            try modelCheckStore?.saveModelCheckConfiguration(
                baseURL: baseURL.isEmpty ? savedConfiguration.baseURL.absoluteString : baseURL,
                apiKey: savedConfiguration.apiKey,
                model: model.isEmpty ? savedConfiguration.model : model
            )
            return
        }

        try modelCheckStore?.saveModelCheckConfiguration(baseURL: baseURL, apiKey: apiKey, model: model)
        hasSavedModelCheckAPIKey = apiKey.isEmpty == false || hasSavedModelCheckAPIKey
    }

    private func makeModelCheckConfigurationForRun() throws -> ModelCheckConfiguration {
        let baseURL = modelCheckBaseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = modelCheckAPIKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelCheckModelText.trimmingCharacters(in: .whitespacesAndNewlines)

        if apiKey.isEmpty,
           let savedConfiguration = try modelCheckStore?.loadModelCheckConfiguration() {
            try modelCheckStore?.saveModelCheckConfiguration(
                baseURL: baseURL.isEmpty ? savedConfiguration.baseURL.absoluteString : baseURL,
                apiKey: savedConfiguration.apiKey,
                model: model.isEmpty ? savedConfiguration.model : model
            )
            guard let updatedConfiguration = try modelCheckStore?.loadModelCheckConfiguration() else {
                throw ModelCheckError.invalidConfiguration
            }
            return updatedConfiguration
        }

        guard let modelCheckStore else {
            throw ModelCheckError.invalidConfiguration
        }

        try modelCheckStore.saveModelCheckConfiguration(baseURL: baseURL, apiKey: apiKey, model: model)
        guard let configuration = try modelCheckStore.loadModelCheckConfiguration() else {
            throw ModelCheckError.invalidConfiguration
        }
        return configuration
    }

    private func modelCheckModelForRun() throws -> String {
        let model = modelCheckModelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.isEmpty == false {
            return model
        }

        guard let savedModel = try modelCheckStore?.loadModelCheckModel(),
              savedModel.isEmpty == false else {
            throw ModelCheckError.invalidConfiguration
        }
        return savedModel
    }
}

private enum RefreshIntervalValidationError: Error {
    case invalid
}
