import Foundation

public struct RevokedAccountCleanupResult: Equatable {
    public let matchedCount: Int
    public let deletedCount: Int
    public let failedCount: Int

    public init(matchedCount: Int, deletedCount: Int, failedCount: Int) {
        self.matchedCount = matchedCount
        self.deletedCount = deletedCount
        self.failedCount = failedCount
    }

    public var summary: String {
        "匹配 \(matchedCount) 个，删除 \(deletedCount) 个，失败 \(failedCount) 个"
    }
}

public protocol RevokedAccountCleaning {
    func deleteRevoked401Accounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential
    ) async throws -> RevokedAccountCleanupResult
}

public struct RevokedAccountCleanupService: RevokedAccountCleaning {
    private let adminClient: Sub2APIAdminClient

    public init(httpClient: HTTPClient) {
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient)
    }

    public func deleteRevoked401Accounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential
    ) async throws -> RevokedAccountCleanupResult {
        let token = try await adminClient.login(configuration: configuration, credential: credential)
        let accounts = try await fetchAccounts(configuration: configuration, token: token)
        let revokedAccounts = accounts.filter(isRevoked401Account)

        var deletedCount = 0
        var failedCount = 0
        for account in revokedAccounts {
            do {
                try await deleteAccount(id: account.id, configuration: configuration, token: token)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }

        return RevokedAccountCleanupResult(
            matchedCount: revokedAccounts.count,
            deletedCount: deletedCount,
            failedCount: failedCount
        )
    }

    private func fetchAccounts(configuration: ServiceConfiguration, token: String) async throws -> [CleanupAccount] {
        var components = URLComponents(
            url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "100"),
            URLQueryItem(name: "platform", value: "openai"),
            URLQueryItem(name: "type", value: ""),
            URLQueryItem(name: "status", value: "error"),
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

        let response = try await adminClient.send(request)
        try adminClient.validateStatusCode(response.statusCode)
        let object = try adminClient.parseJSONObject(from: response.data)

        guard let data = object["data"] as? [String: Any],
              let items = data["items"] as? [[String: Any]] else {
            throw QuotaErrorKind.invalidResponse
        }

        return items.compactMap { item in
            guard let id = parseInt(item["id"]) else {
                return nil
            }

            return CleanupAccount(
                id: id,
                status: adminClient.parseOptionalString(item["status"]),
                errorMessage: adminClient.parseOptionalString(item["error_message"])
            )
        }
    }

    private func deleteAccount(id: Int, configuration: ServiceConfiguration, token: String) async throws {
        var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response = try await adminClient.send(request)
        try adminClient.validateStatusCode(response.statusCode)
    }

    private func isRevoked401Account(_ account: CleanupAccount) -> Bool {
        guard account.status == "error" else {
            return false
        }

        let message = account.errorMessage.lowercased()
        return message.contains("token revoked") && message.contains("401")
    }

    private func parseInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }

        return number.intValue
    }
}

private struct CleanupAccount {
    let id: Int
    let status: String?
    let errorMessage: String

    init(id: Int, status: String?, errorMessage: String?) {
        self.id = id
        self.status = status
        self.errorMessage = errorMessage ?? ""
    }
}
