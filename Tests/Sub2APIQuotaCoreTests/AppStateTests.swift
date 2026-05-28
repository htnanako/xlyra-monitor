import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("AppStateTests")
@MainActor
struct AppStateTests {
    @Test
    func successfulQuotaAboveThresholdIsAvailable() {
        let state = AppState()
        let quota = quota(available: true, remaining: Decimal(11))

        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)

        #expect(state.status == .available)
        #expect(state.consecutiveFailureCount == 0)
    }

    @Test
    func successfulQuotaAtThresholdIsLowQuota() {
        let state = AppState()
        let quota = quota(available: true, remaining: Decimal(10))

        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)

        #expect(state.status == .lowQuota)
    }

    @Test
    func accountPoolWarningUsesFiveHourUsageRisk() {
        let state = AppState()
        let summary = AccountPoolSummary(
            accountCount: 10,
            schedulableCount: 10,
            currentConcurrency: 0,
            concurrencyLimit: 100,
            remaining5hAccounts: Decimal(string: "6.72")!,
            remaining7dAccounts: Decimal(1),
            used5hPercent: Decimal(4),
            used7dPercent: Decimal(90)
        )
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "6.72")!,
            unit: "账号/7d",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date()
        )

        state.applySuccess(snapshot, threshold: Decimal(10), requestDuration: 0.2)

        #expect(state.status == .available)
    }

    @Test
    func failureKeepsLastSuccessfulQuota() {
        let state = AppState()
        let quota = quota(available: true, remaining: Decimal(11))
        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)

        state.applyFailure(.network)

        #expect(state.status == .apiError(.network))
        #expect(state.quotaSnapshot == quota)
        #expect(state.consecutiveFailureCount == 1)
    }

    @Test
    func unavailableQuotaMapsToUnavailable() {
        let state = AppState()
        let quota = quota(available: false, remaining: Decimal(0))

        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)

        #expect(state.status == .unavailable)
        #expect(state.lastError == nil)
    }

    @Test
    func applyNotConfiguredResetsState() {
        let state = AppState()
        state.applyFailure(.network)

        state.applyNotConfigured()

        #expect(state.status == .notConfigured)
        #expect(state.quotaSnapshot == nil)
        #expect(state.lastError == nil)
        #expect(state.consecutiveFailureCount == 0)
    }

    @Test
    func successClearsPreviousError() {
        let state = AppState()
        state.applyFailure(.network)
        let quota = quota(available: true, remaining: Decimal(11))

        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)

        #expect(state.lastError == nil)
    }

    @Test
    func requestDurationAndInFlightStateAreTracked() {
        let state = AppState()
        state.setRequestInFlight(true)
        #expect(state.isRequestInFlight == true)

        let quota = quota(available: true, remaining: Decimal(11))
        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.42)

        #expect(state.isRequestInFlight == false)
        #expect(state.lastRequestDuration == 0.42)
    }

    @Test
    func quotaRefreshKeepsAccountModelCheckResults() {
        let state = AppState()
        let result = ModelDegradationCheckResult(
            targetModel: "gpt-4.1",
            responseModel: "gpt-4.1",
            score: 100,
            status: .normal,
            latency: 0.5,
            checkedAt: Date(),
            probes: []
        )
        state.applyModelCheckResult(result, accountID: 7)

        state.applySuccess(quota(available: true, remaining: Decimal(11)), threshold: Decimal(10), requestDuration: 0.2)
        #expect(state.modelCheckResultsByAccountID[7] == result)

        state.applyFailure(.network)
        #expect(state.modelCheckResultsByAccountID[7] == result)
    }

    @Test
    func tracksPriorityUpdateStateByAccount() {
        let state = AppState()

        state.setPriorityUpdateInFlight(true, accountID: 7)
        #expect(state.priorityUpdateInFlightAccountIDs.contains(7))
        #expect(state.priorityUpdateErrorsByAccountID[7] == nil)

        state.applyPriorityUpdateError("网络异常", accountID: 7)
        #expect(state.priorityUpdateInFlightAccountIDs.contains(7) == false)
        #expect(state.priorityUpdateErrorsByAccountID[7] == "网络异常")

        state.setPriorityUpdateInFlight(true, accountID: 7)
        #expect(state.priorityUpdateErrorsByAccountID[7] == nil)

        state.applyPriorityUpdateSuccess(accountID: 7)
        #expect(state.priorityUpdateInFlightAccountIDs.contains(7) == false)
        #expect(state.priorityUpdateErrorsByAccountID[7] == nil)
    }

    @Test
    func recordsKeyAvailabilitySamplesWithinRollingWindow() {
        let state = AppState()
        let now = Date(timeIntervalSince1970: 24 * 60 * 60)

        state.setKeyAvailabilityCheckInFlight(true, accountID: 7)
        state.applyKeyAvailabilityResult(
            KeyAvailabilityProbeResult(
                accountID: 7,
                checkedAt: now.addingTimeInterval(-25 * 60 * 60),
                isAvailable: true,
                latency: 0.2
            )
        )
        state.applyKeyAvailabilityResult(
            KeyAvailabilityProbeResult(
                accountID: 7,
                checkedAt: now,
                isAvailable: false,
                latency: 0.4
            )
        )

        let samples = state.keyAvailabilitySamplesByAccountID[7] ?? []
        #expect(samples.count == 1)
        #expect(samples.first?.isAvailable == false)
        #expect(samples.first?.latency == 0.4)
        #expect(state.keyAvailabilityInFlightAccountIDs.contains(7) == false)
    }

    @Test
    func resetFailureTrackingDoesNotClearLastSuccessfulQuota() {
        let state = AppState()
        let quota = quota(available: true, remaining: Decimal(11))
        state.applySuccess(quota, threshold: Decimal(10), requestDuration: 0.2)
        state.applyFailure(.network)

        state.resetFailureTracking()

        #expect(state.consecutiveFailureCount == 0)
        #expect(state.quotaSnapshot == quota)
        #expect(state.status == .apiError(.network))
    }

    private func quota(available: Bool, remaining: Decimal) -> QuotaSnapshot {
        QuotaSnapshot(
            available: available,
            remaining: remaining,
            unit: "USD",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date()
        )
    }
}
