import Foundation

public struct HTTPResponse {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol HTTPClient {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponse {
        var request = request
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaErrorKind.invalidResponse
        }

        return HTTPResponse(statusCode: httpResponse.statusCode, data: data)
    }
}
