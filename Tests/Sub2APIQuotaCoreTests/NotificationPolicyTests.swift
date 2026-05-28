import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("NotificationPolicyTests")
struct NotificationPolicyTests {
    @Test
    func anyNonLowQuotaStateEnteringLowQuotaNotifies() {
        var policy = NotificationPolicy(cooldown: 1800)
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.notification(from: .notConfigured, to: .lowQuota, consecutiveFailures: 0, now: now) == .lowQuota)
        #expect(policy.notification(from: .available, to: .lowQuota, consecutiveFailures: 0, now: now.addingTimeInterval(1801)) == .lowQuota)
        #expect(policy.notification(from: .apiError(.network), to: .lowQuota, consecutiveFailures: 0, now: now.addingTimeInterval(3602)) == .lowQuota)
    }

    @Test
    func lowQuotaToLowQuotaDoesNotNotify() {
        var policy = NotificationPolicy(cooldown: 1800)

        #expect(policy.notification(from: .lowQuota, to: .lowQuota, consecutiveFailures: 0, now: Date()) == nil)
    }

    @Test
    func unavailableTransitionsFromAvailableOrLowQuotaNotify() {
        var policy = NotificationPolicy(cooldown: 1800)
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.notification(from: .available, to: .unavailable, consecutiveFailures: 0, now: now) == .unavailable)
        #expect(policy.notification(from: .lowQuota, to: .unavailable, consecutiveFailures: 0, now: now.addingTimeInterval(1801)) == .unavailable)
    }

    @Test
    func refreshFailureNotifiesOncePerContinuousFailurePeriod() {
        var policy = NotificationPolicy(cooldown: 1800)
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.notification(from: .available, to: .apiError(.network), consecutiveFailures: 2, now: now) == nil)
        #expect(policy.notification(from: .apiError(.network), to: .apiError(.network), consecutiveFailures: 3, now: now) == .refreshFailure)
        #expect(policy.notification(from: .apiError(.network), to: .apiError(.network), consecutiveFailures: 4, now: now.addingTimeInterval(3600)) == nil)

        policy.recordRecovery()

        #expect(policy.notification(from: .available, to: .apiError(.network), consecutiveFailures: 3, now: now.addingTimeInterval(7200)) == .refreshFailure)
    }

    @Test
    func cooldownSuppressesRepeatedLowQuotaNotification() {
        var policy = NotificationPolicy(cooldown: 1800)
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.notification(from: .available, to: .lowQuota, consecutiveFailures: 0, now: now) == .lowQuota)
        #expect(policy.notification(from: .available, to: .lowQuota, consecutiveFailures: 0, now: now.addingTimeInterval(120)) == nil)
        #expect(policy.notification(from: .available, to: .lowQuota, consecutiveFailures: 0, now: now.addingTimeInterval(1801)) == .lowQuota)
    }

    @Test
    func resetFailurePeriodAllowsImmediateRefreshFailureNotification() {
        var policy = NotificationPolicy(cooldown: 1800)
        let now = Date(timeIntervalSince1970: 100)

        #expect(policy.notification(from: .available, to: .apiError(.network), consecutiveFailures: 3, now: now) == .refreshFailure)
        policy.resetFailurePeriod()
        #expect(policy.notification(from: .available, to: .apiError(.network), consecutiveFailures: 3, now: now.addingTimeInterval(1)) == .refreshFailure)
    }
}
