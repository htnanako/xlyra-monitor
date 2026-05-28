import Foundation
import Testing
@testable import Sub2APIQuotaApp
@testable import Sub2APIQuotaCore

@Suite("StatusViewModelTests")
struct StatusViewModelTests {
    @Test
    func notConfiguredMenuText() {
        let model = StatusViewModel(status: .notConfigured, snapshot: nil, lastError: nil)

        #expect(model.title == "未配置")
        #expect(model.subtitle == "请先填写服务地址、邮箱和密码")
        #expect(model.colorName == "gray")
    }

    @Test
    func quotaMenuTextIncludesRemainingAndUnit() {
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "12.5")!,
            unit: "USD",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
        let model = StatusViewModel(status: .available, snapshot: snapshot, lastError: nil)

        #expect(model.title == "可用")
        #expect(model.subtitle == "剩余 12.5 USD")
        #expect(model.colorName == "green")
    }

    @Test
    func accountPoolMenuTextIncludesFiveHourAndSevenDayRemaining() {
        let summary = AccountPoolSummary(
            accountCount: 15,
            schedulableCount: 15,
            currentConcurrency: 1,
            concurrencyLimit: 150,
            remaining5hAccounts: Decimal(string: "11.72")!,
            remaining7dAccounts: Decimal(10),
            used5hPercent: Decimal(string: "21.87")!,
            used7dPercent: Decimal(string: "67.73")!,
            rateLimitedCount: 7
        )
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "11.72")!,
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
        let model = StatusViewModel(status: .available, snapshot: snapshot, lastError: nil)

        #expect(model.subtitle == "5h剩余 11.72 个，7d剩余 10 个")
        #expect(model.accountPoolText == "账号池 15/15 可用，限流 7")
        #expect(model.concurrencyText == "并发 1/150")
        #expect(model.fiveHourWindowText == "5小时窗口 剩余 11.72 个账号，已用 21.87%")
        #expect(model.sevenDayWindowText == "7天窗口 剩余 10 个账号，已用 67.73%")
        #expect(model.fiveHourRemainingShortText == "11.7")
        #expect(model.sevenDayRemainingShortText == "10")
        #expect(abs(model.fiveHourUsedFraction - 0.2187) < 0.0001)
        #expect(abs(model.sevenDayUsedFraction - 0.6773) < 0.0001)
        #expect(model.fiveHourRiskColorName == "green")
        #expect(model.sevenDayRiskColorName == "green")
    }

    @Test
    func availableAccountPoolKeepsRiskGreenWhenUsedPercentIsLow() {
        let summary = AccountPoolSummary(
            accountCount: 15,
            schedulableCount: 15,
            currentConcurrency: 1,
            concurrencyLimit: 150,
            remaining5hAccounts: Decimal(string: "6.72")!,
            remaining7dAccounts: Decimal(10),
            used5hPercent: Decimal(string: "4")!,
            used7dPercent: Decimal(string: "69.86")!,
            rateLimitedCount: 8
        )
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "6.72")!,
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
        let model = StatusViewModel(status: .available, snapshot: snapshot, lastError: nil)

        #expect(model.colorName == "green")
        #expect(model.fiveHourRiskColorName == "green")
        #expect(model.sevenDayRiskColorName == "green")
    }

    @Test
    func accountPoolTextRoundsLongDecimals() {
        let summary = AccountPoolSummary(
            accountCount: 15,
            schedulableCount: 15,
            currentConcurrency: 0,
            concurrencyLimit: 150,
            remaining5hAccounts: Decimal(string: "11.393333333333333333")!,
            remaining7dAccounts: Decimal(10),
            used5hPercent: Decimal(string: "24.066666666666666")!,
            used7dPercent: Decimal(string: "68.066666666666666")!
        )
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "11.39")!,
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
        let model = StatusViewModel(status: .available, snapshot: snapshot, lastError: nil)

        #expect(model.subtitle == "5h剩余 11.39 个，7d剩余 10 个")
        #expect(model.fiveHourWindowText == "5小时窗口 剩余 11.39 个账号，已用 24.07%")
        #expect(model.sevenDayWindowText == "7天窗口 剩余 10 个账号，已用 68.07%")
    }

    @Test
    func apiErrorShowsReadableReasonAndKeepsQuotaContext() {
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(11),
            unit: "USD",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )
        let model = StatusViewModel(status: .apiError(.authenticationFailed), snapshot: snapshot, lastError: .authenticationFailed)

        #expect(model.title == "接口错误")
        #expect(model.subtitle == "认证失败，上次剩余 11 USD")
        #expect(model.colorName == "red")
    }

    @Test
    func apiErrorOnlyTurnsStatusIndicatorRed() {
        let summary = AccountPoolSummary(
            accountCount: 3,
            schedulableCount: 3,
            currentConcurrency: 0,
            concurrencyLimit: 30,
            remaining5hAccounts: Decimal(string: "2.4")!,
            remaining7dAccounts: Decimal(3),
            used5hPercent: Decimal(20),
            used7dPercent: Decimal(30)
        )
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(string: "2.4")!,
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )

        let model = StatusViewModel(status: .apiError(.network), snapshot: snapshot, lastError: .network)

        #expect(model.colorName == "red")
        #expect(model.fiveHourRiskColorName == "green")
        #expect(model.sevenDayRiskColorName == "green")
    }

    @Test
    func accountRowsExposeWhetherUsageWindowsAreAvailable() {
        let summary = AccountPoolSummary(
            accountCount: 1,
            schedulableCount: 0,
            currentConcurrency: 0,
            concurrencyLimit: 100,
            remaining5hAccounts: Decimal(0),
            remaining7dAccounts: Decimal(0),
            used5hPercent: Decimal(100),
            used7dPercent: Decimal(100),
            accounts: [
                AccountQuotaDetail(
                    id: 3,
                    name: "ciii",
                    platform: "openai",
                    type: "apikey",
                    priority: 4,
                    status: "active",
                    schedulable: true,
                    currentConcurrency: 0,
                    concurrencyLimit: 100,
                    used5hPercent: Decimal(0),
                    used7dPercent: Decimal(0),
                    supportsUsageWindows: false
                )
            ]
        )
        let snapshot = QuotaSnapshot(
            available: false,
            remaining: Decimal(0),
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 100)
        )

        let model = StatusViewModel(status: .unavailable, snapshot: snapshot, lastError: nil)

        #expect(model.accountRows.first?.supportsUsageWindows == false)
        #expect(model.accountRows.first?.channelKind == .apiKey)
        #expect(model.accountRows.first?.priority == 4)
        #expect(model.accountRows.first?.priorityText == "P4")
        #expect(model.accountRows.first?.accountTypeText == "OpenAI API Key")
        #expect(model.accountRows.first?.concurrencyText == "0/100")
        #expect(model.accountRows.first?.metadataText == "")
    }

    @Test
    func statusDetailsIncludeUpdateTimesAndRequestDuration() {
        let snapshot = QuotaSnapshot(
            available: true,
            remaining: Decimal(1),
            unit: nil,
            backendUpdatedAt: Date(timeIntervalSince1970: 60),
            clientRefreshedAt: Date(timeIntervalSince1970: 120)
        )
        let model = StatusViewModel(
            status: .lowQuota,
            snapshot: snapshot,
            lastError: nil,
            lastRequestDuration: 0.42,
            dateFormatter: .testFormatter
        )

        #expect(model.title == "额度偏低")
        #expect(model.lastUpdatedText == "服务更新 1970-01-01 00:01:00")
        #expect(model.clientRefreshedText == "本机刷新 1970-01-01 00:02:00")
        #expect(model.requestDurationText == "请求耗时 0.42 秒")
    }
}

private extension DateFormatter {
    static var testFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}
