import Foundation
import Sub2APIQuotaCore

struct StatusViewModel {
    let status: QuotaStatus
    let snapshot: QuotaSnapshot?
    let lastError: QuotaErrorKind?
    let lastRequestDuration: TimeInterval?
    private let dateFormatter: DateFormatter

    init(
        status: QuotaStatus,
        snapshot: QuotaSnapshot?,
        lastError: QuotaErrorKind?,
        lastRequestDuration: TimeInterval? = nil,
        dateFormatter: DateFormatter = .statusDateFormatter
    ) {
        self.status = status
        self.snapshot = snapshot
        self.lastError = lastError
        self.lastRequestDuration = lastRequestDuration
        self.dateFormatter = dateFormatter
    }

    var title: String {
        switch status {
        case .notConfigured:
            return "未配置"
        case .available:
            return "可用"
        case .lowQuota:
            return "额度偏低"
        case .unavailable:
            return "额度不可用"
        case .apiError:
            return "接口错误"
        }
    }

    var subtitle: String {
        switch status {
        case .notConfigured:
            return "请先填写服务地址、邮箱和密码"
        case .available, .lowQuota, .unavailable:
            if let snapshot {
                if let poolSummary = snapshot.poolSummary {
                    return "5h剩余 \(formatFixed(poolSummary.remaining5hAccounts)) 个，7d剩余 \(formatCount(poolSummary.remaining7dAccounts)) 个"
                }

                return "剩余 \(format(snapshot.remaining)) \(snapshot.displayUnit)"
            }
            return "等待刷新"
        case .apiError:
            let reason = errorDescription(lastError)
            if let snapshot {
                if let poolSummary = snapshot.poolSummary {
                    return "\(reason)，上次5h剩余 \(formatFixed(poolSummary.remaining5hAccounts)) 个"
                }

                return "\(reason)，上次剩余 \(format(snapshot.remaining)) \(snapshot.displayUnit)"
            }
            return reason
        }
    }

    var colorName: String {
        status.menuBarColorName
    }

    var fiveHourRiskColorName: String {
        if status == .unavailable {
            return "red"
        }

        return fiveHourUsedFraction >= 0.95 ? "yellow" : "green"
    }

    var sevenDayRiskColorName: String {
        sevenDayUsedFraction >= 0.95 ? "red" : "green"
    }

    var lastUpdatedText: String {
        guard let snapshot else {
            return "服务更新 --"
        }

        return "服务更新 \(dateFormatter.string(from: snapshot.menuLastUpdatedAt))"
    }

    var clientRefreshedText: String {
        guard let snapshot else {
            return "本机刷新 --"
        }

        return "本机刷新 \(dateFormatter.string(from: snapshot.clientRefreshedAt))"
    }

    var requestDurationText: String {
        guard let lastRequestDuration else {
            return "请求耗时 --"
        }

        return String(format: "请求耗时 %.2f 秒", lastRequestDuration)
    }

    var lastErrorText: String {
        guard let lastError else {
            return "最近错误 --"
        }

        return "最近错误 \(errorDescription(lastError))"
    }

