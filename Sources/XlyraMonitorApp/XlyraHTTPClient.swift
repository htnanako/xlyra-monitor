import Foundation

struct XlyraHTTPResponse {
    let statusCode: Int
    let data: Data
}

protocol XlyraHTTPClient {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> XlyraHTTPResponse
}

struct XlyraURLSessionHTTPClient: XlyraHTTPClient {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> XlyraHTTPResponse {
        var request = request
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XlyraMonitorError.invalidPayload
        }

        return XlyraHTTPResponse(statusCode: httpResponse.statusCode, data: data)
    }
}
