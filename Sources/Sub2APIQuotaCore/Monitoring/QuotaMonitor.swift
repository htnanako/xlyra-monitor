import Foundation

public enum RefreshSource {
    case automatic
    case manual
    case configurationChanged
}

public protocol MonitorClock {
    func sleep(for interval: TimeInterval) async
}

public protocol ConfigurationRefreshing {
    func configurationDidChange() async
}

public protocol ManualRefreshing {
    func refresh(source: RefreshSource) async
}

public struct SystemMonitorClock: MonitorClock {
    public init() {}

    public func sleep(for interval: TimeInterval) async {
        let nanoseconds = UInt64(max(0, interval) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

@MainActor
public final class QuotaMonitor: ConfigurationRefreshing, ManualRefreshing {
    private let state: AppState
    private let credentialStore: CredentialLoading
    private let quotaService: QuotaFetching
    private let notificationDispatcher: NotificationDispatching
    private let now: () -> Date
    private var notificationPolicy: NotificationPolicy
    private var generation = 0
    private var inFlightRequest: (token: Int, task: Task<Void, Never>)?
    private var nextInFlightToken = 0
    private var pollingTask: Task<Void, Never>?

    public init(
        state: AppState,
        credentialStore: CredentialLoading,
        quotaService: QuotaFetching,
        notificationDispatcher: NotificationDispatching,
        now: @escaping () -> Date = Date.init,
        notificationCooldown: TimeInterval = 1800
    ) {
        self.state = state
        self.credentialStore = credentialStore
        self.quotaService = quotaService
        self.notificationDispatcher = notificationDispatcher
        self.now = now
        self.notificationPolicy = NotificationPolicy(cooldown: notificationCooldown)
    }

    public func refresh(source: RefreshSource) async {
        if let inFlightRequest {
            switch source {
            case .automatic:
                return
            case .manual:
                await inFlightRequest.task.value
                return
            case .configurationChanged:
                break
            }
        }

        let requestGeneration = generation
        nextInFlightToken += 1
        let token = nextInFlightToken
        let task = Task { @MainActor in
            await performRefresh(generation: requestGeneration)
        }

        inFlightRequest = (token, task)
        await task.value

        if inFlightRequest?.token == token {
            inFlightRequest = nil
        }
    }

    public func start(interval: TimeInterval, clock: MonitorClock = SystemMonitorClock()) async {
        await stop()
        await refresh(source: .automatic)

        pollingTask = Task { @MainActor in
            while Task.isCancelled == false {
                await clock.sleep(for: interval)
                if Task.isCancelled {
                    break
                }

                await refresh(source: .automatic)
            }
        }
    }

    public func stop() async {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func configurationDidChange() async {
        generation += 1
        state.resetFailureTracking()
        notificationPolicy.resetFailurePeriod()
        await refresh(source: .configurationChanged)
    }

    private func performRefresh(generation requestGeneration: Int) async {
        let oldStatus = state.status
        let start = now()
        state.setRequestInFlight(true)

        let configuration: StoredConfiguration?
        do {
            configuration = try credentialStore.load()
        } catch let error as QuotaErrorKind {
            await applyFailureIfCurrent(error, oldStatus: oldStatus, requestGeneration: requestGeneration)
            return
        } catch {
            await applyFailureIfCurrent(.credentialReadFailed, oldStatus: oldStatus, requestGeneration: requestGeneration)
            return
        }

        guard let configuration else {
            guard requestGeneration == generation else {
                return
            }

            let oldStatus = state.status
            state.applyNotConfigured()
            await dispatchNotificationIfNeeded(from: oldStatus, snapshot: nil)
            return
        }

        let serviceConfiguration = ServiceConfiguration(
            serviceRoot: configuration.serviceRoot,
            quotaURL: configuration.quotaURL
        )

        do {
            let snapshot = try await quotaService.fetchQuota(
                configuration: serviceConfiguration,
                apiKey: configuration.loginCredential,
                inspectedAPIKey: configuration.inspectedAPIKey
            )

            guard requestGeneration == generation else {
                return
            }

            let oldStatus = state.status
            state.applySuccess(
                snapshot,
                threshold: configuration.threshold,
                requestDuration: now().timeIntervalSince(start)
            )
            await dispatchNotificationIfNeeded(from: oldStatus, snapshot: snapshot)
        } catch let error as QuotaErrorKind {
            await applyFailureIfCurrent(error, oldStatus: oldStatus, requestGeneration: requestGeneration)
        } catch {
            await applyFailureIfCurrent(.network, oldStatus: oldStatus, requestGeneration: requestGeneration)
        }
    }

    private func applyFailureIfCurrent(
        _ error: QuotaErrorKind,
        oldStatus: QuotaStatus,
        requestGeneration: Int
    ) async {
        guard requestGeneration == generation else {
            return
        }

        state.applyFailure(error)
        await dispatchNotificationIfNeeded(from: oldStatus, snapshot: state.quotaSnapshot)
    }

    private func dispatchNotificationIfNeeded(from oldStatus: QuotaStatus, snapshot: QuotaSnapshot?) async {
        guard let kind = notificationPolicy.notification(
            from: oldStatus,
            to: state.status,
            consecutiveFailures: state.consecutiveFailureCount,
            now: now()
        ) else {
            return
        }

        await notificationDispatcher.dispatch(kind, snapshot: snapshot)
    }
}
