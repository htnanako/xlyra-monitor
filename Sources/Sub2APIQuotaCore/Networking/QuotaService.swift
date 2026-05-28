import Foundation

public protocol QuotaFetching {
    func fetchQuota(
        configuration: ServiceConfiguration,
        apiKey: String,
        inspectedAPIKey: String?
    ) async throws -> QuotaSnapshot
}

public struct QuotaService: QuotaFetching {
    private let httpClient: HTTPClient
    private let now: () -> Date
    private let iso8601DateFormatter: ISO8601DateFormatter
    private let jsonEncoder: JSONEncoder
    private let adminClient: Sub2APIAdminClient

    public init(
        httpClient: HTTPClient,
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.now = now
        self.iso8601DateFormatter = ISO8601DateFormatter()
        self.iso8601DateFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        self.jsonEncoder = JSONEncoder()
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient, jsonEncoder: jsonEncoder)
    }

    public func fetchQuota(
        configuration: ServiceConfiguration,
        apiKey: String,
        inspectedAPIKey: String? = nil
    ) async throws -> QuotaSnapshot {
        if let loginCredential = LoginCredential(rawValue: apiKey) {
            return try await fetchSub2APIProfileQuota(
                configuration: configuration,
                credential: loginCredential,
                inspectedAPIKey: inspectedAPIKey
            )
        }

        return try await fetchLegacyQuota(configuration: configuration, apiKey: apiKey)
    }

    private func fetchLegacyQuota(
        configuration: ServiceConfiguration,
        apiKey: String
    ) async throws -> QuotaSnapshot {
        var request = URLRequest(url: configuration.quotaURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: HTTPResponse
        do {
            response = try await httpClient.send(request, timeout: 10)
        } catch let error as QuotaErrorKind {
            throw error
        } catch let error as URLError {
            throw map(urlError: error)
        } catch {
            throw QuotaErrorKind.network
        }

        try validateStatusCode(response.statusCode)
        return try parseLegacyQuotaSnapshot(from: response.data)
    }

    private func fetchSub2APIProfileQuota(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        inspectedAPIKey: String?
    ) async throws -> QuotaSnapshot {
        let token = try await login(configuration: configuration, credential: credential)
        let accountsData = try await sendAccountsRequest(configuration: configuration, token: token)
        let accountIDs = try parseAccountIDs(from: accountsData)
        let usageByAccountID = try await sendAccountUsageRequests(
            configuration: configuration,
            token: token,
            accountIDs: accountIDs
        )
        var snapshot = try parseAccountPoolSnapshot(from: accountsData, usageByAccountID: usageByAccountID)
        if let inspectedAPIKey,
           inspectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let summary = try await fetchInspectedAPIKeySummary(
                configuration: configuration,
                token: token,
                apiKey: inspectedAPIKey
            )
            snapshot = snapshot.withInspectedAPIKey(summary)
        }

        return snapshot
    }

    private func login(
        configuration: ServiceConfiguration,
        credential: LoginCredential
    ) async throws -> String {
        try await adminClient.login(configuration: configuration, credential: credential)
    }

    private func sendAccountsRequest(configuration: ServiceConfiguration, token: String) async throws -> Data {
        var components = URLComponents(
            url: apiURL(configuration: configuration, path: "api/v1/admin/accounts"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "100"),
            URLQueryItem(name: "platform", value: "openai"),
            URLQueryItem(name: "type", value: ""),
            URLQueryItem(name: "status", value: ""),
            URLQueryItem(name: "privacy_mode", value: ""),
            URLQueryItem(name: "group", value: ""),
            URLQueryItem(name: "search", value: ""),
            URLQueryItem(name: "sort_by", value: "name"),
            URLQueryItem(name: "sort_order", value: "asc"),
            URLQueryItem(name: "lite", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await send(request)
        try validateStatusCode(response.statusCode)
        return response.data
    }

    private func sendAccountUsageRequests(
        configuration: ServiceConfiguration,
        token: String,
        accountIDs: [Int]
    ) async throws -> [Int: AccountUsageSnapshot] {
        var usageByAccountID: [Int: AccountUsageSnapshot] = [:]

        for accountID in accountIDs {
            do {
                let data = try await sendAccountUsageRequest(
                    configuration: configuration,
                    token: token,
                    accountID: accountID
                )
                usageByAccountID[accountID] = try parseAccountUsageSnapshot(from: data)
            } catch {
                continue
            }
        }

        return usageByAccountID
    }

    private func sendAccountUsageRequest(
        configuration: ServiceConfiguration,
        token: String,
        accountID: Int
    ) async throws -> Data {
        let url = apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(accountID)/usage")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await send(request)
        try validateStatusCode(response.statusCode)
        return response.data
    }

    private func sendKeysRequest(configuration: ServiceConfiguration, token: String) async throws -> Data {
        var components = URLComponents(
            url: apiURL(configuration: configuration, path: "api/v1/keys"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "100")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await send(request)
        try validateStatusCode(response.statusCode)
        return response.data
    }

    private func sendAPIKeyUsagePageRequest(
        configuration: ServiceConfiguration,
        token: String,
        apiKeyID: Int,
        page: Int,
        pageSize: Int
    ) async throws -> Data {
        var components = URLComponents(
            url: apiURL(configuration: configuration, path: "api/v1/admin/usage"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "api_key_id", value: String(apiKeyID))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await send(request)
        try validateStatusCode(response.statusCode)
        return response.data
    }

    private func fetchInspectedAPIKeySummary(
        configuration: ServiceConfiguration,
        token: String,
        apiKey: String
    ) async throws -> APIKeyUsageSummary? {
        let keysData = try await sendKeysRequest(configuration: configuration, token: token)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let keyPayload = try parseAPIKeyPayload(from: keysData, matching: trimmedAPIKey) else {
            return APIKeyUsageSummary(
                id: -1,
                name: "未找到",
                keyPreview: previewAPIKey(trimmedAPIKey),
                status: "未找到",
                quota: Decimal(0),
                quotaUsed: Decimal(0),
                requests: 0,
                tokens: 0,
                actualCost: Decimal(0),
                userCost: Decimal(0)
            )
        }

        let usage = try await fetchAPIKeyUsageTotals(
            configuration: configuration,
            token: token,
            apiKeyID: keyPayload.id
        )

        return APIKeyUsageSummary(
            id: keyPayload.id,
            name: keyPayload.name,
            keyPreview: keyPayload.keyPreview,
            groupName: keyPayload.groupName,
            status: keyPayload.status,
            quota: keyPayload.quota,
            quotaUsed: keyPayload.quotaUsed,
            expiresAt: keyPayload.expiresAt,
            lastUsedAt: keyPayload.lastUsedAt,
            requests: usage.requests,
            tokens: usage.tokens,
            actualCost: usage.actualCost,
            userCost: usage.userCost
        )
    }

    private func fetchAPIKeyUsageTotals(
        configuration: ServiceConfiguration,
        token: String,
        apiKeyID: Int
    ) async throws -> UsageWindowStats {
        let pageSize = 500
        var page = 1
        var pages = 1
        var requests = 0
        var tokens = 0
        var actualCost = Decimal(0)
        var userCost = Decimal(0)

        repeat {
            let data = try await sendAPIKeyUsagePageRequest(
                configuration: configuration,
                token: token,
                apiKeyID: apiKeyID,
                page: page,
                pageSize: pageSize
            )
            let pagePayload = try parseUsageLogPage(from: data)
            pages = pagePayload.pages
            requests += pagePayload.items.count
            for item in pagePayload.items {
                tokens += item.tokens
                actualCost += item.actualCost
                userCost += item.userCost
            }
            page += 1
        } while page <= pages && page <= 20

        return UsageWindowStats(
            requests: requests,
            tokens: tokens,
            actualCost: actualCost,
            userCost: userCost
        )
    }

    private func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            return try await httpClient.send(request, timeout: 10)
        } catch let error as QuotaErrorKind {
            throw error
        } catch let error as URLError {
            throw map(urlError: error)
        } catch {
            throw QuotaErrorKind.network
        }
    }

    private func apiURL(configuration: ServiceConfiguration, path: String) -> URL {
        var components = URLComponents(url: configuration.serviceRoot, resolvingAgainstBaseURL: false)!
        let basePath = components.path.isEmpty ? "/" : components.path
        components.path = (basePath as NSString).appendingPathComponent(path)
        return components.url!
    }

    private func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200:
            return
        case 401, 403:
            throw QuotaErrorKind.authenticationFailed
        case 500...599:
            throw QuotaErrorKind.serviceUnavailable
        default:
            throw QuotaErrorKind.invalidResponse
        }
    }

    private func map(urlError: URLError) -> QuotaErrorKind {
        if urlError.code == .timedOut {
            return .timeout
        }

        return .network
    }

    private func parseLegacyQuotaSnapshot(from data: Data) throws -> QuotaSnapshot {
        let payload = try parseJSONObject(from: data)

        guard let available = payload["available"] as? Bool else {
            throw QuotaErrorKind.invalidResponse
        }

        let remaining = try parseRemaining(payload["remaining"])
        let unit = parseOptionalString(payload["unit"])
        let backendUpdatedAt = try parseOptionalDate(payload["updated_at"])

        return QuotaSnapshot(
            available: available,
            remaining: remaining,
            unit: unit,
            backendUpdatedAt: backendUpdatedAt,
            clientRefreshedAt: now()
        )
    }

    private func parseAccountIDs(from data: Data) throws -> [Int] {
        let items = try parseAccountItems(from: data)
        return items.compactMap { parseOptionalInt($0["id"]) }
    }

    private func parseAccountItems(from data: Data) throws -> [[String: Any]] {
        let payload = try parseJSONObject(from: data)

        guard let data = payload["data"] as? [String: Any],
              let items = data["items"] as? [[String: Any]] else {
            throw QuotaErrorKind.invalidResponse
        }

        guard items.isEmpty == false else {
            throw QuotaErrorKind.invalidResponse
        }

        return items
    }

    private func parseAccountUsageSnapshot(from data: Data) throws -> AccountUsageSnapshot {
        let payload = try parseJSONObject(from: data)
        let usagePayload: [String: Any]
        if let data = payload["data"] as? [String: Any] {
            usagePayload = data
        } else {
            usagePayload = payload
        }

        let fiveHour = try parseUsageWindow(usagePayload["five_hour"])
        let sevenDay = try parseUsageWindow(usagePayload["seven_day"])
        let updatedAt = try parseOptionalDate(usagePayload["updated_at"])

        return AccountUsageSnapshot(
            fiveHourUsedPercent: fiveHour.usedPercent,
            sevenDayUsedPercent: sevenDay.usedPercent,
            fiveHourResetAt: fiveHour.resetsAt,
            sevenDayResetAt: sevenDay.resetsAt,
            fiveHourStats: fiveHour.stats,
            sevenDayStats: sevenDay.stats,
            updatedAt: updatedAt
        )
    }

    private func parseUsageWindow(_ value: Any?) throws -> UsageWindowSnapshot {
        guard let payload = value as? [String: Any] else {
            throw QuotaErrorKind.invalidResponse
        }

        return UsageWindowSnapshot(
            usedPercent: clampPercent(try parseRemaining(payload["utilization"])),
            resetsAt: try parseOptionalDate(payload["resets_at"]),
            stats: try parseOptionalUsageWindowStats(payload["window_stats"])
        )
    }

    private func parseOptionalUsageWindowStats(_ value: Any?) throws -> UsageWindowStats? {
        guard let payload = value as? [String: Any] else {
            return nil
        }

        return UsageWindowStats(
            requests: parseOptionalInt(payload["requests"]) ?? 0,
            tokens: parseOptionalInt(payload["tokens"]) ?? 0,
            actualCost: parseOptionalDecimal(payload["standard_cost"])
                ?? parseOptionalDecimal(payload["cost"])
                ?? Decimal(0),
            userCost: parseOptionalDecimal(payload["user_cost"])
                ?? parseOptionalDecimal(payload["cost"])
                ?? Decimal(0)
        )
    }

    private func parseAccountPoolSnapshot(
        from data: Data,
        usageByAccountID: [Int: AccountUsageSnapshot] = [:]
    ) throws -> QuotaSnapshot {
        let items = try parseAccountItems(from: data)

        var usableChannelCount = 0
        var quotaWindowAccountCount = 0
        var rateLimitedCount = 0
        var currentConcurrency = 0
        var concurrencyLimit = 0
        var remaining5hPercent = Decimal(0)
        var sevenDayAccountCount = 0
        var remaining7dAccountCount = 0
        var used5hPercent = Decimal(0)
        var used7dPercent = Decimal(0)
        var newestUpdatedAt: Date?
        var accountDetails: [AccountQuotaDetail] = []
        let refreshStartedAt = now()

        for (index, item) in items.enumerated() {
            let rateLimitResetAt = try parseOptionalDate(item["rate_limit_reset_at"])
            let isRateLimited = rateLimitResetAt.map { $0 > refreshStartedAt } ?? false
            let isSchedulable = item["schedulable"] as? Bool == true
            let status = parseOptionalString(item["status"]) ?? "--"
            let isActive = status == "active"

            if isRateLimited {
                rateLimitedCount += 1
            }

            let isUsableAccount = isActive && isSchedulable
            let isAvailableForFiveHourQuota = isUsableAccount && isRateLimited == false
            if isAvailableForFiveHourQuota {
                usableChannelCount += 1
            }

            currentConcurrency += parseOptionalInt(item["current_concurrency"]) ?? 0
            concurrencyLimit += parseOptionalInt(item["concurrency"]) ?? 0

            let extra = item["extra"] as? [String: Any]

            let hasUsageWindowMetadata = hasCodexUsageWindowMetadata(extra)
            let used5h = parseOptionalPercent(extra?["codex_5h_used_percent"]) ?? Decimal(0)
            let used7d = parseOptionalPercent(extra?["codex_7d_used_percent"]) ?? Decimal(0)
            let usage = parseOptionalInt(item["id"]).flatMap { usageByAccountID[$0] }
            let supportsUsageWindows = usage != nil || hasUsageWindowMetadata
            let effectiveUsed5h = usage?.fiveHourUsedPercent ?? used5h
            let effectiveUsed7d = usage?.sevenDayUsedPercent ?? used7d
            let accountID = parseOptionalInt(item["id"]) ?? -(index + 1)
            let accountName = parseOptionalString(item["name"]) ?? "账号 \(index + 1)"
            let accountPlatform = parseOptionalString(item["platform"]) ?? "--"
            let accountType = parseOptionalString(item["type"]) ?? "--"
            let groupNames = parseGroupNames(item)
            let accountEmail = parseOptionalString(extra?["email"])
            let privacyMode = parseOptionalString(extra?["privacy_mode"])
            let priority = parseOptionalInt(item["priority"]) ?? parseOptionalInt(extra?["priority"])
            let reset5hAt: Date?
            if let usageReset5hAt = usage?.fiveHourResetAt {
                reset5hAt = usageReset5hAt
            } else {
                reset5hAt = try parseOptionalDate(extra?["codex_5h_reset_at"])
            }
            let reset7dAt: Date?
            if let usageReset7dAt = usage?.sevenDayResetAt {
                reset7dAt = usageReset7dAt
            } else {
                reset7dAt = try parseOptionalDate(extra?["codex_7d_reset_at"])
            }
            let accountConcurrency = parseOptionalInt(item["current_concurrency"]) ?? 0
            let accountConcurrencyLimit = parseOptionalInt(item["concurrency"]) ?? 0
            if supportsUsageWindows && isAvailableForFiveHourQuota {
                quotaWindowAccountCount += 1
                used5hPercent += effectiveUsed5h
                remaining5hPercent += max(Decimal(0), Decimal(100) - effectiveUsed5h)
            }

            if supportsUsageWindows && isUsableAccount {
                sevenDayAccountCount += 1
                used7dPercent += effectiveUsed7d
                if effectiveUsed7d < Decimal(100) {
                    remaining7dAccountCount += 1
                }
            }

            let updatedAt: Date?
            if let usageUpdatedAt = usage?.updatedAt {
                updatedAt = usageUpdatedAt
            } else {
                updatedAt = try parseOptionalDate(extra?["codex_usage_updated_at"])
            }
            if let updatedAt,
               newestUpdatedAt == nil || updatedAt > newestUpdatedAt! {
                newestUpdatedAt = updatedAt
            }

            accountDetails.append(AccountQuotaDetail(
                id: accountID,
                name: accountName,
                platform: accountPlatform,
                type: accountType,
                groupNames: groupNames,
                email: accountEmail,
                privacyMode: privacyMode,
                priority: priority,
                status: status,
                schedulable: isSchedulable,
                rateLimitedUntil: isRateLimited ? rateLimitResetAt : nil,
                currentConcurrency: accountConcurrency,
                concurrencyLimit: accountConcurrencyLimit,
                used5hPercent: effectiveUsed5h,
                used7dPercent: effectiveUsed7d,
                reset5hAt: reset5hAt,
                reset7dAt: reset7dAt,
                fiveHourStats: usage?.fiveHourStats,
                sevenDayStats: usage?.sevenDayStats,
                usageUpdatedAt: updatedAt,
                supportsUsageWindows: supportsUsageWindows
            ))
        }

        let accountCount = items.count
        let remaining5hAccounts = remaining5hPercent / Decimal(100)
        let remaining7dAccounts = Decimal(remaining7dAccountCount)
        let averageUsed5h = quotaWindowAccountCount > 0 ? used5hPercent / Decimal(quotaWindowAccountCount) : Decimal(0)
        let averageUsed7d = sevenDayAccountCount > 0 ? used7dPercent / Decimal(sevenDayAccountCount) : Decimal(0)
        let summary = AccountPoolSummary(
            accountCount: accountCount,
            schedulableCount: usableChannelCount,
            currentConcurrency: currentConcurrency,
            concurrencyLimit: concurrencyLimit,
            remaining5hAccounts: remaining5hAccounts,
            remaining7dAccounts: remaining7dAccounts,
            used5hPercent: averageUsed5h,
            used7dPercent: averageUsed7d,
            rateLimitedCount: rateLimitedCount,
            accounts: accountDetails
        )

        return QuotaSnapshot(
            available: usableChannelCount > 0,
            remaining: remaining5hAccounts,
            unit: "账号/5h",
            poolSummary: summary,
            backendUpdatedAt: newestUpdatedAt,
            clientRefreshedAt: now()
        )
    }

    private func hasCodexUsageWindowMetadata(_ extra: [String: Any]?) -> Bool {
        guard let extra else {
            return false
        }

        return extra.keys.contains { key in
            key.hasPrefix("codex_5h_")
                || key.hasPrefix("codex_7d_")
                || key == "codex_usage_updated_at"
        }
    }

    private func parseJSONObject(from data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw QuotaErrorKind.invalidResponse
        }

        guard let payload = object as? [String: Any] else {
            throw QuotaErrorKind.invalidResponse
        }

        return payload
    }

    private func parseAPIKeyPayload(from data: Data, matching apiKey: String) throws -> APIKeyPayload? {
        let payload = try parseJSONObject(from: data)
        guard let data = payload["data"] as? [String: Any],
              let items = data["items"] as? [[String: Any]] else {
            throw QuotaErrorKind.invalidResponse
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = items.first(where: { parseOptionalString($0["key"]) == trimmedAPIKey }) else {
            return nil
        }

        let group = item["group"] as? [String: Any]
        let key = parseOptionalString(item["key"]) ?? trimmedAPIKey
        return APIKeyPayload(
            id: parseOptionalInt(item["id"]) ?? -1,
            name: parseOptionalString(item["name"]) ?? "API Key",
            keyPreview: previewAPIKey(key),
            groupName: parseOptionalString(group?["name"]),
            status: parseOptionalString(item["status"]) ?? "--",
            quota: parseOptionalDecimal(item["quota"]) ?? Decimal(0),
            quotaUsed: parseOptionalDecimal(item["quota_used"]) ?? Decimal(0),
            expiresAt: try parseOptionalDate(item["expires_at"]),
            lastUsedAt: try parseOptionalDate(item["last_used_at"])
        )
    }

    private func parseUsageLogPage(from data: Data) throws -> UsageLogPage {
        let payload = try parseJSONObject(from: data)
        guard let data = payload["data"] as? [String: Any],
              let items = data["items"] as? [[String: Any]] else {
            throw QuotaErrorKind.invalidResponse
        }

        let pages = parseOptionalInt(data["pages"]) ?? 1
        let parsedItems = items.map { item in
            UsageLogItem(
                tokens: parseTokenTotal(item),
                actualCost: parseOptionalDecimal(item["actual_cost"])
                    ?? parseOptionalDecimal(item["total_cost"])
                    ?? Decimal(0),
                userCost: parseOptionalDecimal(item["total_cost"])
                    ?? parseOptionalDecimal(item["actual_cost"])
                    ?? Decimal(0)
            )
        }

        return UsageLogPage(pages: max(1, pages), items: parsedItems)
    }

    private func parseTokenTotal(_ item: [String: Any]) -> Int {
        [
            "input_tokens",
            "output_tokens",
            "cache_creation_tokens",
            "cache_read_tokens",
            "cache_creation_5m_tokens",
            "cache_creation_1h_tokens"
        ].reduce(0) { total, key in
            total + (parseOptionalInt(item[key]) ?? 0)
        }
    }

    private func parseRemaining(_ value: Any?) throws -> Decimal {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else {
            throw QuotaErrorKind.invalidResponse
        }

        let text = number.description(withLocale: Locale(identifier: "en_US_POSIX"))
        guard let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw QuotaErrorKind.invalidResponse
        }

        return decimal
    }

    private func parseOptionalDecimal(_ value: Any?) -> Decimal? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite else {
            return nil
        }

        let text = number.description(withLocale: Locale(identifier: "en_US_POSIX"))
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func parseOptionalString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseOptionalInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }

        return number.intValue
    }

    private func parseGroupNames(_ item: [String: Any]) -> [String] {
        if let groups = item["groups"] as? [[String: Any]] {
            let names = groups.compactMap { parseOptionalString($0["name"]) }
            if names.isEmpty == false {
                return names
            }
        }

        if let group = item["group"] as? [String: Any],
           let name = parseOptionalString(group["name"]) {
            return [name]
        }

        return []
    }

    private func parseOptionalPercent(_ value: Any?) -> Decimal? {
        guard let value else {
            return nil
        }

        return try? clampPercent(parseRemaining(value))
    }

    private func clampPercent(_ percent: Decimal) -> Decimal {
        min(Decimal(100), max(Decimal(0), percent))
    }

    private func parseOptionalDate(_ value: Any?) throws -> Date? {
        guard let updatedAt = parseOptionalString(value) else {
            return nil
        }

        if let date = iso8601DateFormatter.date(from: updatedAt) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        guard let date = fallbackFormatter.date(from: updatedAt) else {
            throw QuotaErrorKind.invalidResponse
        }

        return date
    }

    private func previewAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 18 else {
            return apiKey
        }

        return "\(apiKey.prefix(10))...\(apiKey.suffix(6))"
    }
}

