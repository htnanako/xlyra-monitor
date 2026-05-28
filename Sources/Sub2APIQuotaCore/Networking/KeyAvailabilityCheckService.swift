import Foundation

public protocol KeyAvailabilityChecking {
    func runCheck(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        accountID: Int,
        model: String
    ) async throws -> KeyAvailabilityProbeResult
}

public struct KeyAvailabilityCheckService: KeyAvailabilityChecking {
    private let httpClient: HTTPClient
    private let adminClient: Sub2APIAdminClient
    private let now: () -> Date

    public init(
        httpClient: HTTPClient,
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.adminClient = Sub2APIAdminClient(httpClient: httpClient)
        self.now = now
    }

    public func runCheck(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        accountID: Int,
        model: String
    ) async throws -> KeyAvailabilityProbeResult {
        let checkedAt = now()
        let token = try await adminClient.login(configuration: configuration, credential: credential)
        let startedAt = Date()

        var request = URLRequest(url: adminClient.apiURL(configuration: configuration, path: "api/v1/admin/accounts/\(accountID)/test"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "model_id": model,
                "prompt": "请只回复 PONG。",
                "mode": "default"
            ]
        )

        let response = try await send(request, timeout: 30)
        let latency = Date().timeIntervalSince(startedAt)
        guard response.statusCode == 200 else {
            return KeyAvailabilityProbeResult(
                accountID: accountID,
                checkedAt: checkedAt,
                isAvailable: false,
                latency: latency
            )
        }

        let summary = parseTestEvents(from: response.data)
        return KeyAvailabilityProbeResult(
            accountID: accountID,
            checkedAt: checkedAt,
            isAvailable: summary.success && summary.hasContent,
            latency: latency
        )
    }

    private func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponse {
        do {
            return try await httpClient.send(request, timeout: timeout)
        } catch let error as QuotaErrorKind {
            throw error
        } catch let error as URLError {
            throw adminClient.map(urlError: error)
        } catch {
            throw QuotaErrorKind.network
        }
    }

    private func parseTestEvents(from data: Data) -> TestEventSummary {
        guard let text = String(data: data, encoding: .utf8) else {
            return TestEventSummary(success: false, hasContent: false)
        }

        var success = false
        var hasContent = false
        var sawCompleteEvent = false

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("data:") else {
                continue
            }

            let jsonText = trimmedLine.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            guard jsonText.isEmpty == false,
                  let jsonData = jsonText.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            switch parseOptionalString(event["type"]) {
            case "content":
                if parseOptionalString(event["text"]) != nil {
                    hasContent = true
                }
            case "test_complete":
                sawCompleteEvent = true
                success = parseOptionalBool(event["success"]) ?? true
            case "error":
                success = false
            default:
                continue
            }
        }

        return TestEventSummary(success: sawCompleteEvent ? success : hasContent, hasContent: hasContent)
    }

    private func parseOptionalString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedString.isEmpty ? nil : trimmedString
    }

    private func parseOptionalBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}

private struct TestEventSummary {
    let success: Bool
    let hasContent: Bool
}
