import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("RevokedAccountCleanupServiceTests")
struct RevokedAccountCleanupServiceTests {
    @Test
    func deletesOnlyTokenRevoked401ErrorAccounts() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "data": {
            "total": 3,
            "items": [
              {
                "id": 1,
                "status": "error",
                "error_message": "Token revoked (401): Your authentication token has been invalidated."
              },
              {
                "id": 2,
                "status": "error",
                "error_message": "quota exceeded (429)"
              },
              {
                "id": 3,
                "status": "active",
                "error_message": "Token revoked (401): stale"
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let deleteData = #"{"code":0,"message":"success"}"#.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 200, data: deleteData))
            ]
        )
        let service = RevokedAccountCleanupService(httpClient: http)

        let result = try await service.deleteRevoked401Accounts(
            configuration: try ServiceURLNormalizer.normalize("https://example.com/sub2api"),
            credential: LoginCredential(email: "admin@example.com", password: "secret")
        )

        #expect(result == RevokedAccountCleanupResult(matchedCount: 1, deletedCount: 1, failedCount: 0))
        #expect(http.receivedRequests.count == 3)
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts?page=1&page_size=100&platform=openai&type=&status=error&privacy_mode=&group=&search=&sort_by=name&sort_order=asc&lite=1")
        #expect(http.receivedRequests[2].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/1")
        #expect(http.receivedRequests[2].httpMethod == "DELETE")
        #expect(http.receivedRequests[2].value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
    }

    @Test
    func reportsDeleteFailuresWithoutStoppingCleanup() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "data": {
            "total": 2,
            "items": [
              {
                "id": 1,
                "status": "error",
                "error_message": "Token revoked (401): first"
              },
              {
                "id": 2,
                "status": "error",
                "error_message": "Token revoked (401): second"
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let deleteData = #"{"code":0,"message":"success"}"#.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 500, data: Data())),
                .success(HTTPResponse(statusCode: 200, data: deleteData))
            ]
        )
        let service = RevokedAccountCleanupService(httpClient: http)

        let result = try await service.deleteRevoked401Accounts(
            configuration: try ServiceURLNormalizer.normalize("https://example.com"),
            credential: LoginCredential(email: "admin@example.com", password: "secret")
        )

        #expect(result == RevokedAccountCleanupResult(matchedCount: 2, deletedCount: 1, failedCount: 1))
    }
}
