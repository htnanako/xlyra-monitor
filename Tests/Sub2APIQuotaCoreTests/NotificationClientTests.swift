import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("NotificationClientTests")
struct NotificationClientTests {
    @Test
    func allowedAuthorizationSendsCurrentEvent() async {
        let client = FakeNotificationClient(authorizationResult: true)
        let dispatcher = NotificationDispatcher(client: client)

        await dispatcher.dispatch(.lowQuota, snapshot: nil)

        #expect(client.sentKinds == [.lowQuota])
    }

    @Test
    func deniedAuthorizationDoesNotSendAndExposesDeniedState() async {
        let client = FakeNotificationClient(authorizationResult: false)
        let dispatcher = NotificationDispatcher(client: client)

        await dispatcher.dispatch(.lowQuota, snapshot: nil)

        #expect(dispatcher.authorizationDenied == true)
        #expect(client.authorizationDenied == true)
        #expect(client.sentKinds.isEmpty)
    }

    @Test
    func deniedAuthorizationIsNotRequestedRepeatedly() async {
        let client = FakeNotificationClient(authorizationResult: false)
        let dispatcher = NotificationDispatcher(client: client)

        await dispatcher.dispatch(.lowQuota, snapshot: nil)
        await dispatcher.dispatch(.unavailable, snapshot: nil)

        #expect(client.authorizationRequestCount == 1)
        #expect(client.sentKinds.isEmpty)
    }

    @Test
    func deniedAuthorizationCanRecoverAfterSystemSettingsChange() async {
        let client = FakeNotificationClient(authorizationResult: false)
        let dispatcher = NotificationDispatcher(client: client)

        await dispatcher.dispatch(.lowQuota, snapshot: nil)
        client.authorizationResult = true
        client.isAuthorized = true
        await dispatcher.dispatch(.lowQuota, snapshot: nil)

        #expect(dispatcher.authorizationDenied == false)
        #expect(client.sentKinds == [.lowQuota])
    }

    @Test
    func alreadyAuthorizedDoesNotRequestAgainAndSendsCurrentEvent() async {
        let client = FakeNotificationClient(authorizationResult: true)
        client.isAuthorized = true
        let dispatcher = NotificationDispatcher(client: client)

        await dispatcher.dispatch(.lowQuota, snapshot: nil)

        #expect(client.authorizationRequestCount == 0)
        #expect(client.sentKinds == [.lowQuota])
    }
}

final class FakeNotificationClient: NotificationClient {
    var authorizationResult: Bool
    var isAuthorized = false
    var authorizationRequestCount = 0
    var sentKinds: [QuotaNotificationKind] = []
    private(set) var authorizationDenied = false

    init(authorizationResult: Bool) {
        self.authorizationResult = authorizationResult
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        if isAuthorized {
            authorizationDenied = false
            return true
        }

        authorizationRequestCount += 1
        isAuthorized = authorizationResult
        authorizationDenied = authorizationResult == false
        return authorizationResult
    }

    func refreshAuthorizationStatus() async -> Bool {
        authorizationDenied = isAuthorized == false
        return isAuthorized
    }

    func send(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async {
        sentKinds.append(kind)
    }
}
