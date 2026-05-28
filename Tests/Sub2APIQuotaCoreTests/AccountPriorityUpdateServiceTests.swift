import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("AccountPriorityUpdateServiceTests")
struct AccountPriorityUpdateServiceTests {
    @Test
    func updatesAccountPriorityThroughAdminEndpoint() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let updateData = #"{"code":0,"message":"success"}"#.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: updateData))
            ]
        )
        let service = AccountPriorityUpdateService(httpClient: http)

        try await service.updatePriority(
            configuration: try ServiceURLNormalizer.normalize("https://example.com/sub2api"),
            credential: LoginCredential(email: "admin@example.com", password: "secret"),
            accountID: 7,
            priority: 2
        )

        #expect(http.receivedRequests.count == 2)
        #expect(http.receivedRequests[0].url?.absoluteString == "https://example.com/sub2api/api/v1/auth/login")
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/7")
        #expect(http.receivedRequests[1].httpMethod == "PUT")
        #expect(http.receivedRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
        #expect(http.receivedRequests[1].value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(JSONSerialization.jsonObject(with: http.receivedRequests[1].httpBody ?? Data()) as? [String: Int])
        #expect(body == ["priority": 2])
    }
}