    var accountPoolText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "账号池 --"
        }

        if poolSummary.rateLimitedCount > 0 {
            return "账号池 \(poolSummary.schedulableCount)/\(poolSummary.accountCount) 可用，限流 \(poolSummary.rateLimitedCount)"
        }

        return "账号池 \(poolSummary.schedulableCount)/\(poolSummary.accountCount) 可用"
    }

    var availableAccountCountText: String? {
        guard let poolSummary = snapshot?.poolSummary else {
            return nil
        }

        if poolSummary.schedulableCount > 99 {
            return "99+"
        }

        return "\(poolSummary.schedulableCount)"
    }

    var concurrencyText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "并发 --"
        }

        return "并发 \(poolSummary.currentConcurrency)/\(poolSummary.concurrencyLimit)"
    }

    var fiveHourWindowText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "5小时窗口 --"
        }

        return "5小时窗口 剩余 \(formatFixed(poolSummary.remaining5hAccounts)) 个账号，已用 \(formatFixed(poolSummary.used5hPercent))%"
    }

    var sevenDayWindowText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "7天窗口 --"
        }

        return "7天窗口 剩余 \(formatCount(poolSummary.remaining7dAccounts)) 个账号，已用 \(formatFixed(poolSummary.used7dPercent))%"
    }

    var fiveHourRemainingText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "剩余 --"
        }

        return "剩余 \(formatFixed(poolSummary.remaining5hAccounts)) 个"
    }

    var sevenDayRemainingText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "剩余 --"
        }

        return "剩余 \(formatCount(poolSummary.remaining7dAccounts)) 个"
    }

    var fiveHourUsedPercentText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "--"
        }

        return "\(formatFixed(poolSummary.used5hPercent))%"
    }

    var sevenDayUsedPercentText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "--"
        }

        return "\(formatFixed(poolSummary.used7dPercent))%"
    }

    var accountRows: [AccountQuotaRowViewModel] {
        guard let accounts = snapshot?.poolSummary?.accounts else {
            return []
        }

        return accounts.map { account in
            let remaining5hPercent = max(Decimal(0), Decimal(100) - account.used5hPercent)
            let remaining7dPercent = max(Decimal(0), Decimal(100) - account.used7dPercent)
            return AccountQuotaRowViewModel(
                id: account.id,
                name: account.name,
                platform: account.platform,
                channelKind: AccountChannelKind(accountType: account.type),
                priority: account.priority,
                priorityText: account.priority.map { "P\($0)" } ?? "P--",
                accountTypeText: accountTypeText(account),
                metadataText: accountMetadataText(account),
                groupText: accountGroupText(account),
                stateText: accountStateText(account),
                concurrencyText: "\(account.currentConcurrency)/\(account.concurrencyLimit)",
                fiveHourRemainingText: "\(formatCompact(remaining5hPercent))% 可用",
                sevenDayRemainingText: "\(formatCompact(remaining7dPercent))% 可用",
                fiveHourPercentText: "\(formatCompact(account.used5hPercent))%",
                sevenDayPercentText: "\(formatCompact(account.used7dPercent))%",
                fiveHourResetText: account.reset5hAt.map { "重置 \(Self.accountDateFormatter.string(from: $0))" } ?? "重置 --",
                sevenDayResetText: account.reset7dAt.map { "重置 \(Self.accountDateFormatter.string(from: $0))" } ?? "重置 --",
                fiveHourStatsText: account.fiveHourStats.map(formatUsageStats) ?? "--",
                sevenDayStatsText: account.sevenDayStats.map(formatUsageStats) ?? "--",
                keySignalText: keySignalText(account),
                fiveHourFraction: fraction(fromPercent: account.used5hPercent),
                sevenDayFraction: fraction(fromPercent: account.used7dPercent),
                supportsUsageWindows: account.supportsUsageWindows,
                isAvailable: account.status == "active" && account.schedulable && account.isRateLimited == false,
                isRateLimited: account.isRateLimited
            )
        }
    }

    var inspectedAPIKeyRow: APIKeyUsageRowViewModel? {
        guard let inspectedAPIKey = snapshot?.inspectedAPIKey else {
            return nil
        }

        return APIKeyUsageRowViewModel(
            id: inspectedAPIKey.id,
            title: inspectedAPIKey.name,
            keyPreview: inspectedAPIKey.keyPreview,
            statusText: inspectedAPIKey.status,
            groupText: inspectedAPIKey.groupName.map { "分组 \($0)" } ?? "分组 --",
            quotaText: inspectedAPIKey.quota > 0
                ? "额度 \(formatMoney(inspectedAPIKey.quotaUsed))/\(formatMoney(inspectedAPIKey.quota))"
                : "额度不限 · 已用 \(formatMoney(inspectedAPIKey.quotaUsed))",
            usageText: formatUsageStats(
                UsageWindowStats(
                    requests: inspectedAPIKey.requests,
                    tokens: inspectedAPIKey.tokens,
                    actualCost: inspectedAPIKey.actualCost,
                    userCost: inspectedAPIKey.userCost
                )
            ),
            expiresText: inspectedAPIKey.expiresAt.map {
                "过期 \(Self.accountDateFormatter.string(from: $0))"
            } ?? "永不过期",
            lastUsedText: inspectedAPIKey.lastUsedAt.map {
                "最近 \(Self.accountDateFormatter.string(from: $0))"
            } ?? "最近 --",
            isActive: inspectedAPIKey.status == "active"
        )
    }

    var fiveHourRemainingShortText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "--"
        }

        return formatCompact(poolSummary.remaining5hAccounts)
    }

    var sevenDayRemainingShortText: String {
        guard let poolSummary = snapshot?.poolSummary else {
            return "--"
        }

        return formatCount(poolSummary.remaining7dAccounts)
    }

    var fiveHourUsedFraction: Double {
        guard let percent = snapshot?.poolSummary?.used5hPercent else {
            return 0
        }

        return fraction(fromPercent: percent)
    }

    var sevenDayUsedFraction: Double {
        guard let percent = snapshot?.poolSummary?.used7dPercent else {
            return 0
        }

        return fraction(fromPercent: percent)
    }

    private func format(_ decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }

    private func formatFixed(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? format(decimal)
    }

    private func formatCompact(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? format(decimal)
    }

    private func formatMoney(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return "$\(formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? format(decimal))"
    }

    private func formatUsageStats(_ stats: UsageWindowStats) -> String {
        "\(stats.requests) req · \(formatTokens(stats.tokens)) · A \(formatMoney(stats.actualCost)) · U \(formatMoney(stats.userCost))"
    }

    private func formatTokens(_ tokens: Int) -> String {
        let value = Double(tokens)
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return "\(tokens)"
    }

    private func formatCount(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? format(decimal)
    }

    private func fraction(fromPercent percent: Decimal) -> Double {
        let value = NSDecimalNumber(decimal: percent).doubleValue / 100
        return min(1, max(0, value))
    }

    private func errorDescription(_ error: QuotaErrorKind?) -> String {
        switch error {
        case .invalidConfiguration:
            return "配置无效"
        case .authenticationFailed:
            return "认证失败"
        case .timeout:
            return "请求超时"
        case .network:
            return "网络异常"
        case .serviceUnavailable:
            return "服务不可用"
        case .invalidResponse:
            return "响应格式异常"
        case .credentialReadFailed:
            return "读取配置失败"
        case .credentialWriteFailed:
            return "密码保存失败"
        case nil:
            return "未知错误"
        }
    }

    private func accountStateText(_ account: AccountQuotaDetail) -> String {
        if account.isRateLimited {
            return "限流"
        }

        if account.status != "active" {
            return account.status
        }

        return account.schedulable ? "可用" : "不可调度"
    }

    private func accountTypeText(_ account: AccountQuotaDetail) -> String {
        let lowercasedName = account.name.lowercased()
        let plan: String
        if lowercasedName.contains("team") {
            plan = "Team"
        } else if lowercasedName.contains("plus") {
            plan = "Plus"
        } else {
            plan = account.type == "apikey" ? "API Key" : account.type.uppercased()
        }

        return "\(formatPlatformName(account.platform)) \(plan)"
    }

    private func accountMetadataText(_ account: AccountQuotaDetail) -> String {
        var parts: [String] = []
        if let email = account.email {
            parts.append(email)
        }
        return parts.joined(separator: " · ")
    }

    private func keySignalText(_ account: AccountQuotaDetail) -> String {
        "状态 \(accountStateText(account)) · 并发 \(account.currentConcurrency)/\(account.concurrencyLimit)"
    }

    private func formatPlatformName(_ platform: String) -> String {
        switch platform.lowercased() {
        case "openai":
            return "OpenAI"
        default:
            return platform.uppercased()
        }
    }

    private func accountGroupText(_ account: AccountQuotaDetail) -> String {
        guard account.groupNames.isEmpty == false else {
            return "分组 --"
        }

        return "分组 \(account.groupNames.joined(separator: "、"))"
    }

    private static var accountDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }
}

