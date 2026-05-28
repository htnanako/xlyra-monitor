import Foundation
import UserNotifications

public protocol NotificationClient {
    func requestAuthorizationIfNeeded() async -> Bool
    func refreshAuthorizationStatus() async -> Bool
    func send(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async
    var authorizationDenied: Bool { get }
}

public final class UserNotificationClient: NotificationClient {
    private let center: UNUserNotificationCenter
    private var cachedAuthorizationDenied = false

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public var authorizationDenied: Bool {
        cachedAuthorizationDenied
    }

    public func refreshAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            cachedAuthorizationDenied = false
            return true
        case .denied:
            cachedAuthorizationDenied = true
            return false
        case .notDetermined:
            cachedAuthorizationDenied = false
            return false
        @unknown default:
            cachedAuthorizationDenied = true
            return false
        }
    }

    public func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            cachedAuthorizationDenied = false
            return true
        case .denied:
            cachedAuthorizationDenied = true
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                cachedAuthorizationDenied = granted == false
                return granted
            } catch {
                cachedAuthorizationDenied = true
                return false
            }
        @unknown default:
            cachedAuthorizationDenied = true
            return false
        }
    }

    public func send(_ kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) async {
        let content = UNMutableNotificationContent()
        content.title = title(for: kind)
        content.body = body(for: kind, snapshot: snapshot)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sub2api-quota-\(kind.identifier)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    private func title(for kind: QuotaNotificationKind) -> String {
        switch kind {
        case .lowQuota:
            return "Sub2API 额度偏低"
        case .unavailable:
            return "Sub2API 额度不可用"
        case .refreshFailure:
            return "Sub2API 刷新失败"
        }
    }

    private func body(for kind: QuotaNotificationKind, snapshot: QuotaSnapshot?) -> String {
        switch kind {
        case .lowQuota:
            if let snapshot {
                return "当前剩余额度 \(snapshot.remaining) \(snapshot.displayUnit)"
            }
            return "当前额度低于提醒阈值"
        case .unavailable:
            return "接口返回额度不可用，请检查服务状态"
        case .refreshFailure:
            return "连续多次刷新失败，请检查网络或服务配置"
        }
    }
}

private extension QuotaNotificationKind {
    var identifier: String {
        switch self {
        case .lowQuota:
            return "low-quota"
        case .unavailable:
            return "unavailable"
        case .refreshFailure:
            return "refresh-failure"
        }
    }
}
