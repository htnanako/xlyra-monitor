import AppKit
import Combine
import Foundation
import SwiftUI

struct XlyraSiteHealth: Decodable, Equatable {
    let success: Bool?
    let statusCode: Int?
    let latencyMS: Int?
    let errorType: String?
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case statusCode = "status_code"
        case latencyMS = "latency_ms"
        case errorType = "error_type"
        case checkedAt = "checked_at"
    }
}

struct XlyraSiteRow: Decodable, Equatable, Identifiable {
    let name: String
    let slug: String
    let type: String
    let status: String
    let enabled: Bool
    let priority: Double
    let validationOK: Bool?
    let syncStatus: String?
    let apiKeyCount: Int
    let modelCount: Int
    let lastSyncedAt: String?
    let tokens24h: Int
    let cost24h: Double
    let recentHealth: XlyraSiteHealth?
    let isCoolingDown: Bool

    var id: String { slug }

    init(
        name: String,
        slug: String,
        type: String,
        status: String,
        enabled: Bool,
        priority: Double,
        validationOK: Bool?,
        syncStatus: String?,
        apiKeyCount: Int,
        modelCount: Int,
        lastSyncedAt: String?,
        tokens24h: Int,
        cost24h: Double,
        recentHealth: XlyraSiteHealth?,
        isCoolingDown: Bool = false
    ) {
        self.name = name
        self.slug = slug
        self.type = type
        self.status = status
        self.enabled = enabled
        self.priority = priority
        self.validationOK = validationOK
        self.syncStatus = syncStatus
        self.apiKeyCount = apiKeyCount
        self.modelCount = modelCount
        self.lastSyncedAt = lastSyncedAt
        self.tokens24h = tokens24h
        self.cost24h = cost24h
        self.recentHealth = recentHealth
        self.isCoolingDown = isCoolingDown
    }

    var isHealthy: Bool {
        enabled
            && isCoolingDown == false
            && isServiceStatusUsable
            && validationOK != false
            && hasExplicitSyncFailure == false
            && recentHealth?.success != false
    }

    var stateText: String {
        if enabled == false { return "已停用" }
        if isCoolingDown { return "冷却中" }
        if isServiceStatusUsable == false { return status }
        if validationOK == false { return "验证异常" }
        if hasExplicitSyncFailure { return syncStatus ?? "同步异常" }
        if recentHealth?.success == false { return "健康异常" }
        return "可用"
    }

    private var isServiceStatusUsable: Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return true }
        return ["active", "enabled", "ok", "healthy", "available", "ready"].contains(normalized)
    }

    private var hasExplicitSyncFailure: Bool {
        guard let syncStatus else { return false }
        let normalized = syncStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return false }
        return ["error", "failed", "failure", "fail", "out_of_sync", "unsynced", "not_synced", "stale"].contains(normalized)
    }

    enum CodingKeys: String, CodingKey {
        case name, slug, type, status, enabled, priority
        case validationOK = "validation_ok"
        case syncStatus = "sync_status"
        case apiKeyCount = "api_key_count"
        case modelCount = "model_count"
        case lastSyncedAt = "last_synced_at"
        case tokens24h
        case cost24h
        case recentHealth = "recent_health"
        case isCoolingDown = "is_cooling_down"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        priority = try container.decode(Double.self, forKey: .priority)
        validationOK = try container.decodeIfPresent(Bool.self, forKey: .validationOK)
        syncStatus = try container.decodeIfPresent(String.self, forKey: .syncStatus)
        apiKeyCount = try container.decode(Int.self, forKey: .apiKeyCount)
        modelCount = try container.decode(Int.self, forKey: .modelCount)
        lastSyncedAt = try container.decodeIfPresent(String.self, forKey: .lastSyncedAt)
        tokens24h = try container.decode(Int.self, forKey: .tokens24h)
        cost24h = try container.decode(Double.self, forKey: .cost24h)
        recentHealth = try container.decodeIfPresent(XlyraSiteHealth.self, forKey: .recentHealth)
        isCoolingDown = try container.decodeIfPresent(Bool.self, forKey: .isCoolingDown) ?? false
    }
}

struct XlyraSiteSummary: Decodable, Equatable {
    let total: Int
    let healthy: Int
    let rows: [XlyraSiteRow]
}

struct XlyraOAuthRow: Decodable, Equatable, Identifiable {
    let id: String
    let provider: String
    let siteName: String?
    let siteSlug: String?
    let status: String
    let accountID: String
    let email: String
    let planType: String?
    let available: Bool?
    let limitReached: Bool?
    let fiveHourUsedPercent: Double?
    let fiveHourRemainingPercent: Double?
    let fiveHourResetAt: Double?
    let weeklyUsedPercent: Double?
    let weeklyRemainingPercent: Double?
    let weeklyResetAt: Double?
    let creditsBalance: String?
    let creditsUnlimited: Bool?
    let lastRefreshAt: String?
    let lastSyncAt: String?
    let expiresAt: String?
    let tokens24h: Int
    let cost24h: Double
    let priority: Double
    let isCoolingDown: Bool

    var isHealthy: Bool {
        isConnectionUsable && isCoolingDown == false && available != false && limitReached != true
    }

    init(
        id: String,
        provider: String,
        siteName: String?,
        siteSlug: String?,
        status: String,
        accountID: String,
        email: String,
        planType: String?,
        available: Bool?,
        limitReached: Bool?,
        fiveHourUsedPercent: Double?,
        fiveHourRemainingPercent: Double?,
        fiveHourResetAt: Double?,
        weeklyUsedPercent: Double?,
        weeklyRemainingPercent: Double?,
        weeklyResetAt: Double?,
        creditsBalance: String?,
        creditsUnlimited: Bool?,
        lastRefreshAt: String?,
        lastSyncAt: String?,
        expiresAt: String?,
        tokens24h: Int,
        cost24h: Double,
        priority: Double = 0,
        isCoolingDown: Bool = false
    ) {
        self.id = id
        self.provider = provider
        self.siteName = siteName
        self.siteSlug = siteSlug
        self.status = status
        self.accountID = accountID
        self.email = email
        self.planType = planType
        self.available = available
        self.limitReached = limitReached
        self.fiveHourUsedPercent = fiveHourUsedPercent
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.fiveHourResetAt = fiveHourResetAt
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.weeklyResetAt = weeklyResetAt
        self.creditsBalance = creditsBalance
        self.creditsUnlimited = creditsUnlimited
        self.lastRefreshAt = lastRefreshAt
        self.lastSyncAt = lastSyncAt
        self.expiresAt = expiresAt
        self.tokens24h = tokens24h
        self.cost24h = cost24h
        self.priority = priority
        self.isCoolingDown = isCoolingDown
    }

    var displayName: String {
        if email.isEmpty == false { return email }
        if accountID.isEmpty == false { return accountID }
        return siteName ?? provider
    }

    var quotaText: String {
        if let fiveHourRemainingDisplayPercent, let weeklyRemainingDisplayPercent {
            return "5h 剩 \(Self.percentText(fiveHourRemainingDisplayPercent)) · 7d 剩 \(Self.percentText(weeklyRemainingDisplayPercent))"
        }
        if let fiveHourUsedDisplayPercent, let weeklyUsedDisplayPercent {
            return "5h 用 \(Self.percentText(fiveHourUsedDisplayPercent)) · 7d 用 \(Self.percentText(weeklyUsedDisplayPercent))"
        }
        if creditsUnlimited == true {
            return "Credits 不限"
        }
        if let creditsBalance {
            return "Credits \(creditsBalance)"
        }
        return "--"
    }

