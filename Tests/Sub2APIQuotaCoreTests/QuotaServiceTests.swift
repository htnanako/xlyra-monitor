import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("QuotaServiceTests")
struct QuotaServiceTests {
    @Test
    func fetchQuotaLogsInAndReadsAccountPoolUsage() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123","token_type":"Bearer","user":{"balance":88.5,"status":"active","updated_at":"2026-05-10T21:50:51+08:00"}}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 3,
            "items": [
              {
                "id": 1,
                "name": "a@example.com",
                "platform": "openai",
                "priority": 3,
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 2,
                "extra": {
                  "codex_5h_used_percent": 0,
                  "codex_7d_used_percent": 100,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              },
              {
                "id": 2,
                "name": "b@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 1,
                "extra": {
                  "codex_5h_used_percent": 8,
                  "codex_7d_used_percent": 15,
                  "codex_usage_updated_at": "2026-05-10T21:00:00+08:00"
                }
              },
              {
                "id": 3,
                "name": "c@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": false,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 100,
                  "codex_7d_used_percent": 32,
                  "codex_usage_updated_at": "2026-05-10T21:30:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })
        let configuration = try ServiceURLNormalizer.normalize("https://example.com/sub2api/")

        let quota = try await service.fetchQuota(configuration: configuration, apiKey: "admin@example.com\nsecret")

        #expect(http.receivedRequests.count == 5)
        #expect(http.receivedRequests[0].url?.absoluteString == "https://example.com/sub2api/api/v1/auth/login")
        #expect(http.receivedRequests[0].httpMethod == "POST")
        #expect(http.receivedRequests[0].value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(http.receivedRequests[0].value(forHTTPHeaderField: "Accept") == "application/json")
        let loginBody = try #require(JSONSerialization.jsonObject(with: http.receivedRequests[0].httpBody ?? Data()) as? [String: String])
        #expect(loginBody["email"] == "admin@example.com")
        #expect(loginBody["password"] == "secret")
        #expect(http.receivedRequests[1].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts?page=1&page_size=100&platform=openai&type=&status=&privacy_mode=&group=&search=&sort_by=name&sort_order=asc&lite=1")
        #expect(http.receivedRequests[1].httpMethod == "GET")
        #expect(http.receivedRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
        #expect(http.receivedRequests[2].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/1/usage")
        #expect(http.receivedRequests[3].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/2/usage")
        #expect(http.receivedRequests[4].url?.absoluteString == "https://example.com/sub2api/api/v1/admin/accounts/3/usage")
        #expect(http.receivedTimeouts == [10, 10, 10, 10, 10])
        #expect(quota.available == true)
        #expect(quota.remaining == Decimal(string: "1.92"))
        #expect(quota.displayUnit == "账号/5h")
        #expect(quota.poolSummary?.accountCount == 3)
        #expect(quota.poolSummary?.schedulableCount == 2)
        #expect(quota.poolSummary?.currentConcurrency == 3)
        #expect(quota.poolSummary?.concurrencyLimit == 30)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(string: "1.92"))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(1))
        #expect(quota.poolSummary?.used5hPercent == Decimal(4))
        #expect(quota.poolSummary?.used7dPercent == Decimal(string: "57.5"))
        #expect(quota.poolSummary?.accounts.first?.priority == 3)
        #expect(quota.backendUpdatedAt == ISO8601DateFormatter().date(from: "2026-05-10T22:00:00+08:00"))
        #expect(quota.clientRefreshedAt == Date(timeIntervalSince1970: 100))
    }

    @Test
    func rateLimitedAccountsAreExcludedFromRemainingQuota() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 3,
            "items": [
              {
                "id": 1,
                "name": "available@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 20,
                  "codex_7d_used_percent": 30,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              },
              {
                "id": 2,
                "name": "limited@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": "2026-05-10T23:00:00+08:00",
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 0,
                  "codex_7d_used_percent": 0,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              },
              {
                "id": 3,
                "name": "expired-limit@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": "2026-05-10T20:00:00+08:00",
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 40,
                  "codex_7d_used_percent": 50,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData))
            ]
        )
        let service = QuotaService(
            httpClient: http,
            now: { ISO8601DateFormatter().date(from: "2026-05-10T22:30:00+08:00")! }
        )

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.poolSummary?.accountCount == 3)
        #expect(quota.poolSummary?.schedulableCount == 2)
        #expect(quota.poolSummary?.rateLimitedCount == 1)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(string: "1.40"))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(3))
        #expect(quota.poolSummary?.used5hPercent == Decimal(30))
        #expect(quota.poolSummary?.used7dPercent == Decimal(string: "26.6666666666666666666666666666666666666"))
    }

    @Test
    func rateLimitedAccountsAreOnlyExcludedFromFiveHourRemainingQuota() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 2,
            "items": [
              {
                "id": 1,
                "name": "available@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 50,
                  "codex_7d_used_percent": 25,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              },
              {
                "id": 2,
                "name": "limited@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": "2026-05-10T23:00:00+08:00",
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 100,
                  "codex_7d_used_percent": 25,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData))
            ]
        )
        let service = QuotaService(
            httpClient: http,
            now: { ISO8601DateFormatter().date(from: "2026-05-10T22:30:00+08:00")! }
        )

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.poolSummary?.schedulableCount == 1)
        #expect(quota.poolSummary?.rateLimitedCount == 1)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(string: "0.50"))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(2))
        #expect(quota.poolSummary?.used5hPercent == Decimal(50))
        #expect(quota.poolSummary?.used7dPercent == Decimal(25))
    }

    @Test
    func legacyQuotaEndpointStillParsesForCompatibility() async throws {
        let data = #"{"available":true,"remaining":1}"#.data(using: .utf8)!
        let http = FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: data)))
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })
        let configuration = try ServiceURLNormalizer.normalize("https://example.com")

        let quota = try await service.fetchQuota(configuration: configuration, apiKey: "legacy-token")

        #expect(quota.displayUnit == "额度")
        #expect(quota.backendUpdatedAt == nil)
    }

    @Test
    func exhaustedAccountPoolIsUnavailable() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = #"{"code":0,"message":"success","data":{"total":1,"items":[{"id":1,"name":"a@example.com","platform":"openai","status":"active","schedulable":true,"concurrency":10,"current_concurrency":0,"extra":{"codex_5h_used_percent":100,"codex_7d_used_percent":100,"codex_usage_updated_at":""}}]}}"#.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })
        let configuration = try ServiceURLNormalizer.normalize("https://example.com")

        let quota = try await service.fetchQuota(configuration: configuration, apiKey: "admin@example.com\nsecret")

        #expect(quota.available == false)
        #expect(quota.displayUnit == "账号/5h")
        #expect(quota.remaining == Decimal(0))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(0))
        #expect(quota.backendUpdatedAt == nil)
    }

    @Test
    func sevenDayRemainingCountsAccountsThatAreNotExhausted() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let items = (1...15).map { index -> String in
            let used7d = index <= 10 ? 80 : 100
            return """
              {
                "id": \(index),
                "name": "account-\(index)@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 10,
                  "codex_7d_used_percent": \(used7d),
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            """
        }.joined(separator: ",")
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 15,
            "items": [
              \(items)
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(10))
        #expect(quota.poolSummary?.used7dPercent == Decimal(string: "86.6666666666666666666666666666666666667"))
    }

    @Test
    func accountUsageEndpointOverridesStaleListWindowUsage() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 1,
            "items": [
              {
                "id": 1,
                "name": "a@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 100,
                  "codex_7d_used_percent": 100,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let usageData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "updated_at": "2026-05-10T22:01:00+08:00",
            "five_hour": { "utilization": 0 },
            "seven_day": { "utilization": 0 }
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 200, data: usageData))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(http.receivedRequests[2].url?.absoluteString == "https://example.com/api/v1/admin/accounts/1/usage")
        #expect(quota.available == true)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(1))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(1))
        #expect(quota.poolSummary?.used5hPercent == Decimal(0))
        #expect(quota.poolSummary?.used7dPercent == Decimal(0))
        #expect(quota.backendUpdatedAt == ISO8601DateFormatter().date(from: "2026-05-10T22:01:00+08:00"))
    }

    @Test
    func missingUsagePercentDefaultsToUnusedWhenUsageEndpointFails() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 1,
            "items": [
              {
                "id": 1,
                "name": "new-account",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": null,
                  "codex_7d_used_percent": null,
                  "codex_usage_updated_at": null
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 500, data: Data()))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.available == true)
        #expect(quota.poolSummary?.accountCount == 1)
        #expect(quota.poolSummary?.schedulableCount == 1)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(1))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(1))
        #expect(quota.poolSummary?.used5hPercent == Decimal(0))
        #expect(quota.poolSummary?.used7dPercent == Decimal(0))
    }

    @Test
    func accountsWithoutCodexWindowMetadataAreExcludedWhenUsageEndpointFails() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 2,
            "items": [
              {
                "id": 1,
                "name": "ciii",
                "platform": "openai",
                "type": "apikey",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 100,
                "current_concurrency": 0,
                "extra": {
                  "openai_passthrough": true
                }
              },
              {
                "id": 2,
                "name": "codex-account",
                "platform": "openai",
                "type": "oauth",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 20,
                  "codex_7d_used_percent": 30,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 500, data: Data())),
                .success(HTTPResponse(statusCode: 500, data: Data()))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.poolSummary?.accountCount == 2)
        #expect(quota.poolSummary?.schedulableCount == 2)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(string: "0.80"))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(1))
        #expect(quota.poolSummary?.used5hPercent == Decimal(20))
        #expect(quota.poolSummary?.used7dPercent == Decimal(30))
        #expect(quota.poolSummary?.accounts.first?.supportsUsageWindows == false)
        #expect(quota.poolSummary?.accounts.last?.supportsUsageWindows == true)
    }

    @Test
    func errorAccountsAreExcludedEvenWhenSchedulableAndUsageRemains() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"access_token":"token-123"}}"#.data(using: .utf8)!
        let accountsData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "total": 2,
            "items": [
              {
                "id": 1,
                "name": "active@example.com",
                "platform": "openai",
                "status": "active",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 50,
                  "codex_7d_used_percent": 50,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              },
              {
                "id": 2,
                "name": "revoked@example.com",
                "platform": "openai",
                "status": "error",
                "error_message": "Token revoked (401): Your authentication token has been invalidated.",
                "schedulable": true,
                "rate_limit_reset_at": null,
                "concurrency": 10,
                "current_concurrency": 0,
                "extra": {
                  "codex_5h_used_percent": 0,
                  "codex_7d_used_percent": 0,
                  "codex_usage_updated_at": "2026-05-10T22:00:00+08:00"
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let activeUsageData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "updated_at": "2026-05-10T22:01:00+08:00",
            "five_hour": { "utilization": 50 },
            "seven_day": { "utilization": 50 }
          }
        }
        """.data(using: .utf8)!
        let revokedUsageData = """
        {
          "code": 0,
          "message": "success",
          "data": {
            "updated_at": "2026-05-10T22:02:00+08:00",
            "five_hour": { "utilization": 0 },
            "seven_day": { "utilization": 0 }
          }
        }
        """.data(using: .utf8)!
        let http = FakeHTTPClient(
            results: [
                .success(HTTPResponse(statusCode: 200, data: loginData)),
                .success(HTTPResponse(statusCode: 200, data: accountsData)),
                .success(HTTPResponse(statusCode: 200, data: activeUsageData)),
                .success(HTTPResponse(statusCode: 200, data: revokedUsageData))
            ]
        )
        let service = QuotaService(httpClient: http, now: { Date(timeIntervalSince1970: 100) })

        let quota = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")

        #expect(quota.poolSummary?.accountCount == 2)
        #expect(quota.poolSummary?.schedulableCount == 1)
        #expect(quota.poolSummary?.remaining5hAccounts == Decimal(string: "0.50"))
        #expect(quota.poolSummary?.remaining7dAccounts == Decimal(1))
        #expect(quota.poolSummary?.used5hPercent == Decimal(50))
        #expect(quota.poolSummary?.used7dPercent == Decimal(50))
    }

    @Test
    func missingLoginTokenFailsAuthentication() async throws {
        let loginData = #"{"code":0,"message":"success","data":{"user":{"balance":1}}}"#.data(using: .utf8)!
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: loginData))))

        await expectThrownQuotaError(.authenticationFailed) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "admin@example.com\nsecret")
        }
    }

    @Test
    func authenticationStatusMapsToAuthenticationFailed() async throws {
        try await expectQuotaError(statusCode: 401, expectedError: .authenticationFailed)
    }

    @Test
    func forbiddenStatusMapsToAuthenticationFailed() async throws {
        try await expectQuotaError(statusCode: 403, expectedError: .authenticationFailed)
    }

    @Test
    func serverErrorMapsToServiceUnavailable() async throws {
        try await expectQuotaError(statusCode: 502, expectedError: .serviceUnavailable)
    }

    @Test
    func otherNonSuccessStatusMapsToInvalidResponse() async throws {
        try await expectQuotaError(statusCode: 404, expectedError: .invalidResponse)
    }

    @Test
    func invalidUpdatedAtFailsParsing() async throws {
        let data = #"{"available":true,"remaining":1,"updated_at":"not-a-date"}"#.data(using: .utf8)!
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: data))))

        await expectThrownQuotaError(.invalidResponse) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    @Test
    func timedOutErrorMapsToTimeout() async throws {
        let service = QuotaService(httpClient: FakeHTTPClient(result: .failure(URLError(.timedOut))))

        await expectThrownQuotaError(.timeout) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    @Test
    func networkErrorMapsToNetwork() async throws {
        let service = QuotaService(httpClient: FakeHTTPClient(result: .failure(URLError(.notConnectedToInternet))))

        await expectThrownQuotaError(.network) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    @Test(arguments: [
        #"{"remaining":1}"#,
        #"{"available":true}"#,
        #"{"available":"yes","remaining":1}"#,
        #"{"available":true,"remaining":"many"}"#
    ])
    func missingRequiredFieldsFailParsing(payload: String) async throws {
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: payload.data(using: .utf8)!))))

        await expectThrownQuotaError(.invalidResponse) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    @Test
    func nonJSONResponseFailsParsing() async throws {
        let html = "<html>upstream error</html>".data(using: .utf8)!
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: html))))

        await expectThrownQuotaError(.invalidResponse) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    @Test
    func nonFiniteRemainingFailsParsing() async throws {
        let data = #"{"available":true,"remaining":1e999}"#.data(using: .utf8)!
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: 200, data: data))))

        await expectThrownQuotaError(.invalidResponse) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
        }
    }

    private static func configuration() throws -> ServiceConfiguration {
        try ServiceURLNormalizer.normalize("https://example.com")
    }

    private func expectQuotaError(statusCode: Int, expectedError: QuotaErrorKind) async throws {
        let service = QuotaService(httpClient: FakeHTTPClient(result: .success(HTTPResponse(statusCode: statusCode, data: Data()))))

        await expectThrownQuotaError(expectedError) {
            _ = try await service.fetchQuota(configuration: Self.configuration(), apiKey: "secret")
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
