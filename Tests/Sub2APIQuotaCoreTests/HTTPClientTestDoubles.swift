import Foundation
@testable import Sub2APIQuotaCore

final class FakeHTTPClient: HTTPClient {
    var receivedRequest: URLRequest?
    var receivedTimeout: TimeInterval?
    var receivedRequests: [URLRequest] = []
    var receivedTimeouts: [TimeInterval] = []
    var results: [Result<HTTPResponse, Error>]

    init(result: Result<HTTPResponse, Error>) {
        self.results = [result]
    }

    init(results: [Result<HTTPResponse, Error>]) {
        self.results = results
    }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponse {
        receivedRequest = request
        receivedTimeout = timeout
        receivedRequests.append(request)
        receivedTimeouts.append(timeout)

        guard results.isEmpty == false else {
            throw QuotaErrorKind.invalidResponse
        }

        return try results.removeFirst().get()
    }
}
