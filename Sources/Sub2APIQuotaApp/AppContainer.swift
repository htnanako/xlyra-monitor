import Foundation
import AppKit
import Combine
import Sub2APIQuotaCore

@MainActor
final class AppContainer: ObservableObject {
    let state: AppState
    let preferences: AppPreferences
    let credentialStore: CredentialStore
    let quotaMonitor: QuotaMonitor
    let notificationDispatcher: NotificationDispatcher
    let settingsViewModel: SettingsViewModel
    let accountImportViewModel: AccountImportViewModel
    let accountPriorityUpdater: AccountPriorityUpdating
    let keyAvailabilityChecker: KeyAvailabilityChecking
    private var keyAvailabilityTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let appState = AppState()
        let settings = UserDefaultsSettingsStore()
        let preferences = AppPreferences()
        let store = CredentialStore(
            settings: settings,
            secrets: UserDefaultsSecretStore(settings: settings)
        )
        let quotaService = QuotaService(httpClient: URLSessionHTTPClient())
        let priorityUpdater = AccountPriorityUpdateService(httpClient: URLSessionHTTPClient())
        let availabilityChecker = KeyAvailabilityCheckService(httpClient: URLSessionHTTPClient())
        let historyStore = ImportHistoryStore()
        let dispatcher = NotificationDispatcher(client: UserNotificationClient())
        let monitor = QuotaMonitor(
            state: appState,
            credentialStore: store,
            quotaService: quotaService,
            notificationDispatcher: dispatcher,
            notificationCooldown: Self.notificationCooldown()
        )

        state = appState
        self.preferences = preferences
        credentialStore = store
        quotaMonitor = monitor
        notificationDispatcher = dispatcher
        accountPriorityUpdater = priorityUpdater
        keyAvailabilityChecker = availabilityChecker
        settingsViewModel = SettingsViewModel(
            credentialStore: store,
            modelCheckStore: store,
            modelChecker: ModelDegradationCheckService(httpClient: URLSessionHTTPClient()),
            accountModelChecker: AccountModelDegradationCheckService(httpClient: URLSessionHTTPClient()),
            appState: appState,
            monitor: monitor,
            notificationStatus: dispatcher,
            preferences: preferences,
            loginItem: LoginItemService(),
            systemSettings: SystemSettingsOpener()
        )
        accountImportViewModel = AccountImportViewModel(
            credentialStore: store,
            preferences: preferences,
            reader: CredentialImportReader(),
            scanner: CredentialImportDirectoryScanner(historyStore: historyStore),
            importer: AccountImportService(httpClient: URLSessionHTTPClient()),
            revokedAccountCleaner: RevokedAccountCleanupService(httpClient: URLSessionHTTPClient()),
            historyStore: historyStore,
            refresher: monitor
        )

        preferences.$refreshIntervalSeconds
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] refreshIntervalSeconds in
                Task { @MainActor in
                    await self?.quotaMonitor.start(interval: refreshIntervalSeconds)
                }
            }
            .store(in: &cancellables)

        start()
        applyAppIcon()
        keepAppOutOfDock()
    }

    func start() {
        Task {
            await quotaMonitor.start(interval: preferences.refreshIntervalSeconds)
        }
        startKeyAvailabilityMonitoring()
    }

    func stop() {
        Task {
            await quotaMonitor.stop()
        }
        keyAvailabilityTask?.cancel()
        keyAvailabilityTask = nil
    }

    func updateAccountPriority(accountID: Int, priority: Int) async {
        state.setPriorityUpdateInFlight(true, accountID: accountID)

        do {
            guard let storedConfiguration = try credentialStore.load() else {
                state.applyPriorityUpdateError("请先保存登录配置", accountID: accountID)
                return
            }

            guard let credential = LoginCredential(rawValue: storedConfiguration.loginCredential) else {
                state.applyPriorityUpdateError("登录配置无效", accountID: accountID)
                return
            }

            let serviceConfiguration = ServiceConfiguration(
                serviceRoot: storedConfiguration.serviceRoot,
                quotaURL: storedConfiguration.quotaURL
            )

            try await accountPriorityUpdater.updatePriority(
                configuration: serviceConfiguration,
                credential: credential,
                accountID: accountID,
                priority: priority
            )
            state.applyPriorityUpdateSuccess(accountID: accountID)
            await quotaMonitor.refresh(source: .manual)
        } catch let error as QuotaErrorKind {
            state.applyPriorityUpdateError(priorityUpdateErrorText(error), accountID: accountID)
        } catch {
            state.applyPriorityUpdateError("优先级更新失败", accountID: accountID)
        }
    }

    private func startKeyAvailabilityMonitoring() {
        keyAvailabilityTask?.cancel()
        keyAvailabilityTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            while Task.isCancelled == false {
                await runKeyAvailabilityChecks()
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
            }
        }
    }

    private func runKeyAvailabilityChecks() async {
        let storedConfiguration: StoredConfiguration
        do {
            guard let loadedConfiguration = try credentialStore.load() else {
                return
            }
            storedConfiguration = loadedConfiguration
        } catch {
            return
        }

        let keyAccounts = storedConfigurationKeyAccounts()
        guard keyAccounts.isEmpty == false else {
            return
        }

        let model = ((try? credentialStore.loadModelCheckModel()) ?? "gpt-4.1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard model.isEmpty == false else {
            return
        }

        let credential = LoginCredential(email: storedConfiguration.email, password: storedConfiguration.apiKey)
        let serviceConfiguration = ServiceConfiguration(
            serviceRoot: storedConfiguration.serviceRoot,
            quotaURL: storedConfiguration.quotaURL
        )

        for account in keyAccounts {
            guard state.keyAvailabilityInFlightAccountIDs.contains(account.id) == false else {
                continue
            }

            state.setKeyAvailabilityCheckInFlight(true, accountID: account.id)
            do {
                let result = try await keyAvailabilityChecker.runCheck(
                    configuration: serviceConfiguration,
                    credential: credential,
                    accountID: account.id,
                    model: model
                )
                state.applyKeyAvailabilityResult(result)
            } catch {
                state.applyKeyAvailabilityFailure(accountID: account.id)
            }
        }
    }

    private func storedConfigurationKeyAccounts() -> [AccountQuotaDetail] {
        state.quotaSnapshot?.poolSummary?.accounts.filter {
            AccountChannelKind(accountType: $0.type) == .apiKey
        } ?? []
    }

    private func keepAppOutOfDock() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func applyAppIcon() {
        guard let icon = NSImage(named: Sub2APIQuotaAppMetadata.appIconName) else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }

    private static func notificationCooldown() -> TimeInterval {
        let key = "SUB2API_NOTIFICATION_COOLDOWN_SECONDS"
        guard let rawValue = ProcessInfo.processInfo.environment[key],
              let seconds = TimeInterval(rawValue),
              seconds >= 0 else {
            return 1800
        }

        return seconds
    }

    private func priorityUpdateErrorText(_ error: QuotaErrorKind) -> String {
        switch error {
        case .invalidConfiguration:
            return "配置无效"
        case .authenticationFailed:
            return "认证失败"
        case .timeout:
            return "请求超时"
        case .network:
            return "网络异常"
        case .serviceUnavailable:
            return "服务不可用"
        case .invalidResponse:
            return "响应格式异常"
        case .credentialReadFailed:
            return "读取配置失败"
        case .credentialWriteFailed:
            return "保存配置失败"
        }
    }
}
