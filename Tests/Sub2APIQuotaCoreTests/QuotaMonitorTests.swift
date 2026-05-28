import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("QuotaMonitorTests")
@MainActor
struct QuotaMonitorTests {
    @Test
    func missingConfigurationSetsNotConfigured() async {
        let state = AppState()
        let store = FakeCredentialStore(loadResult: .success(nil))
        let monitor = QuotaMonitor(
            state: state,
            credentialStore: store,
            quotaService: FakeQuotaService(),
            notificationDispatcher: FakeNotificationDispatcher(),
            now: { Date(timeIntervalSince1970: 100) }
        )

        await monitor.refresh(source: .manual)

        #expect(state.status == .notConfigured)
        #expect(state.consecutiveFailureCount == 0)
    }

    @Test
    func successfulRefreshUpdatesState() async {
        let state = AppState()
        let snapshot = Self.quota(available: true, remaining: Decimal(11))
        let service = FakeQuotaService(result: .success(snapshot))
        let monitor = monitor(state: state, service: service)

        await monitor.refresh(source: .manual)

        #expect(state.status == .available)
        #expect(state.quotaSnapshot == snapshot)
        #expect(service.fetchCount == 1)
    }

    @Test
    func failureIncrementsFailureCountAndKeepsLastQuota() async {
        let state = AppState()
        let snapshot = Self.quota(available: true, remaining: Decimal(11))
        let service = FakeQuotaService(result: .success(snapshot))
        let monitor = monitor(state: state, service: service)
        await monitor.refresh(source: .manual)

        service.result = .failure(QuotaErrorKind.network)
        await monitor.refresh(source: .manual)

        #expect(state.status == .apiError(.network))
        #expect(state.quotaSnapshot == snapshot)
        #expect(state.consecutiveFailureCount == 1)
    }

    @Test
    func automaticRefreshSkipsWhileRequestIsInFlight() async {
        let state = AppState()
        let service = SlowQuotaService()
        let monitor = monitor(state: state, service: service)

        async let first: Void = monitor.refresh(source: .manual)
        await service.waitUntilStarted()
        await monitor.refresh(source: .automatic)

        #expect(service.fetchCount == 1)
        service.complete(with: .success(Self.quota(available: true, remaining: Decimal(11))))
        await first
        #expect(state.status == .available)
    }

    @Test
    func manualRefreshReusesInFlightRequest() async {
        let service = SlowQuotaService()
        let monitor = monitor(service: service)

        async let first: Void = monitor.refresh(source: .manual)
        await service.waitUntilStarted()
        async let second: Void = monitor.refresh(source: .manual)
        await Task.yield()

        #expect(service.fetchCount == 1)
        service.complete(with: .success(Self.quota(available: true, remaining: Decimal(11))))
        await first
        await second
    }

    @Test
    func staleConfigurationResultDoesNotOverwriteNewState() async {
        let state = AppState()
        let service = SlowQuotaService()
        let store = FakeCredentialStore(loadResult: .success(.example(threshold: Decimal(10))))
        let monitor = QuotaMonitor(
            state: state,
            credentialStore: store,
            quotaService: service,
            notificationDispatcher: FakeNotificationDispatcher(),
            now: { Date(timeIntervalSince1970: 100) }
        )

        async let oldRefresh: Void = monitor.refresh(source: .manual)
        await service.waitUntilStarted()

        service.result = .success(Self.quota(available: true, remaining: Decimal(3)))
        store.loadResult = .success(.example(threshold: Decimal(1)))
        async let newRefresh: Void = monitor.configurationDidChange()
        await service.waitUntilStarted(count: 2)
        service.complete(at: 1, with: .success(Self.quota(available: true, remaining: Decimal(3))))
        await newRefresh

        service.complete(at: 0, with: .success(Self.quota(available: true, remaining: Decimal(3))))
        await oldRefresh

        #expect(state.status == .available)
    }

    @Test
    func configurationChangeFailureStartsFreshFailureCount() async {
        let state = AppState()
        let service = FakeQuotaService(result: .failure(QuotaErrorKind.network))
        let monitor = monitor(state: state, service: service)

        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)
        #expect(state.consecutiveFailureCount == 2)

        await monitor.configurationDidChange()

