import Foundation

public enum QuotaStatus: Equatable {
    case notConfigured
    case available
    case lowQuota
    case unavailable
    case apiError(QuotaErrorKind)

    public var menuBarColorName: String {
        switch self {
        case .notConfigured:
            return "gray"
        case .available:
            return "green"
        case .lowQuota:
            return "yellow"
        case .unavailable, .apiError:
            return "red"
        }
    }

    public var isAPIError: Bool {
        if case .apiError = self {
            return true
        }

        return false
    }
}

public enum QuotaErrorKind: Error, Equatable {
    case invalidConfiguration
    case authenticationFailed
    case timeout
    case network
    case serviceUnavailable
    case invalidResponse
    case credentialReadFailed
    case credentialWriteFailed
}

public struct QuotaSnapshot: Equatable {
    public let available: Bool
    public let remaining: Decimal
    public let unit: String?
    public let poolSummary: AccountPoolSummary?
    public let inspectedAPIKey: APIKeyUsageSummary?
    public let backendUpdatedAt: Date?
    public let clientRefreshedAt: Date

    public init(
        available: Bool,
        remaining: Decimal,
        unit: String?,
        poolSummary: AccountPoolSummary? = nil,
        inspectedAPIKey: APIKeyUsageSummary? = nil,
        backendUpdatedAt: Date?,
        clientRefreshedAt: Date
    ) {
        self.available = available
        self.remaining = remaining
        self.unit = unit
        self.poolSummary = poolSummary
        self.inspectedAPIKey = inspectedAPIKey
        self.backendUpdatedAt = backendUpdatedAt
        self.clientRefreshedAt = clientRefreshedAt
    }

    public var displayUnit: String {
        guard let unit else {
            return "额度"
        }

        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUnit.isEmpty == false else {
            return "额度"
        }

        return trimmedUnit
    }

    public var menuLastUpdatedAt: Date {
        backendUpdatedAt ?? clientRefreshedAt
    }
}

public struct AccountPoolSummary: Equatable {
    public let accountCount: Int
    public let schedulableCount: Int
    public let currentConcurrency: Int
    public let concurrencyLimit: Int
    public let remaining5hAccounts: Decimal
    public let remaining7dAccounts: Decimal
    public let used5hPercent: Decimal
    public let used7dPercent: Decimal
    public let rateLimitedCount: Int
    public let accounts: [AccountQuotaDetail]

    public var isFiveHourLowQuota: Bool {
        used5hPercent >= Decimal(95)
    }

    public var isSevenDayExhausted: Bool {
        used7dPercent >= Decimal(100)
    }

    public init(
        accountCount: Int,
        schedulableCount: Int,
        currentConcurrency: Int,
        concurrencyLimit: Int,
        remaining5hAccounts: Decimal,
        remaining7dAccounts: Decimal,
        used5hPercent: Decimal,
        used7dPercent: Decimal,
        rateLimitedCount: Int = 0,
        accounts: [AccountQuotaDetail] = []
    ) {
        self.accountCount = accountCount
        self.schedulableCount = schedulableCount
        self.currentConcurrency = currentConcurrency
        self.concurrencyLimit = concurrencyLimit
        self.remaining5hAccounts = remaining5hAccounts
        self.remaining7dAccounts = remaining7dAccounts
        self.used5hPercent = used5hPercent
        self.used7dPercent = used7dPercent
        self.rateLimitedCount = rateLimitedCount
        self.accounts = accounts
    }
}

