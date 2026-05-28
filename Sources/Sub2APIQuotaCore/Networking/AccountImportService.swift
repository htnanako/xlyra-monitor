import Foundation

public protocol AccountImporting {
    func importAccounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        payload: [String: Any]
    ) async throws -> AccountImportResult
}

public struct AccountImportService: AccountImporting {
    private let adminClient: Sub2APIAdminClient

    public init(httpClient: HTTPClient) {
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient)
    }

    public func importAccounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        payload: [String: Any]
    ) async throws -> AccountImportResult {
        let token = try await adminClient.login(configuration: configuration, credential: credential)
        var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/data"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "data": payload,
                "skip_default_group_bind": true
            ]
        )

        let response = try await adminClient.send(request)
        try adminClient.validateStatusCode(response.statusCode)
        let object = try adminClient.parseJSONObject(from: response.data)

        return AccountImportResult(
            accountCreated: parseInt(object["account_created"]),
            accountFailed: parseInt(object["account_failed"]),
            proxyCreated: parseInt(object["proxy_created"]),
            proxyReused: parseInt(object["proxy_reused"]),
            proxyFailed: parseInt(object["proxy_failed"]),
            errors: object["errors"] as? [String] ?? []
        )
    }

    private func parseInt(_ value: Any?) -> Int {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }
}

