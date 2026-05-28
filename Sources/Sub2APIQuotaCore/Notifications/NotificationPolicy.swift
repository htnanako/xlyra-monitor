import Foundation

public enum QuotaNotificationKind: Equatable {
    case lowQuota
    case unavailable
    case refreshFailure
}

public struct NotificationPolicy {
    public var cooldown: TimeInterval
    private var lastSentAt: [QuotaNotificationKind: Date] = [:]
    private var hasSentFailureNotificationInCurrentFailurePeriod = false

    public init(cooldown: TimeInterval) {
        self.cooldown = cooldown
    }

    public mutating func notification(
        from oldStatus: QuotaStatus,
        to newStatus: QuotaStatus,
        consecutiveFailures: Int,
        now: Date
    ) -> QuotaNotificationKind? {
        if oldStatus.isAPIError == false || newStatus.isAPIError == false {
            if newStatus.isAPIError == false {
                recordRecovery()
            }
        }

        let candidate = notificationCandidate(
            from: oldStatus,
            to: newStatus,
            consecutiveFailures: consecutiveFailures
        )

        guard let candidate, canSend(candidate, now: now) else {
            return nil
        }

        lastSentAt[candidate] = now
        return candidate
    }

    public mutating func recordRecovery() {
        hasSentFailureNotificationInCurrentFailurePeriod = false
    }

    public mutating func resetFailurePeriod() {
        hasSentFailureNotificationInCurrentFailurePeriod = false
        lastSentAt[.refreshFailure] = nil
    }

    private mutating func notificationCandidate(
        from oldStatus: QuotaStatus,
        to newStatus: QuotaStatus,
        consecutiveFailures: Int
    ) -> QuotaNotificationKind? {
        switch (oldStatus, newStatus) {
        case (_, .lowQuota) where oldStatus != .lowQuota:
            return .lowQuota
        case (.available, .unavailable), (.lowQuota, .unavailable):
            return .unavailable
        case (_, .apiError) where consecutiveFailures >= 3 && hasSentFailureNotificationInCurrentFailurePeriod == false:
            hasSentFailureNotificationInCurrentFailurePeriod = true
            return .refreshFailure
        default:
            return nil
        }
    }

    private func canSend(_ kind: QuotaNotificationKind, now: Date) -> Bool {
        guard let lastSent = lastSentAt[kind] else {
            return true
        }

        return now.timeIntervalSince(lastSent) >= cooldown
    }
}
