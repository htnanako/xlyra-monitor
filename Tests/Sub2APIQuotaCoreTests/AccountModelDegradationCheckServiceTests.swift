import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("AccountModelDegradationCheckServiceTests")
struct AccountModelDegradationCheckServiceTests {
    @Test
    func openAIAccountCheckUsesSub2APIAccountTestEndpoints() async throws {
        let http = FakeHTTPClient(results: [
            .success(jsonResponse(#"{"data":{"access_token":"admin-token"}}"#)),
            .success(jsonResponse(#"{"data":[{"id":"gpt-4.1"},{"id":"gpt-4o"}]}"#)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gpt-4.1"}
            data: {"type":"content","text":"pong"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gpt-4.1"}
            data: {"type":"content","text":"pong"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gpt-4.1"}
            data: {"type":"content","text":"pong"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gpt-4.1"}
            data: {"type":"content","text":"COMPACT_OK"}
            data: {"type":"test_complete","success":true}
            """))
        ])
        let service = AccountModelDegradationCheckService(
            httpClient: http,
            now: { Date(timeIntervalSince1970: 1_780_000_000) }
        )

        let result = try await service.runCheck(
            configuration: try ServiceURLNormalizer.normalize("https://example.com/sub2api"),
            credential: LoginCredential(email: "admin@example.com", password: "password"),
            target: AccountModelCheckTarget(id: 7, name: "OpenAI", platform: "openai"),
            model: "gpt-4.1"
        )

        #expect(result.score == 100)
        #expect(result.scoreKind == .verifiableHealth)
        #expect(result.status == .normal)
        #expect(result.responseModel == "gpt-4.1")
        #expect(http.receivedRequests.map(\.httpMethod) == ["POST", "GET", "POST", "POST", "POST", "POST"])
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/7/models")
        #expect(http.receivedRequests[2].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/7/test")
        #expect(http.receivedRequests[5].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/7/test")
        #expect(String(data: http.receivedRequests[5].httpBody ?? Data(), encoding: .utf8)?.contains(#""mode":"compact""#) == true)
    }

    @Test
    func nonOpenAIAccountSkipsCompactProbeNetworkRequest() async throws {
        let http = FakeHTTPClient(results: [
            .success(jsonResponse(#"{"data":{"access_token":"admin-token"}}"#)),
            .success(jsonResponse(#"{"data":[{"id":"gemini-2.5-pro"}]}"#)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gemini-2.5-pro"}
            data: {"type":"content","text":"ok"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gemini-2.5-pro"}
            data: {"type":"content","text":"ok"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gemini-2.5-pro"}
            data: {"type":"content","text":"ok"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gemini-2.5-pro"}
            data: {"type":"content","text":"OK_42"}
            data: {"type":"test_complete","success":true}
            """)),
            .success(sseResponse("""
            data: {"type":"test_start","model":"gemini-2.5-pro"}
            data: {"type":"content","text":"444"}
            data: {"type":"test_complete","success":true}
            """))
        ])
        let service = AccountModelDegradationCheckService(httpClient: http)

        let result = try await service.runCheck(
            configuration: try ServiceURLNormalizer.normalize("https://example.com"),
            credential: LoginCredential(email: "admin@example.com", password: "password"),
            target: AccountModelCheckTarget(id: 3, name: "Gemini", platform: "gemini"),
            model: "gemini-2.5-pro"
        )

        #expect(result.score == 100)
        #expect(http.receivedRequests.count == 7)
        #expect(result.probes.last?.detail == "非 OpenAI 账号无需检测")
    }

    private func jsonResponse(_ text: String) -> HTTPResponse {
        HTTPResponse(statusCode: 200, data: text.data(using: .utf8)!)
    }

    private func sseResponse(_ text: String) -> HTTPResponse {
        HTTPResponse(statusCode: 200, data: text.data(using: .utf8)!)
    }
}
