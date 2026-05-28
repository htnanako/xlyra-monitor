import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var status: QuotaStatus = .notConfigured
    @Published public private(set) var quotaSnapshot: QuotaSnapshot?
    @Published public private(set) var lastError: QuotaErrorKind?
    @Published public private(set) var lastRequestDuration: TimeInterval?
    @Published public private(set) var isRequestInFlight = false
    @Published public private(set) var consecutiveFailureCount = 0
    @Published public private(set) var isModelCheckInFlight = false
    @Published public private(set) var modelCheckResult: ModelDegradationCheckResult?
    @Published public private(set) var modelCheckError: String?
    @Published public private(set) var modelCheckInFlightAccountIDs: Set<Int> = []
    @Published public private(set) var modelCheckResultsByAccountID: [Int: ModelDegradationCheckResult] = [:]
    @Published public private(set) var modelCheckErrorsByAccountID: [Int: String] = [:]
    @Published public private(set) var priorityUpdateInFlightAccountIDs: Set<Int> = []
    @Published public private(set) var priorityUpdateErrorsByAccountID: [Int: String] = [:]
    @Published public private(set) var keyAvailabilitySamplesByAccountID: [Int: [KeyAvailabilitySample]] = [:]
    @Published public private(set) var keyAvailabilityInFlightAccountIDs: Set<Int> = []

    public init() {}

    public func applyNotConfigured() {
        status = .notConfigured
        quotaSnapshot = nil
        lastError = nil
        lastRequestDuration = nil
        isRequestInFlight = false
        consecutiveFailureCount = 0
    }

    public func applySuccess(
        _ quotaSnapshot: QuotaSnapshot,
        threshold: Decimal,
        requestDuration: TimeInterval
    ) {
        self.quotaSnapshot = quotaSnapshot
        lastError = nil
        lastRequestDuration = requestDuration
        isRequestInFlight = false
        consecutiveFailureCount = 0

        if quotaSnapshot.available == false {
            status = .unavailable
        } else if let poolSummary = quotaSnapshot.poolSummary {
            status = poolSummary.isFiveHourLowQuota ? .lowQuota : .available
        } else if quotaSnapshot.remaining <= threshold {
            status = .lowQuota
        } else {
            status = .available
        }
    }

    public func applyFailure(_ error: QuotaErrorKind) {
        status = .apiError(error)
        lastError = error
        isRequestInFlight = false
        consecutiveFailureCount += 1
    }

    public func resetFailureTracking() {
        consecutiveFailureCount = 0
    }

    public func setRequestInFlight(_ isRequestInFlight: Bool) {
        self.isRequestInFlight = isRequestInFlight
    }

    public func setModelCheckInFlight(_ isModelCheckInFlight: Bool) {
        self.isModelCheckInFlight = isModelCheckInFlight
        if isModelCheckInFlight {
            modelCheckError = nil
        }
    }

    public func applyModelCheckResult(_ result: ModelDegradationCheckResult) {
        modelCheckResult = result
        modelCheckError = nil
        isModelCheckInFlight = false
    }

    public func applyModelCheckError(_ message: String) {
        modelCheckError = message
        isModelCheckInFlight = false
    }

    public func setModelCheckInFlight(_ isInFlight: Bool, accountID: Int) {
        if isInFlight {
            modelCheckInFlightAccountIDs.insert(accountID)
            modelCheckErrorsByAccountID[accountID] = nil
        } else {
            modelCheckInFlightAccountIDs.remove(accountID)
        }
    }

    public func applyModelCheckResult(_ result: ModelDegradationCheckResult, accountID: Int) {
        modelCheckResultsByAccountID[accountID] = result
        modelCheckErrorsByAccountID[accountID] = nil
        modelCheckInFlightAccountIDs.remove(accountID)
    }

    public func applyModelCheckError(_ message: String, accountID: Int) {
        modelCheckErrorsByAccountID[accountID] = message
        modelCheckInFlightAccountIDs.remove(accountID)
    }

    public func setPriorityUpdateInFlight(_ isInFlight: Bool, accountID: Int) {
        if isInFlight {
            priorityUpdateInFlightAccountIDs.insert(accountID)
            priorityUpdateErrorsByAccountID[accountID] = nil
        } else {
            priorityUpdateInFlightAccountIDs.remove(accountID)
        }
    }

    public func applyPriorityUpdateSuccess(accountID: Int) {
        priorityUpdateErrorsByAccountID[accountID] = nil
        priorityUpdateInFlightAccountIDs.remove(accountID)
    }

    public func applyPriorityUpdateError(_ message: String, accountID: Int) {
        priorityUpdateErrorsByAccountID[accountID] = message
        priorityUpdateInFlightAccountIDs.remove(accountID)
    }

    public func setKeyAvailabilityCheckInFlight(_ isInFlight: Bool, accountID: Int) {
        if isInFlight {
            keyAvailabilityInFlightAccountIDs.insert(accountID)
        } else {
            keyAvailabilityInFlightAccountIDs.remove(accountID)
        }
    }

    public func applyKeyAvailabilityResult(
        _ result: KeyAvailabilityProbeResult,
        window: TimeInterval = 24 * 60 * 60
    ) {
        let sample = KeyAvailabilitySample(
            accountID: result.accountID,
            checkedAt: result.checkedAt,
            isAvailable: result.isAvailable,
            latency: result.latency
        )
        let oldestAllowed = result.checkedAt.addingTimeInterval(-window)
        var samples = keyAvailabilitySamplesByAccountID[result.accountID] ?? []
        samples.append(sample)
        keyAvailabilitySamplesByAccountID[result.accountID] = Array(samples
            .filter { $0.checkedAt >= oldestAllowed }
            .suffix(288))
        keyAvailabilityInFlightAccountIDs.remove(result.accountID)
    }

    public func applyKeyAvailabilityFailure(accountID: Int, checkedAt: Date = Date()) {
        applyKeyAvailabilityResult(
            KeyAvailabilityProbeResult(
                accountID: accountID,
                checkedAt: checkedAt,
                isAvailable: false,
                latency: nil
            )
        )
    }
}