        #expect(state.consecutiveFailureCount == 1)
    }

    @Test
    func lowQuotaUnavailableAndRefreshFailureNotificationsAreDispatched() async {
        let state = AppState()
        let service = FakeQuotaService(result: .success(Self.quota(available: true, remaining: Decimal(1))))
        let dispatcher = FakeNotificationDispatcher()
        let monitor = monitor(state: state, service: service, dispatcher: dispatcher)

        await monitor.refresh(source: .manual)
        service.result = .success(Self.quota(available: false, remaining: Decimal(0)))
        await monitor.refresh(source: .manual)
        service.result = .failure(QuotaErrorKind.network)
        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)

        #expect(dispatcher.sentKinds == [.lowQuota, .unavailable, .refreshFailure])
    }

    @Test
    func configurationChangeAllowsRefreshFailureNotificationWithinOldCooldown() async {
        let service = FakeQuotaService(result: .failure(QuotaErrorKind.network))
        let dispatcher = FakeNotificationDispatcher()
        let monitor = monitor(service: service, dispatcher: dispatcher)

        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)
        await monitor.configurationDidChange()
        await monitor.refresh(source: .manual)
        await monitor.refresh(source: .manual)

        #expect(dispatcher.sentKinds == [.refreshFailure, .refreshFailure])
    }

    @Test
    func startRefreshesImmediatelyAndStopPreventsLaterTicks() async {
        let service = FakeQuotaService(result: .success(Self.quota(available: true, remaining: Decimal(11))))
        let clock = FakeMonitorClock()
        let monitor = monitor(service: service)

        await monitor.start(interval: 30, clock: clock)
        await Task.yield()
        #expect(service.fetchCount == 1)

        await clock.advance()
        await service.waitUntilFetchCount(2)
        #expect(service.fetchCount == 2)

        await monitor.stop()
        await clock.advance()
        #expect(service.fetchCount == 2)
    }

    private func monitor(
        state: AppState? = nil,
        service: QuotaFetching,
        dispatcher: NotificationDispatching = FakeNotificationDispatcher()
    ) -> QuotaMonitor {
        QuotaMonitor(
            state: state ?? AppState(),
            credentialStore: FakeCredentialStore(loadResult: .success(.example(threshold: Decimal(10)))),
            quotaService: service,
            notificationDispatcher: dispatcher,
            now: { Date(timeIntervalSince1970: 100) },
            notificationCooldown: 1800
        )
    }

    nonisolated fileprivate static func quota(available: Bool, remaining: Decimal) -> QuotaSnapshot {
        QuotaSnapshot(
            available: available,
            remaining: remaining,
            unit: "USD",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
    }
}

private extension StoredConfiguration {
    static func example(threshold: Decimal = Decimal(10)) -> StoredConfiguration {
        let configuration = try! ServiceURLNormalizer.normalize("https://example.com")
        return StoredConfiguration(
            serviceRoot: configuration.serviceRoot,
            quotaURL: configuration.quotaURL,
            email: "admin@example.com",
            apiKey: "secret",
            threshold: threshold
        )
    }
}

private final class FakeCredentialStore: CredentialLoading {
    var loadResult: Result<StoredConfiguration?, Error>

    init(loadResult: Result<StoredConfiguration?, Error>) {
        self.loadResult = loadResult
    }

    func load() throws -> StoredConfiguration? {
        try loadResult.get()
    }
}

private final class FakeQuotaService: QuotaFetching {
    var result: Result<QuotaSnapshot, Error>
    private(set) var fetchCount = 0
    private var fetchCountContinuations: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(result: Result<QuotaSnapshot, Error> = .success(QuotaMonitorTests.quota(available: true, remaining: Decimal(11)))) {
        self.result = result
    }

    func fetchQuota(
        configuration: ServiceConfiguration,
        apiKey: String,
        inspectedAPIKey: String?
    ) async throws -> QuotaSnapshot {
        fetchCount += 1
        resumeFetchCountContinuations()
        return try result.get()
    }

    func waitUntilFetchCount(_ expectedCount: Int) async {
        if fetchCount >= expectedCount {
            return
        }

        await withCheckedContinuation { continuation in
            fetchCountContinuations.append((expectedCount, continuation))
        }
    }

    private func resumeFetchCountContinuations() {
        let ready = fetchCountContinuations.filter { fetchCount >= $0.count }
        fetchCountContinuations.removeAll { fetchCount >= $0.count }
        ready.forEach { $0.continuation.resume() }
    }
}

private final class SlowQuotaService: QuotaFetching {
    private(set) var fetchCount = 0
    var result: Result<QuotaSnapshot, Error> = .success(QuotaMonitorTests.quota(available: true, remaining: Decimal(11)))
    private var startedContinuations: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var completionContinuations: [CheckedContinuation<QuotaSnapshot, Error>] = []

    func fetchQuota(
        configuration: ServiceConfiguration,
        apiKey: String,
        inspectedAPIKey: String?
    ) async throws -> QuotaSnapshot {
        fetchCount += 1
        resumeStartedContinuations()

        return try await withCheckedThrowingContinuation { continuation in
            completionContinuations.append(continuation)
        }
    }

    func waitUntilStarted(count: Int = 1) async {
        if fetchCount >= count {
            return
        }

        await withCheckedContinuation { continuation in
            startedContinuations.append((count, continuation))
        }
    }

    func complete(with result: Result<QuotaSnapshot, Error>? = nil) {
        complete(at: 0, with: result)
    }

    func complete(at index: Int, with result: Result<QuotaSnapshot, Error>? = nil) {
        let result = result ?? self.result
        let continuation = completionContinuations.remove(at: index)
        continuation.resume(with: result)
    }

    private func resumeStartedContinuations() {
        let ready = startedContinuations.filter { fetchCount >= $0.count }
        startedContinuations.removeAll { fetchCount >= $0.count }
        ready.forEach { $0.continuation.resume() }
    }
}

private final class FakeNotificationDispatcher: NotificationDispatching {
    private(set) var sentKinds: [QuotaNotificationKind] = []

    func dispatch(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async {
        sentKinds.append(kind)
    }
}

private final class FakeMonitorClock: MonitorClock {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var pendingAdvances = 0

    func sleep(for interval: TimeInterval) async {
        if pendingAdvances > 0 {
            pendingAdvances -= 1
            return
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func advance() async {
        if continuations.isEmpty {
            pendingAdvances += 1
            await Task.yield()
            return
        }

        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
        await Task.yield()
    }
}