    var planDisplayText: String {
        guard let planType = planType?.trimmingCharacters(in: .whitespacesAndNewlines),
              planType.isEmpty == false else {
            return provider.uppercased()
        }
        switch planType.lowercased() {
        case "plus":
            return "PLUS"
        case "team":
            return "TEAM"
        case "pro":
            return "PRO"
        default:
            return planType.uppercased()
        }
    }

    var fiveHourUsedDisplayPercent: Double? {
        Self.usedPercent(used: fiveHourUsedPercent, remaining: fiveHourRemainingPercent)
    }

    var fiveHourRemainingDisplayPercent: Double? {
        Self.remainingPercent(used: fiveHourUsedPercent, remaining: fiveHourRemainingPercent)
    }

    var weeklyUsedDisplayPercent: Double? {
        Self.usedPercent(used: weeklyUsedPercent, remaining: weeklyRemainingPercent)
    }

    var weeklyRemainingDisplayPercent: Double? {
        Self.remainingPercent(used: weeklyUsedPercent, remaining: weeklyRemainingPercent)
    }

    var stateText: String {
        if isCoolingDown { return "冷却中" }
        if isConnectionUsable == false { return status }
        if limitReached == true { return "额度触顶" }
        if available == false { return "不可用" }
        return "可用"
    }

    func quotaProgressColorName(usedPercent: Double?) -> String {
        if available == false || isConnectionUsable == false || isCoolingDown {
            return "gray"
        }
        return XlyraOAuthCapacity.riskColorName(for: usedPercent)
    }

