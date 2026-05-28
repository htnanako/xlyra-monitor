import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("ModelDegradationCheckServiceTests")
struct ModelDegradationCheckServiceTests {
    @Test
    func successfulCheckRunsOpenAICompatibleProbes() async throws {
        let http = FakeHTTPClient(results: [
            .success(HTTPResponse(statusCode: 200, data: #"{"id":"gpt-test"}"#.data(using: .utf8)!)),
            .success(HTTPResponse(statusCode: 200, data: chatResponse(model: "gpt-test"))),
            .success(HTTPResponse(statusCode: 200, data: #"data: {"choices":[{"delta":{"content":"pong"}}]}\n\ndata: [DONE]\n\n"#.data(using: .utf8)!)),
            .success(HTTPResponse(statusCode: 200, data: toolResponse())),
            .success(HTTPResponse(statusCode: 200, data: textResponse(content: "OK_42"))),
            .success(HTTPResponse(statusCode: 200, data: textResponse(content: "444")))
        ])
        let service = ModelDegradationCheckService(
            httpClient: http,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = try await service.runCheck(configuration: configuration())

        #expect(result.score == 100)
        #expect(result.scoreKind == .qualityProbe)
        #expect(result.status == .normal)
        #expect(result.responseModel == "gpt-test")
        #expect(result.probes.count == 6)
        #expect(http.receivedRequests.map(\.url?.path) == [
            "/v1/models/gpt-test",
            "/v1/chat/completions",
            "/v1/chat/completions",
            "/v1/chat/completions",
            "/v1/chat/completions",
            "/v1/chat/completions"
        ])
        #expect(http.receivedRequests.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer test-key"
        })
    }

    @Test
    func mismatchedResponseModelLowersScore() async throws {
        let http = FakeHTTPClient(results: [
            .success(HTTPResponse(statusCode: 200, data: #"{"id":"gpt-test"}"#.data(using: .utf8)!)),
            .success(HTTPResponse(statusCode: 200, data: chatResponse(model: "gpt-cheap"))),
            .success(HTTPResponse(statusCode: 200, data: #"data: {"choices":[{"delta":{"content":"pong"}}]}\n\ndata: [DONE]\n\n"#.data(using: .utf8)!)),
            .success(HTTPResponse(statusCode: 200, data: toolResponse())),
            .success(HTTPResponse(statusCode: 200, data: textResponse(content: "OK_42"))),
            .success(HTTPResponse(statusCode: 200, data: textResponse(content: "444")))
        ])
        let service = ModelDegradationCheckService(httpClient: http)

        let result = try await service.runCheck(configuration: configuration())

        #expect(result.score == 90)
        #expect(result.status == .modelMismatch)
        #expect(result.responseModel == "gpt-cheap")
    }

    private func configuration() -> ModelCheckConfiguration {
        ModelCheckConfiguration(
            baseURL: URL(string: "https://api.example.com/v1")!,
            apiKey: "test-key",
            model: "gpt-test"
        )
    }

    private func chatResponse(model: String) -> Data {
        """
        {
          "model": "\(model)",
          "usage": {"total_tokens": 22},
          "choices": [
            {"message": {"content": "{\\"answer\\":42,\\"label\\":\\"ok\\"}"}}
          ]
        }
        """.data(using: .utf8)!
    }

    private func toolResponse() -> Data {
        """
        {
          "model": "gpt-test",
          "choices": [
            {
              "message": {
                "tool_calls": [
                  {
                    "function": {
                      "name": "mark_result",
                      "arguments": "{\\"answer\\":42,\\"label\\":\\"ok\\"}"
                    }
                  }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!
    }

    private func textResponse(content: String) -> Data {
        """
        {
          "model": "gpt-test",
          "usage": {"total_tokens": 12},
          "choices": [
            {"message": {"content": "\(content)"}}
          ]
        }
        """.data(using: .utf8)!
    }
}
