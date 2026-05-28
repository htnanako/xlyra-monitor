import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("AccountImportServiceTests")
struct AccountImportServiceTests {
    @Test
    func logsInAndPostsImportDataToAdminEndpoint() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let importData = #"{"account_created":1,"account_failed":0,"proxy_created":0,"proxy_reused":0,"proxy_failed":0,"errors":[]}"#.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: importData))
            ]
        )
        let service = AccountImportService(httpClient: http)
        let payload = try #require(JSONSerialization.jsonObject(with: #"{"accounts":[{"name":"hidden"}],"proxies":[]}"#.data(using: .utf8)!) as? [String: Any])

        let result = try await service.importAccounts(
            configuration: try ServiceURLNormalizer.normalize("https://example.com/sub2api"),
            credential: LoginCredential(email: "admin@example.com", password: "secret"),
            payload: payload
        )

        #expect(result.accountCreated == 1)
        #expect(result.isFullySuccessful)
        #expect(http.receivedRequests.count == 2)
        #expect(http.receivedRequests[0].url?.absoluteString == "https://example.com/sub2api/api/v1/auth/login")
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/data")
        #expect(http.receivedRequests[1].httpMethod == "POST")
        #expect(http.receivedRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
        let body = try #require(JSONSerialization.jsonObject(with: http.receivedRequests[1].httpBody ?? Data()) as? [String: Any])
        #expect(body["skip_default_group_bind"] as? Bool == true)
        let data = try #require(body["data"] as? [String: Any])
        #expect((data["accounts"] as? [Any])?.count == 1)
    }

    @Test
    func parsesPartialFailureResult() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let importData = #"{"account_created":1,"account_failed":1,"proxy_created":0,"proxy_reused":0,"proxy_failed":0,"errors":["duplicate"]}"#.data(using: .utf8)!
        let service = AccountImportService(
            httpClient: FakeHTTPClient(
                results: [
                    .success(HTTPResponse(statusCode: 200, data: loginData)),
                    .success(HTTPResponse(statusCode: 200, data: importData))
                ]
            )
        )

        let result = try await service.importAccounts(
            configuration: try ServiceURLNormalizer.normalize("https://example.com"),
            credential: LoginCredential(email: "admin@example.com", password: "secret"),
            payload: ["accounts": []]
        )

        #expect(result.accountCreated == 1)
        #expect(result.accountFailed == 1)
        #expect(result.errors == ["duplicate"])
        #expect(result.isFullySuccessful == false)
    }

    @Test
    func authenticationFailureIsMapped() async throws {
        let service = AccountImportService(
            httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 401, data: Data())))
        )

        await expectThrownQuotaError(QuotaErrorKind.authenticationFailed) {
            _ = try await service.importAccounts(
                configuration: try ServiceURLNormalizer.normalize("https://example.com"),
                credential: LoginCredential(email: "admin@example.com", password: "secret"),
                payload: ["accounts": []]
            )
        }
    }

    private func expectThrownQuotaError(
        _ expectedError: QuotaErrorKind,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expectedError)")
        } catch let error as QuotaErrorKind {
            #expect(error == expectedError)
        } catch {
            Issue.record("Expected \(expectedError), got \(error)")
        }
    }
}