public struct AccountQuotaDetail: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let platform: String
    public let type: String
    public let groupNames: [String]
    public let email: String?
    public let privacyMode: String?
    public let priority: Int?
    public let status: String
    public let schedulable: Bool
    public let rateLimitedUntil: Date?
    public let currentConcurrency: Int
    public let concurrencyLimit: Int
    public let used5hPercent: Decimal
    public let used7dPercent: Decimal
    public let reset5hAt: Date?
    public let reset7dAt: Date?
    public let fiveHourStats: UsageWindowStats?
    public let sevenDayStats: UsageWindowStats?
    public let usageUpdatedAt: Date?
    public let supportsUsageWindows: Bool

    public var isRateLimited: Bool {
        rateLimitedUntil != nil
    }

    public init(
        id: Int,
        name: String,
        platform: String,
        type: String,
        groupNames: [String] = [],
        email: String? = nil,
        privacyMode: String? = nil,
        priority: Int? = nil,
        status: String,
        schedulable: Bool,
        rateLimitedUntil: Date? = nil,
        currentConcurrency: Int,
        concurrencyLimit: Int,
        used5hPercent: Decimal,
        used7dPercent: Decimal,
        reset5hAt: Date? = nil,
        reset7dAt: Date? = nil,
        fiveHourStats: UsageWindowStats? = nil,
        sevenDayStats: UsageWindowStats? = nil,
        usageUpdatedAt: Date? = nil,
        supportsUsageWindows: Bool = true
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.type = type
        self.groupNames = groupNames
        self.email = email
        self.privacyMode = privacyMode
        self.priority = priority
        self.status = status
        self.schedulable = schedulable
        self.rateLimitedUntil = rateLimitedUntil
        self.currentConcurrency = currentConcurrency
        self.concurrencyLimit = concurrencyLimit
        self.used5hPercent = used5hPercent
        self.used7dPercent = used7dPercent
        self.reset5hAt = reset5hAt
        self.reset7dAt = reset7dAt
        self.fiveHourStats = fiveHourStats
        self.sevenDayStats = sevenDayStats
        self.usageUpdatedAt = usageUpdatedAt
        self.supportsUsageWindows = supportsUsageWindows
    }
}

public struct UsageWindowStats: Equatable {
    public let requests: Int
    public let tokens: Int
    public let actualCost: Decimal
    public let userCost: Decimal

    public init(
        requests: Int,
        tokens: Int,
        actualCost: Decimal,
        userCost: Decimal
    ) {
        self.requests = requests
        self.tokens = tokens
        self.actualCost = actualCost
        self.userCost = userCost
    }
}

public struct KeyAvailabilitySample: Equatable, Identifiable {
    public let id: UUID
    public let accountID: Int
    public let checkedAt: Date
    public let isAvailable: Bool
    public let latency: TimeInterval?

    public init(
        id: UUID = UUID(),
        accountID: Int,
        checkedAt: Date,
        isAvailable: Bool,
        latency: TimeInterval?
    ) {
        self.id = id
        self.accountID = accountID
        self.checkedAt = checkedAt
        self.isAvailable = isAvailable
        self.latency = latency
    }
}

public struct KeyAvailabilitySummary: Equatable {
    public let accountID: Int
    public let samples: [KeyAvailabilitySample]
    public let windowHours: Int

    public init(accountID: Int, samples: [KeyAvailabilitySample], windowHours: Int = 24) {
        self.accountID = accountID
        self.samples = samples
        self.windowHours = windowHours
    }

    public var sampleCount: Int {
        samples.count
    }

    public var availableCount: Int {
        samples.filter(\.isAvailable).count
    }

    public var availabilityPercent: Double? {
        guard sampleCount > 0 else {
            return nil
        }

        return Double(availableCount) / Double(sampleCount) * 100
    }

    public var latestLatency: TimeInterval? {
        samples.last?.latency
    }

    public var latestCheckedAt: Date? {
        samples.last?.checkedAt
    }
}

public struct KeyAvailabilityProbeResult: Equatable {
    public let accountID: Int
    public let checkedAt: Date
    public let isAvailable: Bool
    public let latency: TimeInterval?

    public init(
        accountID: Int,
        checkedAt: Date,
        isAvailable: Bool,
        latency: TimeInterval?
    ) {
        self.accountID = accountID
        self.checkedAt = checkedAt
        self.isAvailable = isAvailable
        self.latency = latency
    }
}

public struct APIKeyUsageSummary: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let keyPreview: String
    public let groupName: String?
    public let status: String
    public let quota: Decimal
    public let quotaUsed: Decimal
    public let expiresAt: Date?
    public let lastUsedAt: Date?
    public let requests: Int
    public let tokens: Int
    public let actualCost: Decimal
    public let userCost: Decimal

    public init(
        id: Int,
        name: String,
        keyPreview: String,
        groupName: String? = nil,
        status: String,
        quota: Decimal,
        quotaUsed: Decimal,
        expiresAt: Date? = nil,
        lastUsedAt: Date? = nil,
        requests: Int,
        tokens: Int,
        actualCost: Decimal,
        userCost: Decimal
    ) {
        self.id = id
        self.name = name
        self.keyPreview = keyPreview
        self.groupName = groupName
        self.status = status
        self.quota = quota
        self.quotaUsed = quotaUsed
        self.expiresAt = expiresAt
        self.lastUsedAt = lastUsedAt
        self.requests = requests
        self.tokens = tokens
        self.actualCost = actualCost
        self.userCost = userCost
    }
}