enum AccountChannelKind: Equatable {
    case oauth
    case apiKey
    case other(String)

    init(accountType: String) {
        switch accountType.lowercased() {
        case "oauth":
            self = .oauth
        case "apikey", "api_key", "api-key", "key":
            self = .apiKey
        default:
            self = .other(accountType)
        }
    }
}

struct AccountQuotaRowViewModel: Identifiable, Equatable {
    let id: Int
    let name: String
    let platform: String
    let channelKind: AccountChannelKind
    let priority: Int?
    let priorityText: String
    let accountTypeText: String
    let metadataText: String
    let groupText: String
    let stateText: String
    let concurrencyText: String
    let fiveHourRemainingText: String
    let sevenDayRemainingText: String
    let fiveHourPercentText: String
    let sevenDayPercentText: String
    let fiveHourResetText: String
    let sevenDayResetText: String
    let fiveHourStatsText: String
    let sevenDayStatsText: String
    let keySignalText: String
    let fiveHourFraction: Double
    let sevenDayFraction: Double
    let supportsUsageWindows: Bool
    let isAvailable: Bool
    let isRateLimited: Bool
}

struct APIKeyUsageRowViewModel: Identifiable, Equatable {
    let id: Int
    let title: String
    let keyPreview: String
    let statusText: String
    let groupText: String
    let quotaText: String
    let usageText: String
    let expiresText: String
    let lastUsedText: String
    let isActive: Bool
}

private extension DateFormatter {
    static var statusDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}
