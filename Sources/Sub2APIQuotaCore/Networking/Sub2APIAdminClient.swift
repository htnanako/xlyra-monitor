import Foundation

public struct LoginCredential: Equatable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }

        let email = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let password = String(parts[1])
        guard email.isEmpty == false, password.isEmpty == false else {
            return nil
        }

        self.email = email
        self.password = password
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct Sub2APIAdminClient {
    let httpClient: HTTPClient
    let jsonEncoder: JSONEncoder

    init(httpClient: HTTPClient, jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.httpClient = httpClient
        self.jsonEncoder = jsonEncoder
    }

    func login(configuration: ServiceConfiguration, credential: LoginCredential) async throws -> String {
        var request = URLRequest(url: apiURL(configuration: configuration, path: "api/v1/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(LoginRequest(email: credential.email, password: credential.password))

        let response = try await send(request)
        try validateStatusCode(response.statusCode)

        let object = try parseJSONObject(from: response.data)
        guard let data = object["data"] as? [String: Any],
              let token = parseOptionalString(data["access_token"]) else {
            throw QuotaErrorKind.authenticationFailed
        }

        return token
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            return try await httpClient.send(request, timeout: 10)
        } catch let error as QuotaErrorKind {
            throw error
        } catch let error as URLError {
            throw map(urlError: error)
        } catch {
            throw QuotaErrorKind.network
        }
    }

    func apiURL(configuration: ServiceConfiguration, path: String) -> URL {
        var components = URLComponents(url: configuration.serviceRoot, resolvingAgainstBaseURL: false)!
        let basePath = components.path.isEmpty ? "/" : components.path
        components.path = (basePath as NSString).appendingPathComponent(path)
        return components.url!
    }

    func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200:
            return
        case 401, 403:
            throw QuotaErrorKind.authenticationFailed
        case 500...599:
            throw QuotaErrorKind.serviceUnavailable
        default:
            throw QuotaErrorKind.invalidResponse
        }
    }

    func parseJSONObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaErrorKind.invalidResponse
        }

        return object
    }

    func parseOptionalString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedString.isEmpty ? nil : trimmedString
    }

    func map(urlError: URLError) -> QuotaErrorKind {
        if urlError.code == .timedOut {
            return .timeout
        }

        return .network
    }
}