    private var isConnectionUsable: Bool {
        ["connected", "active", "ok", "healthy", "available", "ready"].contains(status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func usedPercent(used: Double?, remaining: Double?) -> Double? {
        if let (usedPercent, _) = normalizedPercentPair(used: used, remaining: remaining) {
            return boundedPercent(usedPercent)
        }
        if let usedPercent = normalizedPercent(used) {
            return boundedPercent(usedPercent)
        }
        if let remainingPercent = normalizedPercent(remaining) {
            return boundedPercent(100 - remainingPercent)
        }
        return nil
    }

    private static func remainingPercent(used: Double?, remaining: Double?) -> Double? {
        if let (_, remainingPercent) = normalizedPercentPair(used: used, remaining: remaining) {
            return boundedPercent(remainingPercent)
        }
        if let remainingPercent = normalizedPercent(remaining) {
            return boundedPercent(remainingPercent)
        }
        if let usedPercent = normalizedPercent(used) {
            return boundedPercent(100 - usedPercent)
        }
        return nil
    }

    private static func normalizedPercentPair(used: Double?, remaining: Double?) -> (Double, Double)? {
        guard let used, let remaining else {
            return nil
        }

        let pairs = percentCandidates(used).flatMap { usedCandidate in
            percentCandidates(remaining).map { remainingCandidate in
                (usedCandidate, remainingCandidate)
            }
        }
        return pairs.min { lhs, rhs in
            abs((lhs.0 + lhs.1) - 100) < abs((rhs.0 + rhs.1) - 100)
        }
    }

    private static func normalizedPercent(_ value: Double?) -> Double? {
        guard let value else { return nil }
        if value > 0, value <= 1 {
            return value * 100
        }
        return value
    }

    private static func percentCandidates(_ value: Double) -> [Double] {
        guard value > 0, value <= 1 else {
            return [value]
        }
        return [value * 100, value]
    }

    private static func boundedPercent(_ value: Double) -> Double {
        let clamped = max(0, min(100, value))
        return (clamped * 10).rounded() / 10
    }

    private static func percentText(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", rounded)
    }

    enum CodingKeys: String, CodingKey {
        case id, provider, status
        case siteName = "site_name"
        case siteSlug = "site_slug"
        case accountID = "account_id"
        case email
        case planType = "plan_type"
        case available
        case limitReached = "limit_reached"
        case fiveHourUsedPercent = "five_hour_used_percent"
        case fiveHourRemainingPercent = "five_hour_remaining_percent"
        case fiveHourResetAt = "five_hour_reset_at"
        case weeklyUsedPercent = "weekly_used_percent"
        case weeklyRemainingPercent = "weekly_remaining_percent"
        case weeklyResetAt = "weekly_reset_at"
        case creditsBalance = "credits_balance"
        case creditsUnlimited = "credits_unlimited"
        case lastRefreshAt = "last_refresh_at"
        case lastSyncAt = "last_sync_at"
        case expiresAt = "expires_at"
        case tokens24h
        case cost24h
        case priority
        case isCoolingDown = "is_cooling_down"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(String.self, forKey: .provider)
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        siteSlug = try container.decodeIfPresent(String.self, forKey: .siteSlug)
        status = try container.decode(String.self, forKey: .status)
        accountID = try container.decode(String.self, forKey: .accountID)
        email = try container.decode(String.self, forKey: .email)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        available = try container.decodeIfPresent(Bool.self, forKey: .available)
        limitReached = try container.decodeIfPresent(Bool.self, forKey: .limitReached)
        fiveHourUsedPercent = try container.decodeIfPresent(Double.self, forKey: .fiveHourUsedPercent)
        fiveHourRemainingPercent = try container.decodeIfPresent(Double.self, forKey: .fiveHourRemainingPercent)
        fiveHourResetAt = try container.decodeIfPresent(Double.self, forKey: .fiveHourResetAt)
        weeklyUsedPercent = try container.decodeIfPresent(Double.self, forKey: .weeklyUsedPercent)
        weeklyRemainingPercent = try container.decodeIfPresent(Double.self, forKey: .weeklyRemainingPercent)
        weeklyResetAt = try container.decodeIfPresent(Double.self, forKey: .weeklyResetAt)
        creditsBalance = try container.decodeIfPresent(String.self, forKey: .creditsBalance)
        creditsUnlimited = try container.decodeIfPresent(Bool.self, forKey: .creditsUnlimited)
        lastRefreshAt = try container.decodeIfPresent(String.self, forKey: .lastRefreshAt)
        lastSyncAt = try container.decodeIfPresent(String.self, forKey: .lastSyncAt)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        tokens24h = try container.decode(Int.self, forKey: .tokens24h)
        cost24h = try container.decode(Double.self, forKey: .cost24h)
        priority = try container.decodeIfPresent(Double.self, forKey: .priority) ?? 0
        isCoolingDown = try container.decodeIfPresent(Bool.self, forKey: .isCoolingDown) ?? false
    }
}

struct XlyraOAuthSummary: Decodable, Equatable {
    let total: Int
    let healthy: Int
    let limited: Int
    let rows: [XlyraOAuthRow]

    var liveTotal: Int {
        rows.isEmpty ? total : rows.count
    }

    var liveHealthy: Int {
        rows.isEmpty ? healthy : rows.filter(\.isHealthy).count
    }

    var liveLimited: Int {
        rows.isEmpty ? limited : rows.filter { $0.limitReached == true }.count
    }

    var fiveHourCapacity: XlyraOAuthCapacity {
        capacity { $0.fiveHourUsedDisplayPercent }
    }

    var weeklyCapacity: XlyraOAuthCapacity {
        capacity { $0.weeklyUsedDisplayPercent }
    }

    private func capacity(_ usedPercent: (XlyraOAuthRow) -> Double?) -> XlyraOAuthCapacity {
        let usedPercents = rows.compactMap { account -> Double? in
            guard account.isHealthy, let percent = usedPercent(account) else {
                return nil
            }
            return max(0, min(100, percent))
        }
        return XlyraOAuthCapacity(
            averageUsedPercent: usedPercents.isEmpty ? nil : usedPercents.reduce(0, +) / Double(usedPercents.count)
        )
    }
}

struct XlyraOAuthCapacity: Equatable {
    let averageUsedPercent: Double?

    var usedFraction: Double {
        guard let averageUsedPercent else {
            return 0
        }
        return max(0, min(1, averageUsedPercent / 100))
    }

    var remainingFraction: Double? {
        guard let averageUsedPercent else {
            return nil
        }
        return max(0, min(1, 1 - averageUsedPercent / 100))
    }

    var shortText: String {
        guard let averageUsedPercent else {
            return "--"
        }
        let rounded = (averageUsedPercent * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", rounded)
    }

    var riskColorName: String {
        Self.riskColorName(for: averageUsedPercent)
    }

    static func riskColorName(for usedPercent: Double?) -> String {
        guard let usedPercent else { return "gray" }
        switch usedPercent {
        case 90...:
            return "red"
        case 80..<90:
            return "orange"
        case 60..<80:
            return "yellow"
        default:
            return "green"
        }
    }
}

struct XlyraAPIKeyRow: Decodable, Equatable, Identifiable {
    let name: String
    let maskedKey: String
    let copyableKey: String?
    let status: String
    let quotaLimit: Double?
    let quotaUsed: Double
    let quotaUnlimited: Bool
    let lastUsedAt: String?
    let expiresAt: String?

    var id: String { "\(name)-\(maskedKey)" }

    var copyText: String {
        copyableKey ?? maskedKey
    }

    var isActive: Bool { status == "active" }

    var isExhausted: Bool {
        guard quotaUnlimited == false, let quotaLimit else { return false }
        return quotaUsed >= quotaLimit
    }

    var quotaText: String {
        if quotaUnlimited { return "不限额 · 已用 $\(Self.moneyFormatter.string(from: NSNumber(value: quotaUsed)) ?? "0")" }
        let limit = quotaLimit ?? 0
        return "$\(Self.moneyFormatter.string(from: NSNumber(value: quotaUsed)) ?? "0") / $\(Self.moneyFormatter.string(from: NSNumber(value: limit)) ?? "0")"
    }

    enum CodingKeys: String, CodingKey {
        case name, status
        case maskedKey = "masked_key"
        case copyableKey = "copyable_key"
        case quotaLimit = "quota_limit"
        case quotaUsed = "quota_used"
        case quotaUnlimited = "quota_unlimited"
        case lastUsedAt = "last_used_at"
        case expiresAt = "expires_at"
    }

    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct XlyraAPIKeySummary: Decodable, Equatable {
    let total: Int
    let active: Int
    let exhausted: Int
    let rows: [XlyraAPIKeyRow]
}

struct XlyraRequestSummary: Decodable, Equatable {
    let total: Int
    let lastHour: Int
    let last24h: Int
    let ok24h: Int
    let failed24h: Int
    let avgLatency24h: Int?

    var successRate24h: Double? {
        guard last24h > 0 else { return nil }
        return Double(ok24h) / Double(last24h)
    }

    enum CodingKeys: String, CodingKey {
        case total
        case lastHour = "last_hour"
        case last24h = "last_24h"
        case ok24h = "ok_24h"
        case failed24h = "failed_24h"
        case avgLatency24h = "avg_latency_24h"
    }
}

struct XlyraUsageSummary: Decodable, Equatable {
    let tokens24h: Int
    let cost24h: Double

    enum CodingKeys: String, CodingKey {
        case tokens24h = "tokens_24h"
        case cost24h = "cost_24h"
    }
}

struct XlyraErrorRow: Decodable, Equatable, Identifiable {
    let errorType: String
    let count: Int

    var id: String { errorType }

    enum CodingKeys: String, CodingKey {
        case errorType = "error_type"
        case count
    }
}

struct XlyraCooldownSummary: Decodable, Equatable {
    let active: Int
}

struct XlyraSnapshot: Decodable, Equatable {
    let generatedAt: String
    let sites: XlyraSiteSummary
    let oauth: XlyraOAuthSummary
    let apiKeys: XlyraAPIKeySummary
    let requests: XlyraRequestSummary
    let usage: XlyraUsageSummary
    let errors: [XlyraErrorRow]
    let cooldowns: XlyraCooldownSummary
    let checkedAt: Date

    init(
        generatedAt: String,
        sites: XlyraSiteSummary,
        oauth: XlyraOAuthSummary,
        apiKeys: XlyraAPIKeySummary,
        requests: XlyraRequestSummary,
        usage: XlyraUsageSummary,
        errors: [XlyraErrorRow],
        cooldowns: XlyraCooldownSummary,
        checkedAt: Date = Date()
    ) {
        self.generatedAt = generatedAt
        self.sites = sites
        self.oauth = oauth
        self.apiKeys = apiKeys
        self.requests = requests
        self.usage = usage
        self.errors = errors
        self.cooldowns = cooldowns
        self.checkedAt = checkedAt
    }

    var healthLevel: XlyraHealthLevel {
        if sites.total == 0 || apiKeys.active == 0 {
            return .critical
        }
        if sites.healthy == 0 || requests.successRate24h.map({ $0 < 0.80 }) == true {
            return .critical
        }
        if sites.healthy < sites.total || oauth.liveHealthy < oauth.liveTotal || oauth.liveLimited > 0 || apiKeys.exhausted > 0 || requests.failed24h > 0 || cooldowns.active > 0 {
            return .warning
        }
        return .healthy
    }

    var abnormalItemCount: Int {
        riskItems.count
    }

    var riskItems: [String] {
        var items: [String] = []
        if sites.healthy < sites.total {
            items.append("站点异常 \(sites.total - sites.healthy) 个")
        }
        if oauth.liveHealthy < oauth.liveTotal {
            items.append("OAuth 异常 \(oauth.liveTotal - oauth.liveHealthy) 个")
        }
        if oauth.liveLimited > 0 {
            items.append("OAuth 额度触顶 \(oauth.liveLimited) 个")
        }
        if apiKeys.exhausted > 0 {
            items.append("Key 配额耗尽 \(apiKeys.exhausted) 个")
        }
        if requests.failed24h > 0 {
            items.append("24h 失败 \(requests.failed24h) 次")
        }
        return items
    }

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case sites
        case oauth
        case apiKeys = "api_keys"
        case requests
        case usage
        case errors
        case cooldowns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        sites = try container.decode(XlyraSiteSummary.self, forKey: .sites)
        oauth = try container.decode(XlyraOAuthSummary.self, forKey: .oauth)
        apiKeys = try container.decode(XlyraAPIKeySummary.self, forKey: .apiKeys)
        requests = try container.decode(XlyraRequestSummary.self, forKey: .requests)
        usage = try container.decode(XlyraUsageSummary.self, forKey: .usage)
        errors = try container.decode([XlyraErrorRow].self, forKey: .errors)
        cooldowns = try container.decode(XlyraCooldownSummary.self, forKey: .cooldowns)
        checkedAt = Date()
    }
}

enum XlyraHealthLevel: Equatable {
    case healthy
    case warning
    case critical
}

@MainActor
final class XlyraMonitorState: ObservableObject {
    @Published private(set) var snapshot: XlyraSnapshot?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var consecutiveFailures = 0
    @Published private(set) var lastRefreshDuration: TimeInterval?
    @Published private(set) var selectedDetailTab: XlyraDetailTab = .oauth

    var statusColorName: String {
        if isRefreshing, snapshot == nil { return "yellow" }
        if lastError != nil { return "red" }
        if snapshot != nil { return "green" }
        return "gray"
    }

    var title: String {
        if lastError != nil { return "xLyra 连接失败" }
        if snapshot != nil { return "xLyra 已连接" }
        return isRefreshing ? "xLyra 连接中" : "xLyra 未检查"
    }

    func beginRefresh() {
        isRefreshing = true
    }

    func selectDetailTab(_ tab: XlyraDetailTab) {
        selectedDetailTab = tab
    }

    func applySuccess(_ snapshot: XlyraSnapshot, requestDuration: TimeInterval? = nil) {
        self.snapshot = snapshot
        lastError = nil
        isRefreshing = false
        lastRefreshDuration = requestDuration
        consecutiveFailures = snapshot.healthLevel == .healthy ? 0 : consecutiveFailures + 1
    }

    func applyFailure(_ message: String, requestDuration: TimeInterval? = nil) {
        lastError = message
        isRefreshing = false
        lastRefreshDuration = requestDuration
        consecutiveFailures += 1
    }
}

final class XlyraMonitorPreferences {
    private let configURL: URL
    private let fileManager: FileManager

    init(
        configURL: URL = XlyraMonitorPreferences.defaultConfigURL(),
        fileManager: FileManager = .default
    ) {
        self.configURL = configURL
        self.fileManager = fileManager
    }

    var consoleURL: URL? {
        get {
            guard let rawValue = configuration().consoleURL,
                  rawValue.isEmpty == false else {
                return nil
            }
            return URL(string: rawValue)
        }
        set {
            var config = configuration()
            config.consoleURL = newValue?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            save(config)
        }
    }

    var hasAdminAccessToken: Bool {
        (try? adminAccessToken())?.isEmpty == false
    }

    var adminAccessTokenStatusText: String {
        hasAdminAccessToken ? "已配置 Admin Access Token（App 配置文件），刷新时使用 xLyra 控制面 API" : "未配置 Admin Access Token，无法刷新"
    }

    func adminAccessToken() throws -> String? {
        guard let token = configuration().adminAccessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            return nil
        }
        return token
    }

    func saveAdminAccessToken(_ token: String?) throws {
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var config = configuration()
        if trimmedToken.isEmpty {
            config.adminAccessToken = nil
            save(config)
            return
        }
        config.adminAccessToken = trimmedToken
        save(config)
    }

    private func configuration() -> XlyraMonitorConfiguration {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(XlyraMonitorConfiguration.self, from: data) else {
            return XlyraMonitorConfiguration()
        }
        return config
    }

    private func save(_ configuration: XlyraMonitorConfiguration) {
        do {
            try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: configURL, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch {
            assertionFailure("Failed to save xLyra monitor config: \(error)")
        }
    }

    private static func defaultConfigURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseURL
            .appendingPathComponent("xLyra Monitor", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}

private struct XlyraMonitorConfiguration: Codable, Equatable {
    var consoleURL: String?
    var adminAccessToken: String?
}

struct XlyraOAuthImportResult: Equatable {
    let message: String

    static func fromResponseData(_ data: Data) -> XlyraOAuthImportResult {
        guard data.isEmpty == false,
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return XlyraOAuthImportResult(message: "OAuth 导入完成")
        }

        var parts = [String]()
        if let message = string(from: object, keys: ["message", "msg", "status"]), message.isEmpty == false {
            parts.append(message)
        }

        for (title, keys) in [
            ("导入", ["imported", "created", "account_created", "success", "success_count"]),
            ("跳过", ["skipped", "duplicate", "duplicated", "reused"]),
            ("失败", ["failed", "account_failed", "error_count"])
        ] {
            if let value = int(from: object, keys: keys) {
                parts.append("\(title) \(value)")
            }
        }

        if let errors = array(from: object, keys: ["errors", "error_messages"]), errors.isEmpty == false {
            parts.append("错误 \(errors.count)")
        }

        return XlyraOAuthImportResult(message: parts.isEmpty ? "OAuth 导入完成" : parts.joined(separator: " · "))
    }

    private static func string(from object: Any, keys: [String]) -> String? {
        guard let dictionary = object as? [String: Any] else { return nil }
        for key in keys {
            if let value = dictionary[key] as? String { return value }
            if let nested = dictionary["data"] as? [String: Any], let value = nested[key] as? String {
                return value
            }
        }
        return nil
    }

    private static func int(from object: Any, keys: [String]) -> Int? {
        guard let dictionary = object as? [String: Any] else { return nil }
        for key in keys {
            if let value = intValue(dictionary[key]) { return value }
            if let nested = dictionary["data"] as? [String: Any], let value = intValue(nested[key]) {
                return value
            }
        }
        return nil
    }

    private static func array(from object: Any, keys: [String]) -> [Any]? {
        guard let dictionary = object as? [String: Any] else { return nil }
        for key in keys {
            if let value = dictionary[key] as? [Any] { return value }
            if let nested = dictionary["data"] as? [String: Any], let value = nested[key] as? [Any] {
                return value
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

protocol XlyraSnapshotFetching {
    func fetchSnapshot(preferences: XlyraMonitorPreferences) async throws -> XlyraSnapshot
    func refreshOAuthConnections(preferences: XlyraMonitorPreferences, connectionIDs: [String]) async throws
    func importOAuthAccounts(preferences: XlyraMonitorPreferences, payload: Data) async throws -> XlyraOAuthImportResult
}

struct XlyraAPIMonitorService: XlyraSnapshotFetching {
    private let httpClient: XlyraHTTPClient

    init(httpClient: XlyraHTTPClient = XlyraURLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchSnapshot(preferences: XlyraMonitorPreferences) async throws -> XlyraSnapshot {
        guard let accessToken = try preferences.adminAccessToken() else {
            throw XlyraMonitorError.missingAdminAccessToken
        }

        async let ready = fetchProbe(path: "readyz", preferences: preferences, accessToken: nil)
        async let version = fetchJSON(path: "api/v1/system/version", preferences: preferences, accessToken: nil)
        async let siteTypes = fetchJSON(path: "api/v1/site-types", preferences: preferences, accessToken: nil)
        async let overview = fetchJSON(path: "api/v1/dashboard/overview", preferences: preferences, accessToken: accessToken)
        async let oauth = fetchJSON(path: "api/v1/oauth/connections", preferences: preferences, accessToken: accessToken)
        async let sites = fetchJSON(path: "api/v1/sites?oauth=exclude", preferences: preferences, accessToken: accessToken)
        async let apiKeys = fetchJSON(path: "api/v1/api-keys", preferences: preferences, accessToken: accessToken)
        async let healthSites = fetchJSON(path: "api/v1/health/sites", preferences: preferences, accessToken: accessToken)
        async let cooldowns = fetchJSON(path: "api/v1/routes/cooldowns", preferences: preferences, accessToken: accessToken)
        async let requests = fetchJSON(path: "api/v1/requests?page=1&page_size=50", preferences: preferences, accessToken: accessToken)

        do {
            return try await XlyraAPISnapshotBuilder.snapshot(
                ready: ready,
                version: version,
                siteTypes: siteTypes,
                overview: overview,
                oauth: oauth,
                sites: sites,
                apiKeys: apiKeys,
                healthSites: healthSites,
                cooldowns: cooldowns,
                requests: requests
            )
        } catch let error as XlyraMonitorError {
            throw error
        } catch {
            throw XlyraMonitorError.decodingFailed
        }
    }

    func refreshOAuthConnections(preferences: XlyraMonitorPreferences, connectionIDs: [String]) async throws {
        guard let accessToken = try preferences.adminAccessToken() else {
            throw XlyraMonitorError.missingAdminAccessToken
        }

        for connectionID in connectionIDs {
            try await post(path: "api/v1/oauth/connections/\(connectionID)/refresh", preferences: preferences, accessToken: accessToken)
        }
    }

    func importOAuthAccounts(preferences: XlyraMonitorPreferences, payload: Data) async throws -> XlyraOAuthImportResult {
        guard let accessToken = try preferences.adminAccessToken() else {
            throw XlyraMonitorError.missingAdminAccessToken
        }

        let responseData = try await postJSON(
            path: "api/v1/oauth/import",
            preferences: preferences,
            accessToken: accessToken,
            payload: payload
        )
        return XlyraOAuthImportResult.fromResponseData(responseData)
    }

    private func fetchProbe(path: String, preferences: XlyraMonitorPreferences, accessToken: String?) async throws {
        guard let consoleURL = preferences.consoleURL else {
            throw XlyraMonitorError.missingConsoleURL
        }
        let url = try apiURL(baseURL: consoleURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        }

        let response = try await httpClient.send(request, timeout: 6)
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw XlyraMonitorError.apiUnauthorized
            }
            throw XlyraMonitorError.apiRequestFailed(response.statusCode)
        }
    }

    private func fetchJSON(path: String, preferences: XlyraMonitorPreferences, accessToken: String?) async throws -> Any {
        guard let consoleURL = preferences.consoleURL else {
            throw XlyraMonitorError.missingConsoleURL
        }
        let url = try apiURL(baseURL: consoleURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        }

        let response = try await httpClient.send(request, timeout: 12)
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw XlyraMonitorError.apiUnauthorized
            }
            throw XlyraMonitorError.apiRequestFailed(response.statusCode)
        }
        guard response.data.isEmpty == false else {
            return [:]
        }
        return try JSONSerialization.jsonObject(with: response.data)
    }

    private func post(path: String, preferences: XlyraMonitorPreferences, accessToken: String) async throws {
        guard let consoleURL = preferences.consoleURL else {
            throw XlyraMonitorError.missingConsoleURL
        }
        let url = try apiURL(baseURL: consoleURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")

        let response = try await httpClient.send(request, timeout: 12)
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw XlyraMonitorError.apiUnauthorized
            }
            throw XlyraMonitorError.apiRequestFailed(response.statusCode)
        }
    }

    private func postJSON(path: String, preferences: XlyraMonitorPreferences, accessToken: String, payload: Data) async throws -> Data {
        guard let consoleURL = preferences.consoleURL else {
            throw XlyraMonitorError.missingConsoleURL
        }
        let url = try apiURL(baseURL: consoleURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")

        let response = try await httpClient.send(request, timeout: 30)
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw XlyraMonitorError.apiUnauthorized
            }
            throw XlyraMonitorError.apiRequestFailed(response.statusCode)
        }
        return response.data
    }

    private func apiURL(baseURL: URL, path: String) throws -> URL {
        var base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        base.append("/")
        base.append(normalizedPath)
        guard let url = URL(string: base) else {
            throw XlyraMonitorError.invalidPayload
        }
        return url
    }
}

enum XlyraAPISnapshotBuilder {
    static func snapshot(
        ready: Void,
        version: Any,
        siteTypes: Any,
        overview: Any,
        oauth: Any,
        sites: Any,
        apiKeys: Any,
        healthSites: Any,
        cooldowns: Any,
        requests: Any
    ) throws -> XlyraSnapshot {
        _ = ready
        _ = objectPayload(version)
        _ = arrayPayload(siteTypes)
        let overviewObject = objectPayload(overview)
        let healthRows = arrayPayload(healthSites)
        let siteUsageRows = siteUsageRows(from: overviewObject)
        let cooldownRows = arrayPayload(cooldowns)
        let siteRows = arrayPayload(sites)
            .map { siteRow($0, healthRows: healthRows, usageRows: siteUsageRows, cooldownRows: cooldownRows) }
            .sorted(by: siteSort)
        let oauthRows = arrayPayload(oauth)
            .map { oauthRow($0, siteRows: siteRows, cooldownRows: cooldownRows) }
            .sorted(by: oauthSort)
        let apiKeyRows = arrayPayload(apiKeys).map(apiKeyRow)

        let requestSummary = requestSummary(from: overviewObject, requestsPayload: requests)
        let usageSummary = usageSummary(from: overviewObject, siteRows: siteRows, oauthRows: oauthRows)
        let errors = errorRows(from: overviewObject, requestsPayload: requests)
        let cooldownSummary = cooldownSummary(from: overviewObject, cooldownsPayload: cooldowns)

        return XlyraSnapshot(
            generatedAt: isoDateFormatter.string(from: Date()),
            sites: XlyraSiteSummary(
                total: siteRows.isEmpty ? (int(overviewObject, "sites.total", "site_total") ?? 0) : siteRows.count,
                healthy: siteRows.isEmpty ? (int(overviewObject, "sites.healthy", "healthy_sites", "site_healthy") ?? 0) : siteRows.filter(\.isHealthy).count,
                rows: siteRows
            ),
            oauth: XlyraOAuthSummary(
                total: oauthRows.isEmpty ? (int(overviewObject, "oauth.total", "oauth_total") ?? 0) : oauthRows.count,
                healthy: oauthRows.isEmpty ? (int(overviewObject, "oauth.healthy", "healthy_oauth", "oauth_healthy") ?? 0) : oauthRows.filter(\.isHealthy).count,
                limited: oauthRows.isEmpty ? (int(overviewObject, "oauth.limited", "limited_oauth", "oauth_limited") ?? 0) : oauthRows.filter { $0.limitReached == true }.count,
                rows: oauthRows
            ),
            apiKeys: XlyraAPIKeySummary(
                total: apiKeyRows.isEmpty ? (int(overviewObject, "api_keys.total", "apiKeys.total", "api_key_total") ?? 0) : apiKeyRows.count,
                active: apiKeyRows.isEmpty ? (int(overviewObject, "api_keys.active", "apiKeys.active", "active_api_keys", "api_key_active") ?? 0) : apiKeyRows.filter(\.isActive).count,
                exhausted: apiKeyRows.isEmpty ? (int(overviewObject, "api_keys.exhausted", "apiKeys.exhausted", "exhausted_api_keys") ?? 0) : apiKeyRows.filter(\.isExhausted).count,
                rows: apiKeyRows
            ),
            requests: requestSummary,
            usage: usageSummary,
            errors: errors,
            cooldowns: cooldownSummary
        )
    }

    private static func siteRow(
        _ object: [String: Any],
        healthRows: [[String: Any]],
        usageRows: [[String: Any]],
        cooldownRows: [[String: Any]]
    ) -> XlyraSiteRow {
        let siteID = string(object, "id", "site_id", "slug") ?? UUID().uuidString
        let slug = string(object, "slug") ?? siteID
        let healthObject = matchingHealthObject(siteID: siteID, slug: slug, healthRows: healthRows)
            ?? dictionary(object, "recent_health", "health", "latest_health")
        let name = string(object, "name", "display_name") ?? string(object, "slug") ?? "未命名站点"
        let usageObject = matchingSiteUsageObject(siteID: siteID, slug: slug, name: name, usageRows: usageRows)
        let isCoolingDown = hasCooldown(siteID: siteID, slug: slug, name: name, rows: cooldownRows)
        return XlyraSiteRow(
            name: name,
            slug: slug,
            type: string(object, "type", "site_type", "provider") ?? "--",
            status: string(object, "status") ?? "active",
            enabled: bool(object, "enabled") ?? true,
            priority: double(object, "priority", "routing_priority") ?? 0,
            validationOK: bool(object, "validation_ok", "state.validation_ok", "sync_state.validation_ok", "validation.ok"),
            syncStatus: string(object, "sync_status", "state.sync_status", "sync_state.status"),
            apiKeyCount: int(object, "api_key_count", "apiKeys.count", "api_keys_count", "sync_state.api_key_count") ?? 0,
            modelCount: int(object, "model_count", "models.count", "sync_state.model_count") ?? 0,
            lastSyncedAt: string(object, "last_synced_at", "state.last_synced_at", "sync_state.last_synced_at"),
            tokens24h: int(usageObject ?? [:], "total_tokens", "tokens", "tokens_24h") ?? int(object, "tokens24h", "tokens_24h", "usage.tokens_24h", "usage.tokens24h", "usage.total_tokens", "total_tokens") ?? 0,
            cost24h: double(usageObject ?? [:], "cost", "estimated_cost", "cost_24h") ?? double(object, "cost24h", "cost_24h", "usage.cost_24h", "usage.cost24h", "usage.estimated_cost", "estimated_cost", "cost") ?? 0,
            recentHealth: healthObject.map(siteHealth),
            isCoolingDown: isCoolingDown
        )
    }

    private static func siteUsageRows(from object: [String: Any]) -> [[String: Any]] {
        if let rows = value(object, "site_cost_summary") as? [[String: Any]] {
            return rows
        }
        guard let windows = object["windows"] as? [String: Any] else {
            return []
        }
        let preferredKeys = ["1", "24", "today", "7"]
        for key in preferredKeys {
            if let window = windows[key] as? [String: Any],
               let rows = window["site_cost_summary"] as? [[String: Any]] {
                return rows
            }
        }
        for window in windows.values {
            if let windowObject = window as? [String: Any],
               let rows = windowObject["site_cost_summary"] as? [[String: Any]] {
                return rows
            }
        }
        return []
    }

    private static func matchingSiteUsageObject(siteID: String, slug: String, name: String, usageRows: [[String: Any]]) -> [String: Any]? {
        usageRows.first {
            string($0, "site_id", "site.id", "id") == siteID
                || string($0, "site_slug", "site.slug", "slug") == slug
                || string($0, "site_name", "site.name", "name") == name
        }
    }

    private static func matchingHealthObject(siteID: String, slug: String, healthRows: [[String: Any]]) -> [String: Any]? {
        guard let row = healthRows.first(where: {
            string($0, "site_id", "health.site_id", "site.id", "id") == siteID
                || string($0, "site_slug", "site.slug", "slug") == slug
        }) else {
            return nil
        }
        return dictionary(row, "health") ?? row
    }

    private static func siteHealth(_ object: [String: Any]) -> XlyraSiteHealth {
        XlyraSiteHealth(
            success: bool(object, "success", "ok") ?? healthStatusIsSuccessful(string(object, "status", "health.status")),
            statusCode: int(object, "status_code", "statusCode"),
            latencyMS: int(object, "latency_ms", "latencyMS", "latency", "recent_avg_latency_ms"),
            errorType: string(object, "error_type", "errorType", "message", "status"),
            checkedAt: string(object, "checked_at", "checkedAt")
        )
    }

    private static func healthStatusIsSuccessful(_ status: String?) -> Bool? {
        guard let status else { return nil }
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "healthy", "ok", "success", "available", "ready":
            return true
        case "unhealthy", "error", "failed", "failure", "down":
            return false
        default:
            return nil
        }
    }

    private static func oauthRow(_ object: [String: Any], siteRows: [XlyraSiteRow], cooldownRows: [[String: Any]]) -> XlyraOAuthRow {
        let siteName = string(object, "site_name", "site.name", "siteName")
        let siteSlug = string(object, "site_slug", "site.slug", "siteSlug")
        let accountID = string(object, "account_id", "accountID", "account.id") ?? ""
        let email = string(object, "email", "account.email") ?? ""
        let isCoolingDown = hasCooldown(siteID: siteSlug ?? accountID, slug: siteSlug ?? accountID, name: siteName ?? email, rows: cooldownRows)
        let sitePriority = matchingSite(siteSlug: siteSlug, siteName: siteName, rows: siteRows)?.priority
        return XlyraOAuthRow(
            id: string(object, "id") ?? UUID().uuidString,
            provider: string(object, "provider") ?? "oauth",
            siteName: siteName,
            siteSlug: siteSlug,
            status: string(object, "status") ?? "connected",
            accountID: accountID,
            email: email,
            planType: string(object, "plan_type", "account.plan_type", "meta.plan_type", "quota.plan_type", "meta.quota.plan_type", "metadata.quota.plan_type", "site.oauth_account.plan_type", "site.meta.oauth_plan_type"),
            available: bool(object, "available", "quota.available", "meta.quota.available", "metadata.quota.available"),
            limitReached: bool(object, "limit_reached", "quota.limit_reached", "quota.limited", "meta.quota.limit_reached", "meta.quota.limited", "metadata.quota.limit_reached"),
            fiveHourUsedPercent: double(object, "five_hour_used_percent", "quota.five_hour.used_percent", "meta.quota.five_hour.used_percent", "metadata.quota.five_hour.used_percent"),
            fiveHourRemainingPercent: double(object, "five_hour_remaining_percent", "quota.five_hour.remaining_percent", "meta.quota.five_hour.remaining_percent", "metadata.quota.five_hour.remaining_percent"),
            fiveHourResetAt: double(object, "five_hour_reset_at", "quota.five_hour.reset_at", "meta.quota.five_hour.reset_at", "metadata.quota.five_hour.reset_at"),
            weeklyUsedPercent: double(object, "weekly_used_percent", "quota.weekly.used_percent", "meta.quota.weekly.used_percent", "metadata.quota.weekly.used_percent"),
            weeklyRemainingPercent: double(object, "weekly_remaining_percent", "quota.weekly.remaining_percent", "meta.quota.weekly.remaining_percent", "metadata.quota.weekly.remaining_percent"),
            weeklyResetAt: double(object, "weekly_reset_at", "quota.weekly.reset_at", "meta.quota.weekly.reset_at", "metadata.quota.weekly.reset_at"),
            creditsBalance: string(object, "credits_balance", "quota.credits.balance", "meta.quota.credits.balance", "metadata.quota.credits.balance"),
            creditsUnlimited: bool(object, "credits_unlimited", "quota.credits.unlimited", "meta.quota.credits.unlimited", "metadata.quota.credits.unlimited"),
            lastRefreshAt: string(object, "last_refresh_at", "lastRefreshAt"),
            lastSyncAt: string(object, "last_sync_at", "lastSyncAt", "site.sync_state.last_synced_at"),
            expiresAt: string(object, "expires_at", "expiresAt"),
            tokens24h: int(object, "tokens24h", "tokens_24h", "usage.tokens_24h", "usage.tokens24h", "usage.total_tokens", "site.usage.total_tokens") ?? 0,
            cost24h: double(object, "cost24h", "cost_24h", "usage.cost_24h", "usage.cost24h", "usage.estimated_cost", "site.usage.estimated_cost") ?? 0,
            priority: double(object, "priority", "routing_priority", "site.priority", "site.routing_priority") ?? sitePriority ?? 0,
            isCoolingDown: isCoolingDown
        )
    }

    private static func siteSort(_ lhs: XlyraSiteRow, _ rhs: XlyraSiteRow) -> Bool {
        let lhsRank = statusRank(isEnabled: lhs.enabled, isCoolingDown: lhs.isCoolingDown, isHealthy: lhs.isHealthy)
        let rhsRank = statusRank(isEnabled: rhs.enabled, isCoolingDown: rhs.isCoolingDown, isHealthy: rhs.isHealthy)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func oauthSort(_ lhs: XlyraOAuthRow, _ rhs: XlyraOAuthRow) -> Bool {
        let lhsRank = statusRank(isEnabled: true, isCoolingDown: lhs.isCoolingDown, isHealthy: lhs.isHealthy)
        let rhsRank = statusRank(isEnabled: true, isCoolingDown: rhs.isCoolingDown, isHealthy: rhs.isHealthy)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    private static func matchingSite(siteSlug: String?, siteName: String?, rows: [XlyraSiteRow]) -> XlyraSiteRow? {
        rows.first { site in
            site.slug == siteSlug || site.name == siteName
        }
    }

    private static func statusRank(isEnabled: Bool, isCoolingDown: Bool, isHealthy: Bool) -> Int {
        if isEnabled == false { return 3 }
        if isCoolingDown { return 1 }
        return isHealthy ? 0 : 2
    }

    private static func hasCooldown(siteID: String, slug: String, name: String, rows: [[String: Any]]) -> Bool {
        rows.contains { row in
            string(row, "site_id", "site.id", "id", "target.site_id") == siteID
                || string(row, "site_slug", "site.slug", "slug", "target.site_slug") == slug
                || string(row, "site_name", "site.name", "name", "target.site_name") == name
        }
    }

    private static func apiKeyRow(_ object: [String: Any]) -> XlyraAPIKeyRow {
        XlyraAPIKeyRow(
            name: string(object, "name", "label") ?? "API Key",
            maskedKey: string(object, "masked_key", "maskedKey", "key_preview", "preview") ?? "****",
            copyableKey: string(object, "key", "api_key", "secret", "value", "token", "copyable_key", "masked_key", "maskedKey", "key_preview", "preview"),
            status: string(object, "status") ?? "active",
            quotaLimit: double(object, "quota_limit", "quota.limit", "quotaLimit"),
            quotaUsed: double(object, "quota_used", "quota.used", "quotaUsed") ?? 0,
            quotaUnlimited: bool(object, "quota_unlimited", "quota.unlimited", "quotaUnlimited") ?? (double(object, "quota_limit", "quota.limit", "quotaLimit") == nil),
            lastUsedAt: string(object, "last_used_at", "lastUsedAt"),
            expiresAt: string(object, "expires_at", "expiresAt")
        )
    }

    private static func requestSummary(from object: [String: Any], requestsPayload: Any) -> XlyraRequestSummary {
        let requestRows = arrayPayload(requestsPayload)
        let failedRows = requestRows.filter { bool($0, "success", "ok") == false }
        let last24h = int(object, "requests.last_24h", "requests.last24h", "last_24h_requests", "requests_24h", "kpis.requests.today")
            ?? int(objectPayload(requestsPayload), "meta.total", "total")
            ?? requestRows.count
        let explicitFailed = int(object, "requests.failed_24h", "requests.failed24h", "failed_24h_requests", "failed_requests_24h")
        let explicitOK = int(object, "requests.ok_24h", "requests.ok24h", "ok_24h_requests", "ok_requests_24h")
        let successRate = normalizedRatio(double(object, "requests.success_rate", "kpis.requests.success_rate", "success_rate"))
        let ok24h = explicitOK ?? successRate.map { Int((Double(last24h) * $0).rounded()) } ?? max(0, last24h - (explicitFailed ?? failedRows.count))
        let failed24h = explicitFailed ?? max(0, last24h - ok24h)

        return XlyraRequestSummary(
            total: int(object, "requests.total", "total_requests", "request_total", "kpis.requests.total") ?? last24h,
            lastHour: int(object, "requests.last_hour", "requests.lastHour", "last_hour_requests", "requests_1h", "kpis.rate_limit.rpm.used") ?? 0,
            last24h: last24h,
            ok24h: ok24h,
            failed24h: failed24h,
            avgLatency24h: int(object, "requests.avg_latency_24h", "requests.avgLatency24h", "avg_latency_24h")
        )
    }

    private static func usageSummary(from object: [String: Any], siteRows: [XlyraSiteRow], oauthRows: [XlyraOAuthRow]) -> XlyraUsageSummary {
        let fallbackTokens = siteRows.map(\.tokens24h).reduce(0, +)
        let fallbackCost = siteRows.map(\.cost24h).reduce(0, +)
        return XlyraUsageSummary(
            tokens24h: int(object, "usage.tokens_24h", "usage.tokens24h", "tokens_24h", "kpis.requests.today_tokens") ?? (fallbackTokens > 0 ? fallbackTokens : oauthRows.map(\.tokens24h).reduce(0, +)),
            cost24h: double(object, "usage.cost_24h", "usage.cost24h", "cost_24h", "kpis.cost.today") ?? (fallbackCost > 0 ? fallbackCost : oauthRows.map(\.cost24h).reduce(0, +))
        )
    }

    private static func normalizedRatio(_ value: Double?) -> Double? {
        guard let value else { return nil }
        if value > 1 {
            return max(0, min(1, value / 100))
        }
        return max(0, min(1, value))
    }

    private static func errorRows(from object: [String: Any]) -> [XlyraErrorRow] {
        arrayPayload(object["errors"] ?? object["error_rows"] ?? []).map {
            XlyraErrorRow(
                errorType: string($0, "error_type", "type", "code") ?? "unknown",
                count: int($0, "count", "total") ?? 0
            )
        }
    }

    private static func errorRows(from object: [String: Any], requestsPayload: Any) -> [XlyraErrorRow] {
        let overviewErrors = errorRows(from: object)
        if overviewErrors.isEmpty == false {
            return overviewErrors
        }
        let grouped = Dictionary(grouping: arrayPayload(requestsPayload).filter { bool($0, "success", "ok") == false }) {
            string($0, "error_type", "error.type", "error.code") ?? "unknown"
        }
        return grouped.map { XlyraErrorRow(errorType: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.errorType < $1.errorType : $0.count > $1.count }
    }

    private static func cooldownSummary(from object: [String: Any], cooldownsPayload: Any) -> XlyraCooldownSummary {
        let rows = arrayPayload(cooldownsPayload)
        return XlyraCooldownSummary(
            active: rows.isEmpty == false ? rows.count : (int(objectPayload(cooldownsPayload), "meta.total", "total", "active") ?? int(object, "cooldowns.active", "active_cooldowns", "cooldown_count") ?? 0)
        )
    }

    private static func objectPayload(_ value: Any) -> [String: Any] {
        if let dictionary = value as? [String: Any] {
            if let data = dictionary["data"] as? [String: Any] {
                return data
            }
            return dictionary
        }
        return [:]
    }

    private static func arrayPayload(_ value: Any) -> [[String: Any]] {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let dictionary = value as? [String: Any] {
            for key in ["data", "items", "rows", "connections", "sites", "api_keys", "apiKeys"] {
                if let array = dictionary[key] as? [[String: Any]] {
                    return array
                }
                if let nested = dictionary[key] as? [String: Any] {
                    let nestedArray = arrayPayload(nested)
                    if nestedArray.isEmpty == false {
                        return nestedArray
                    }
                }
            }
        }
        return []
    }

    private static func dictionary(_ object: [String: Any], _ keys: String...) -> [String: Any]? {
        for key in keys {
            if let value = value(object, key) as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func string(_ object: [String: Any], _ keys: String...) -> String? {
        for key in keys {
            guard let rawValue = value(object, key), !(rawValue is NSNull) else { continue }
            if let stringValue = rawValue as? String {
                let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedValue.isEmpty == false { return trimmedValue }
            } else if let numberValue = rawValue as? NSNumber {
                return numberValue.stringValue
            }
        }
        return nil
    }

    private static func int(_ object: [String: Any], _ keys: String...) -> Int? {
        for key in keys {
            guard let rawValue = value(object, key), !(rawValue is NSNull) else { continue }
            if let intValue = rawValue as? Int { return intValue }
            if let numberValue = rawValue as? NSNumber { return numberValue.intValue }
            if let stringValue = rawValue as? String, let intValue = Int(stringValue) { return intValue }
            if let stringValue = rawValue as? String, let doubleValue = Double(stringValue) { return Int(doubleValue.rounded()) }
        }
        return nil
    }

    private static func double(_ object: [String: Any], _ keys: String...) -> Double? {
        for key in keys {
            guard let rawValue = value(object, key), !(rawValue is NSNull) else { continue }
            if let doubleValue = rawValue as? Double { return doubleValue }
            if let intValue = rawValue as? Int { return Double(intValue) }
            if let numberValue = rawValue as? NSNumber { return numberValue.doubleValue }
            if let stringValue = rawValue as? String, let doubleValue = Double(stringValue) { return doubleValue }
        }
        return nil
    }

    private static func bool(_ object: [String: Any], _ keys: String...) -> Bool? {
        for key in keys {
            guard let rawValue = value(object, key), !(rawValue is NSNull) else { continue }
            if let boolValue = rawValue as? Bool { return boolValue }
            if let numberValue = rawValue as? NSNumber { return numberValue.boolValue }
            if let stringValue = rawValue as? String {
                switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes", "y":
                    return true
                case "false", "0", "no", "n":
                    return false
                default:
                    continue
                }
            }
        }
        return nil
    }

    private static func value(_ object: [String: Any], _ path: String) -> Any? {
        let parts = path.split(separator: ".").map(String.init)
        var current: Any? = object
        for part in parts {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }
            current = dictionary[part]
        }
        return current
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum XlyraMonitorError: Error {
    case invalidPayload
    case decodingFailed
    case missingConsoleURL
    case missingAdminAccessToken
    case apiUnauthorized
    case apiRequestFailed(Int)

    var message: String {
        switch self {
        case .invalidPayload:
            return "xLyra API 返回内容不可读"
        case .decodingFailed:
            return "xLyra 数据解析失败"
        case .missingConsoleURL:
            return "未配置 xLyra 控制台地址"
        case .missingAdminAccessToken:
            return "未配置 xLyra Admin Access Token"
        case .apiUnauthorized:
            return "xLyra Admin Access Token 无效或权限不足"
        case .apiRequestFailed(let statusCode):
            return "xLyra API 请求失败 HTTP \(statusCode)"
        }
    }
}

@MainActor
final class XlyraMonitor: ObservableObject {
    let state: XlyraMonitorState
    private let preferences: XlyraMonitorPreferences
    private let service: XlyraSnapshotFetching
    private var statusPollingTask: Task<Void, Never>?
    private var oauthPollingTask: Task<Void, Never>?
    private var isRefreshInFlight = false

    init(
        state: XlyraMonitorState,
        preferences: XlyraMonitorPreferences,
        service: XlyraSnapshotFetching = XlyraAPIMonitorService()
    ) {
        self.state = state
        self.preferences = preferences
        self.service = service
    }

    func start(statusInterval: TimeInterval, oauthInterval: TimeInterval) {
        statusPollingTask?.cancel()
        oauthPollingTask?.cancel()

        statusPollingTask = Task { @MainActor in
            await refresh()
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: UInt64(max(10, statusInterval) * 1_000_000_000))
                if Task.isCancelled == false {
                    await refresh()
                }
            }
        }

        oauthPollingTask = Task { @MainActor in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: UInt64(max(10, oauthInterval) * 1_000_000_000))
                if Task.isCancelled == false {
                    await refreshOAuth()
                }
            }
        }
    }

    func start(interval: TimeInterval) {
        start(statusInterval: interval, oauthInterval: 300)
    }

    func stop() {
        statusPollingTask?.cancel()
        oauthPollingTask?.cancel()
        statusPollingTask = nil
        oauthPollingTask = nil
    }

    func refresh() async {
        guard isRefreshInFlight == false else { return }
        isRefreshInFlight = true
        defer { isRefreshInFlight = false }
        state.beginRefresh()
        let startedAt = Date()
        do {
            guard preferences.consoleURL != nil else {
                throw XlyraMonitorError.missingConsoleURL
            }
            let snapshot = try await service.fetchSnapshot(preferences: preferences)
            state.applySuccess(snapshot, requestDuration: Date().timeIntervalSince(startedAt))
        } catch let error as XlyraMonitorError {
            state.applyFailure(error.message, requestDuration: Date().timeIntervalSince(startedAt))
        } catch {
            state.applyFailure("刷新失败", requestDuration: Date().timeIntervalSince(startedAt))
        }
    }

    func refreshOAuth() async {
        guard isRefreshInFlight == false else { return }
        isRefreshInFlight = true
        defer { isRefreshInFlight = false }
        state.beginRefresh()
        let startedAt = Date()
        do {
            guard preferences.consoleURL != nil else {
                throw XlyraMonitorError.missingConsoleURL
            }
            let currentConnectionIDs = state.snapshot?.oauth.rows.map(\.id) ?? []
            if currentConnectionIDs.isEmpty == false {
                try await service.refreshOAuthConnections(preferences: preferences, connectionIDs: currentConnectionIDs)
            }
            let snapshot = try await service.fetchSnapshot(preferences: preferences)
            state.applySuccess(snapshot, requestDuration: Date().timeIntervalSince(startedAt))
        } catch let error as XlyraMonitorError {
            state.applyFailure(error.message, requestDuration: Date().timeIntervalSince(startedAt))
        } catch {
            state.applyFailure("刷新失败", requestDuration: Date().timeIntervalSince(startedAt))
        }
    }

    func importOAuthAccounts(payload: Data) async -> Result<XlyraOAuthImportResult, XlyraMonitorError> {
        do {
            guard preferences.consoleURL != nil else {
                throw XlyraMonitorError.missingConsoleURL
            }
            let result = try await service.importOAuthAccounts(preferences: preferences, payload: payload)
            await refresh()
            return .success(result)
        } catch let error as XlyraMonitorError {
            return .failure(error)
        } catch {
            return .failure(.apiRequestFailed(-1))
        }
    }
}

@MainActor
final class XlyraAppContainer: ObservableObject {
    let state = XlyraMonitorState()
    let appPreferences = AppPreferences()
    let monitorPreferences = XlyraMonitorPreferences()
    let loginItem = LoginItemService()
    let monitor: XlyraMonitor
    private var cancellables = Set<AnyCancellable>()

    init() {
        monitor = XlyraMonitor(
            state: state,
            preferences: monitorPreferences
        )

        appPreferences.$refreshIntervalSeconds
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.monitor.start(
                        statusInterval: self.appPreferences.refreshIntervalSeconds,
                        oauthInterval: self.appPreferences.oauthRefreshIntervalSeconds
                    )
                }
            }
            .store(in: &cancellables)

        appPreferences.$oauthRefreshIntervalSeconds
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.monitor.start(
                        statusInterval: self.appPreferences.refreshIntervalSeconds,
                        oauthInterval: self.appPreferences.oauthRefreshIntervalSeconds
                    )
                }
            }
            .store(in: &cancellables)

        monitor.start(
            statusInterval: appPreferences.refreshIntervalSeconds,
            oauthInterval: appPreferences.oauthRefreshIntervalSeconds
        )
        applyAppIcon()
        keepAppOutOfDock()
    }

    private func keepAppOutOfDock() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private func applyAppIcon() {
        guard let icon = NSImage(named: XlyraMonitorAppMetadata.appIconName) else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}
