import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("KeyAvailabilityCheckServiceTests")
struct KeyAvailabilityCheckServiceTests {
    @Test
    func checksKeyAvailabilityThroughAccountTestEndpoint() async throws {
        let loginData = #"{"code":0,"data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let testData = """
        data: {"type":"test_start","model":"gpt-4.1"}
        data: {"type":"content","text":"PONG"}
        data: {"type":"test_complete","success":true}
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: testData))
            ]
        )
        let checkedAt = Date(timeIntervalSince1970: 100)
        let service = KeyAvailabilityCheckService(httpClient: http, now: { checkedAt })

        let result = try await service.runCheck(
            configuration: try ServiceURLNormalizer.normalize("https://example.com/sub2api"),
            credential: LoginCredential(email: "admin@example.com", password: "secret"),
            accountID: 7,
            model: "gpt-4.1"
        )

        #expect(result.accountID == 7)
        #expect(result.checkedAt == checkedAt)
        #expect(result.isAvailable == true)
        #expect(result.latency != nil)
        #expect(http.receivedRequests.count == 2)
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/7/test")
        #expect(http.receivedRequests[1].httpMethod == "POST")

        let body = try #require(JSONSerialization.jsonObject(with: http.receivedRequests[1].httpBody ?? Data()) as? [String: String])
        #expect(body["model_id"] == "gpt-4.1")
        #expect(body["mode"] == "default")
    }
}