private struct AccountUsageSnapshot {
    let fiveHourUsedPercent: Decimal
    let sevenDayUsedPercent: Decimal
    let fiveHourResetAt: Date?
    let sevenDayResetAt: Date?
    let fiveHourStats: UsageWindowStats?
    let sevenDayStats: UsageWindowStats?
    let updatedAt: Date?
}

private struct UsageWindowSnapshot {
    let usedPercent: Decimal
    let resetsAt: Date?
    let stats: UsageWindowStats?
}

private struct APIKeyPayload {
    let id: Int
    let name: String
    let keyPreview: String
    let groupName: String?
    let status: String
    let quota: Decimal
    let quotaUsed: Decimal
    let expiresAt: Date?
    let lastUsedAt: Date?
}

private struct UsageLogPage {
    let pages: Int
    let items: [UsageLogItem]
}

private struct UsageLogItem {
    let tokens: Int
    let actualCost: Decimal
    let userCost: Decimal
}

private extension QuotaSnapshot {
    func withInspectedAPIKey(_ inspectedAPIKey: APIKeyUsageSummary?) -> QuotaSnapshot {
        QuotaSnapshot(
            available: available,
            remaining: remaining,
            unit: unit,
            poolSummary: poolSummary,
            inspectedAPIKey: inspectedAPIKey,
            backendUpdatedAt: backendUpdatedAt,
            clientRefreshedAt: clientRefreshedAt
        )
    }
}
