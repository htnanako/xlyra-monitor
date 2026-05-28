import Foundation

public protocol AccountPriorityUpdating {
    func updatePriority(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        accountID: Int,
        priority: Int
    ) async throws
}

public struct AccountPriorityUpdateService: AccountPriorityUpdating {
    private let adminClient: Sub2APIAdminClient
    private let jsonEncoder: JSONEncoder

    public init(httpClient: HTTPClient) {
        let jsonEncoder = JSONEncoder()
        self.jsonEncoder = jsonEncoder
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient, jsonEncoder: jsonEncoder)
    }

    public func updatePriority(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        accountID: Int,
        priority: Int
    ) async throws {
        let token = try await adminClient.login(configuration: configuration, credential: credential)
        var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(accountID)"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(AccountPriorityUpdateRequest(priority: priority))

        let response = try await adminClient.send(request)
        try adminClient.validateStatusCode(response.statusCode)
    }
}

private struct AccountPriorityUpdateRequest: Encodable {
    let priority: Int
}
