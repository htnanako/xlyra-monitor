import Foundation

public protocol NotificationDispatching {
    func dispatch(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async
}

public protocol NotificationAuthorizationStatusProviding {
    var isAuthorizationDenied: Bool { get }
    func requestAuthorization() async -> Bool
    func refreshAuthorizationStatus() async -> Bool
}

public final class NotificationDispatcher: NotificationDispatching, NotificationAuthorizationStatusProviding {
    private let client: NotificationClient
    private var permissionDenied = false

    public init(client: NotificationClient) {
        self.client = client
    }

    public var isAuthorizationDenied: Bool {
        permissionDenied || client.authorizationDenied
    }

    public var authorizationDenied: Bool {
        isAuthorizationDenied
    }

    public func refreshAuthorizationStatus() async -> Bool {
        let authorized = await client.refreshAuthorizationStatus()
        permissionDenied = authorized == false && client.authorizationDenied
        return authorized
    }

    public func requestAuthorization() async -> Bool {
        let authorized = await client.requestAuthorizationIfNeeded()
        permissionDenied = authorized == false
        return authorized
    }

    public func dispatch(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async {
        if permissionDenied {
            let authorized = await refreshAuthorizationStatus()
            guard authorized else {
                return
            }
        }

        guard permissionDenied == false else {
            return
        }

        let authorized = await client.requestAuthorizationIfNeeded()
        guard authorized else {
            permissionDenied = true
            return
        }

        await client.send(kind, snapshot: snapshot)
    }
}
