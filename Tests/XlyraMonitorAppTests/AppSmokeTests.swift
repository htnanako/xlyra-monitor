import AppKit
import Foundation
import SwiftUI
import Testing
@testable import XlyraMonitorApp

@Suite("AppSmokeTests")
struct AppSmokeTests {
    @Test
    func testAppTargetExposesMenuBarMetadata() {
        #expect(XlyraMonitorAppMetadata.menuBarTitle == "xLyra")
        #expect(XlyraMonitorAppMetadata.menuBarLabel == "xLyra 监控")
        #expect(XlyraMonitorAppMetadata.fallbackVersion == "0.1.8")
    }

    @Test
    func testUpdateVersionComparisonHandlesTags() {
        #expect(XlyraVersionComparator.isVersion("v0.1.8", newerThan: "0.1.0"))
        #expect(XlyraVersionComparator.isVersion("0.10.0", newerThan: "0.9.9"))
        #expect(XlyraVersionComparator.isVersion("0.1.0", newerThan: "0.1.0") == false)
        #expect(XlyraVersionComparator.isVersion("0.0.9", newerThan: "0.1.0") == false)
    }

    @Test
    func testUpdateInstallerAssetPrefersXlyraDMG() {
        let assets = [
            XlyraGitHubReleaseAsset(
                name: "notes.txt",
                browserDownloadURL: URL(string: "https://example.com/notes.txt")!
            ),
            XlyraGitHubReleaseAsset(
                name: "other-app.dmg",
                browserDownloadURL: URL(string: "https://example.com/other.dmg")!
            ),
            XlyraGitHubReleaseAsset(
                name: "xLyra-Monitor-0.2.0.dmg",
                browserDownloadURL: URL(string: "https://example.com/xlyra.dmg")!
            )
        ]

        #expect(XlyraAppUpdateService.installerAsset(from: assets)?.name == "xLyra-Monitor-0.2.0.dmg")
    }

    @Test
    func testGitHubReleaseDecodesUpdatePayload() throws {
        let data = """
        {
          "tag_name": "v0.2.0",
          "name": "xLyra Monitor 0.2.0",
          "html_url": "https://github.com/z4jst/xlyra-monitor/releases/tag/v0.2.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "xLyra-Monitor-0.2.0.dmg",
              "browser_download_url": "https://github.com/z4jst/xlyra-monitor/releases/download/v0.2.0/xLyra-Monitor-0.2.0.dmg"
            }
          ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(XlyraGitHubRelease.self, from: data)

        #expect(release.tagName == "v0.2.0")
        #expect(release.assets.first?.name == "xLyra-Monitor-0.2.0.dmg")
    }

    @MainActor
    @Test
    func testAutomaticUpdateChecksRunEveryFiveMinutes() {
        #expect(XlyraAppUpdateCoordinator.automaticCheckInterval == 300)
    }

    @Test
    func testXlyraBusinessSnapshotDecodes() throws {
        let data = """
        {
          "generated_at": "2026-05-27T06:53:41.872526+00:00",
          "sites": {
            "total": 2,
            "healthy": 1,
            "rows": [
              {
                "name": "Codex_cord_jxxc",
                "slug": "codex-cord-jxxc",
                "type": "codex",
                "status": "active",
                "enabled": true,
                "priority": 4.0,
                "validation_ok": true,
                "sync_status": "synced",
                "api_key_count": 1,
                "model_count": 8,
                "last_synced_at": "2026-05-27T06:00:02.650771+00:00",
                "tokens24h": 24525954,
                "cost24h": 77.370499,
                "recent_health": {
                  "success": true,
                  "status_code": 200,
                  "latency_ms": 565,
                  "error_type": null,
                  "checked_at": "2026-05-27T06:41:24.506623+00:00"
                }
              },
              {
                "name": "bad-site",
                "slug": "bad-site",
                "type": "openai",
                "status": "active",
                "enabled": true,
                "priority": 5.0,
                "validation_ok": false,
                "sync_status": "error",
                "api_key_count": 0,
                "model_count": 0,
                "last_synced_at": null,
                "tokens24h": 0,
                "cost24h": 0,
                "recent_health": {}
              }
            ]
          },
          "oauth": {
            "total": 1,
            "healthy": 1,
            "limited": 0,
            "rows": [
              {
                "id": "oauth-1",
                "provider": "codex",
                "site_name": "Codex_cord_jxxc",
                "site_slug": "codex-cord-jxxc",
                "status": "connected",
                "account_id": "user-123",
                "email": "codex@example.com",
                "plan_type": "plus",
                "available": true,
                "limit_reached": false,
                "five_hour_used_percent": 4,
                "five_hour_remaining_percent": 96,
                "five_hour_reset_at": 1779875344,
                "weekly_used_percent": 27,
                "weekly_remaining_percent": 73,
                "weekly_reset_at": 1780296607,
                "credits_balance": "0",
                "credits_unlimited": false,
                "last_refresh_at": "2026-05-27T05:06:06.765101+00:00",
                "last_sync_at": "2026-05-27T06:00:03.745145+00:00",
                "expires_at": "2026-06-06T05:06:06.765101+00:00",
                "tokens24h": 24525954,
                "cost24h": 77.370499
              }
            ]
          },
          "api_keys": {
            "total": 1,
            "active": 1,
            "exhausted": 0,
            "rows": [
              {
                "name": "default",
                "masked_key": "sk-9...3786",
                "status": "active",
                "quota_limit": null,
                "quota_used": 457.64655505,
                "quota_unlimited": true,
                "last_used_at": "2026-05-27T06:53:34.711922+00:00",
                "expires_at": null
              }
            ]
          },
          "requests": {
            "total": 3064,
            "last_hour": 204,
            "last_24h": 713,
            "ok_24h": 674,
            "failed_24h": 39,
            "avg_latency_24h": 16189
          },
          "usage": {
            "tokens_24h": 56435720,
            "cost_24h": 111.51302085
          },
          "errors": [
            { "error_type": "upstream_timeout", "count": 9 }
          ],
          "cooldowns": {
            "active": 0
          }
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(XlyraSnapshot.self, from: data)

        #expect(snapshot.sites.total == 2)
        #expect(snapshot.sites.rows.first?.name == "Codex_cord_jxxc")
        #expect(snapshot.oauth.rows.first?.fiveHourRemainingPercent == 96)
        #expect(snapshot.oauth.rows.first?.fiveHourResetAt == 1_779_875_344)
        #expect(snapshot.oauth.rows.first?.weeklyUsedPercent == 27)
        #expect(snapshot.oauth.rows.first?.weeklyResetAt == 1_780_296_607)
        #expect(snapshot.oauth.rows.first?.lastRefreshAt == "2026-05-27T05:06:06.765101+00:00")
        #expect(snapshot.oauth.rows.first?.lastSyncAt == "2026-05-27T06:00:03.745145+00:00")
        #expect(snapshot.oauth.rows.first?.expiresAt == "2026-06-06T05:06:06.765101+00:00")
        #expect(snapshot.apiKeys.rows.first?.quotaUnlimited == true)
        #expect(snapshot.requests.failed24h == 39)
        #expect(snapshot.usage.tokens24h == 56_435_720)
        #expect(snapshot.healthLevel == XlyraHealthLevel.warning)
        #expect(snapshot.riskItems.contains("站点异常 1 个"))
    }

    @Test
    func testXlyraSiteMissingOptionalValidationAndSyncStatusIsUsable() throws {
        let data = """
        {
          "name": "Codex Site",
          "slug": "codex-site",
          "type": "codex",
          "status": "active",
          "enabled": true,
          "priority": 1,
          "api_key_count": 1,
          "model_count": 8,
          "last_synced_at": null,
          "tokens24h": 120000,
          "cost24h": 12.34,
          "recent_health": {
            "success": true,
            "status_code": 200,
            "latency_ms": 345
          }
        }
        """.data(using: .utf8)!

        let site = try JSONDecoder().decode(XlyraSiteRow.self, from: data)

        #expect(site.validationOK == nil)
        #expect(site.syncStatus == nil)
        #expect(site.isHealthy)
        #expect(site.stateText == "可用")
    }

    @MainActor
    @Test
    func testMonitorTitleReflectsConnectionStateInsteadOfBusinessHealth() {
        let state = XlyraMonitorState()
        let snapshot = XlyraSnapshot(
            generatedAt: "2026-05-28T08:00:00.000Z",
            sites: XlyraSiteSummary(total: 1, healthy: 1, rows: []),
            oauth: XlyraOAuthSummary(total: 1, healthy: 1, limited: 0, rows: []),
            apiKeys: XlyraAPIKeySummary(total: 1, active: 1, exhausted: 0, rows: []),
            requests: XlyraRequestSummary(
                total: 100,
                lastHour: 10,
                last24h: 100,
                ok24h: 69,
                failed24h: 31,
                avgLatency24h: nil
            ),
            usage: XlyraUsageSummary(tokens24h: 0, cost24h: 0),
            errors: [],
            cooldowns: XlyraCooldownSummary(active: 0)
        )

        #expect(snapshot.healthLevel == .critical)

        state.applySuccess(snapshot)

        #expect(state.title == "xLyra 已连接")
        #expect(state.statusColorName == "green")
    }

    @Test
    func testXlyraOAuthQuotaNormalizesFractionalPercentValues() throws {
        let data = """
        {
          "id": "oauth-1",
          "provider": "codex",
          "status": "connected",
          "account_id": "user-1",
          "email": "codex@example.com",
          "available": true,
          "limit_reached": false,
          "five_hour_used_percent": 0.04,
          "five_hour_remaining_percent": 0.96,
          "weekly_used_percent": 0.55,
          "weekly_remaining_percent": 0.45,
          "tokens24h": 0,
          "cost24h": 0
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(XlyraOAuthRow.self, from: data)

        #expect(account.fiveHourUsedDisplayPercent == 4)
        #expect(account.fiveHourRemainingDisplayPercent == 96)
        #expect(account.weeklyUsedDisplayPercent == 55)
        #expect(account.weeklyRemainingDisplayPercent == 45)
        #expect(account.quotaText == "5h 剩 96% · 7d 剩 45%")
    }

    @Test
    func testXlyraOAuthQuotaUsesRemainingPercentWhenOneIsAmbiguous() throws {
        let data = """
        {
          "id": "oauth-1",
          "provider": "codex",
          "status": "connected",
          "account_id": "user-1",
          "email": "codex@example.com",
          "available": true,
          "limit_reached": false,
          "five_hour_used_percent": 1,
          "five_hour_remaining_percent": 99,
          "tokens24h": 0,
          "cost24h": 0
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder().decode(XlyraOAuthRow.self, from: data)

        #expect(account.fiveHourUsedDisplayPercent == 1)
        #expect(account.fiveHourRemainingDisplayPercent == 99)
    }

    @Test
    func testXlyraMonitorPreferencesStartWithoutBundledConsoleURL() throws {
        let preferences = XlyraMonitorPreferences(
            configURL: Self.temporaryXlyraConfigURL()
        )

        #expect(preferences.consoleURL == nil)
        #expect(try preferences.adminAccessToken() == nil)
    }

    @Test
    func testXlyraOAuthLiveSummaryUsesRowsInsteadOfStaleOverviewCounts() throws {
        let data = """
        {
          "generated_at": "2026-05-27T06:53:41.872526+00:00",
          "sites": {
            "total": 1,
            "healthy": 1,
            "rows": [
              {
                "name": "Codex Site",
                "slug": "codex-site",
                "type": "codex",
                "status": "active",
                "enabled": true,
                "priority": 1,
                "api_key_count": 1,
                "model_count": 8,
                "tokens24h": 0,
                "cost24h": 0,
                "recent_health": { "success": true }
              }
            ]
          },
          "oauth": {
            "total": 5,
            "healthy": 5,
            "limited": 0,
            "rows": [
              {
                "id": "oauth-1",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-1",
                "email": "one@example.com",
                "plan_type": "plus",
                "available": true,
                "limit_reached": false,
                "five_hour_remaining_percent": 99,
                "weekly_remaining_percent": 80,
                "tokens24h": 0,
                "cost24h": 0
              },
              {
                "id": "oauth-2",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-2",
                "email": "two@example.com",
                "plan_type": "team",
                "available": true,
                "limit_reached": false,
                "five_hour_remaining_percent": 90,
                "weekly_remaining_percent": 70,
                "tokens24h": 0,
                "cost24h": 0
              },
              {
                "id": "oauth-3",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-3",
                "email": "three@example.com",
                "plan_type": "plus",
                "available": true,
                "limit_reached": false,
                "five_hour_remaining_percent": 75,
                "weekly_remaining_percent": 60,
                "tokens24h": 0,
                "cost24h": 0
              },
              {
                "id": "oauth-4",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-4",
                "email": "four@example.com",
                "plan_type": "team",
                "available": true,
                "limit_reached": false,
                "five_hour_remaining_percent": 50,
                "weekly_remaining_percent": 50,
                "tokens24h": 0,
                "cost24h": 0
              },
              {
                "id": "oauth-5",
                "provider": "codex",
                "status": "error",
                "account_id": "user-5",
                "email": "five@example.com",
                "plan_type": "plus",
                "available": true,
                "limit_reached": false,
                "five_hour_remaining_percent": 100,
                "weekly_remaining_percent": 100,
                "tokens24h": 0,
                "cost24h": 0
              }
            ]
          },
          "api_keys": {
            "total": 1,
            "active": 1,
            "exhausted": 0,
            "rows": [
              {
                "name": "default",
                "masked_key": "sk-9...3786",
                "status": "active",
                "quota_limit": null,
                "quota_used": 0,
                "quota_unlimited": true
              }
            ]
          },
          "requests": { "total": 0, "last_hour": 0, "last_24h": 0, "ok_24h": 0, "failed_24h": 0, "avg_latency_24h": null },
          "usage": { "tokens_24h": 0, "cost_24h": 0 },
          "errors": [],
          "cooldowns": { "active": 0 }
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(XlyraSnapshot.self, from: data)

        #expect(snapshot.oauth.total == 5)
        #expect(snapshot.oauth.healthy == 5)
        #expect(snapshot.oauth.liveTotal == 5)
        #expect(snapshot.oauth.liveHealthy == 4)
        #expect(snapshot.oauth.fiveHourCapacity.shortText == "78.5%")
        #expect(abs(snapshot.oauth.fiveHourCapacity.remainingFraction - 0.785) < 0.0001)
        #expect(snapshot.oauth.weeklyCapacity.shortText == "65%")
        #expect(abs(snapshot.oauth.weeklyCapacity.remainingFraction - 0.65) < 0.0001)
        #expect(snapshot.oauth.rows[0].planDisplayText == "PLUS")
        #expect(snapshot.oauth.rows[1].planDisplayText == "TEAM")
        #expect(snapshot.riskItems.contains("OAuth 异常 1 个"))
    }

    @Test
    func testXlyraOAuthMenuBarCapacityAveragesRemainingPercentAcrossHealthyAccounts() throws {
        let data = """
        {
          "generated_at": "2026-05-27T06:53:41.872526+00:00",
          "sites": {
            "total": 1,
            "healthy": 1,
            "rows": [
              {
                "name": "Codex Site",
                "slug": "codex-site",
                "type": "codex",
                "status": "active",
                "enabled": true,
                "priority": 1,
                "api_key_count": 1,
                "model_count": 8,
                "tokens24h": 0,
                "cost24h": 0,
                "recent_health": { "success": true }
              }
            ]
          },
          "oauth": {
            "total": 2,
            "healthy": 2,
            "limited": 0,
            "rows": [
              {
                "id": "oauth-1",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-1",
                "email": "one@example.com",
                "available": true,
                "limit_reached": false,
                "five_hour_used_percent": 20,
                "weekly_used_percent": 85,
                "tokens24h": 0,
                "cost24h": 0
              },
              {
                "id": "oauth-2",
                "provider": "codex",
                "status": "connected",
                "account_id": "user-2",
                "email": "two@example.com",
                "available": true,
                "limit_reached": false,
                "five_hour_used_percent": 60,
                "weekly_used_percent": 95,
                "tokens24h": 0,
                "cost24h": 0
              }
            ]
          },
          "api_keys": {
            "total": 1,
            "active": 1,
            "exhausted": 0,
            "rows": [
              {
                "name": "default",
                "masked_key": "sk-9...3786",
                "status": "active",
                "quota_limit": null,
                "quota_used": 0,
                "quota_unlimited": true
              }
            ]
          },
          "requests": { "total": 0, "last_hour": 0, "last_24h": 0, "ok_24h": 0, "failed_24h": 0, "avg_latency_24h": null },
          "usage": { "tokens_24h": 0, "cost_24h": 0 },
          "errors": [],
          "cooldowns": { "active": 0 }
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(XlyraSnapshot.self, from: data)

        #expect(snapshot.oauth.fiveHourCapacity.shortText == "60%")
        #expect(abs(snapshot.oauth.fiveHourCapacity.remainingFraction - 0.60) < 0.0001)
        #expect(snapshot.oauth.fiveHourCapacity.riskColorName == "green")
        #expect(snapshot.oauth.weeklyCapacity.shortText == "10%")
        #expect(abs(snapshot.oauth.weeklyCapacity.remainingFraction - 0.10) < 0.0001)
        #expect(snapshot.oauth.weeklyCapacity.riskColorName == "orange")
    }

    @Test
    func testXlyraOAuthRemainingRiskColorsFollowConfiguredBands() {
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 39).riskColorName == "yellow")
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 20).riskColorName == "yellow")
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 19).riskColorName == "orange")
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 10).riskColorName == "orange")
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 9).riskColorName == "red")
        #expect(XlyraOAuthCapacity(averageRemainingPercent: 40).riskColorName == "green")
    }

    @Test
    func testXlyraOAuthQuotaProgressColorKeepsLimitedAccountsPercentBased() throws {
        let account = try JSONDecoder().decode(XlyraOAuthRow.self, from: """
        {
          "id": "oauth-limited",
          "provider": "codex",
          "status": "connected",
          "account_id": "user-123",
          "email": "limited@example.com",
          "available": true,
          "limit_reached": true,
          "five_hour_remaining_percent": 18,
          "tokens24h": 0,
          "cost24h": 0
        }
        """.data(using: .utf8)!)

        #expect(account.stateText == "额度触顶")
        #expect(account.quotaProgressColorName(remainingPercent: account.fiveHourRemainingDisplayPercent) == "orange")
    }

    @Test
    func testXlyraOAuthQuotaProgressColorGraysUnavailableAccounts() throws {
        let account = try JSONDecoder().decode(XlyraOAuthRow.self, from: """
        {
          "id": "oauth-error",
          "provider": "codex",
          "status": "error",
          "account_id": "user-456",
          "email": "error@example.com",
          "available": true,
          "limit_reached": false,
          "five_hour_remaining_percent": 8,
          "tokens24h": 0,
          "cost24h": 0
        }
        """.data(using: .utf8)!)

        #expect(account.quotaProgressColorName(remainingPercent: account.fiveHourRemainingDisplayPercent) == "gray")
    }

    @Test
    func testXlyraAntigravityOAuthUsesRemainingModelQuotaForProgressColor() throws {
        let json = """
        {
          "oauth": {
            "items": [
              {
                "id": "oauth-antigravity",
                "provider": "antigravity",
                "status": "connected",
                "account_id": "ag-user",
                "email": "ag@example.com",
                "available": true,
                "limit_reached": false,
                "meta": {
                  "models": [
                    {
                      "id": "gemini-pro-agent",
                      "name": "gemini-pro-agent",
                      "upstream_model_name": "gemini-pro-agent",
                      "display_name": "Gemini 3.1 Pro (High)",
                      "quota": {
                        "name": "gemini-pro-agent",
                        "display_name": "Gemini 3.1 Pro (High)",
                        "used_percent": 12,
                        "remaining_percent": 88,
                        "reset_time": "2026-06-04T08:25:24Z"
                      }
                    },
                    {
                      "id": "claude-opus-4-6-thinking",
                      "name": "claude-opus-4-6-thinking",
                      "upstream_model_name": "claude-opus-4-6-thinking",
                      "display_name": "Claude Opus 4.6 (Thinking)",
                      "quota": {
                        "name": "claude-opus-4-6-thinking",
                        "display_name": "Claude Opus 4.6 (Thinking)",
                        "used_percent": 5,
                        "remaining_percent": 95,
                        "reset_at": 1780561524
                      }
                    }
                  ]
                }
              }
            ]
          },
          "sites": [],
          "api_keys": [],
          "dashboard": {},
          "health_sites": [],
          "cooldowns": [],
          "requests": []
        }
        """.data(using: .utf8)!
        let payload = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        let snapshot = try XlyraAPISnapshotBuilder.snapshot(
            ready: (),
            version: [:],
            siteTypes: [],
            overview: payload["dashboard"]!,
            oauth: payload["oauth"]!,
            sites: payload["sites"]!,
            apiKeys: payload["api_keys"]!,
            healthSites: payload["health_sites"]!,
            cooldowns: payload["cooldowns"]!,
            requests: payload["requests"]!
        )

        let account = try #require(snapshot.oauth.rows.first)
        #expect(account.modelQuotas.map(\.model) == ["gemini-pro-agent", "claude-opus-4-6-thinking"])
        #expect(account.quotaText == "Gemini 剩 88% · Opus 剩 95%")
        #expect(account.quotaDisplays.map(\.title) == ["Gemini", "Opus"])
        #expect(snapshot.oauth.fiveHourCapacity.shortText == "--")
        #expect(snapshot.oauth.fiveHourCapacity.remainingFraction == 0)
        #expect(snapshot.oauth.weeklyCapacity.shortText == "--")
        #expect(snapshot.oauth.weeklyCapacity.remainingFraction == 0)
        #expect(snapshot.oauth.primaryCapacityLabel == "5h")
        #expect(snapshot.oauth.secondaryCapacityLabel == "7d")
    }

    @Test
    func testXlyraAntigravityOAuthParsesTargetModelQuotas() throws {
        let json = """
        {
          "oauth": {
            "items": [
              {
                "id": "oauth-antigravity",
                "provider": "antigravity",
                "status": "connected",
                "account_id": "ag-user",
                "email": "ag@example.com",
                "available": true,
                "limit_reached": false,
                "meta": {
                  "models": [
                    {
                      "id": "gemini-pro-agent",
                      "name": "gemini-pro-agent",
                      "upstream_model_name": "gemini-pro-agent",
                      "display_name": "Gemini 3.1 Pro (High)",
                      "quota": {
                        "name": "gemini-pro-agent",
                        "display_name": "Gemini 3.1 Pro (High)",
                        "used_percent": 82,
                        "remaining_percent": 18,
                        "reset_time": "2026-06-04T08:25:24Z"
                      }
                    },
                    {
                      "id": "claude-opus-4-6-thinking",
                      "name": "claude-opus-4-6-thinking",
                      "upstream_model_name": "claude-opus-4-6-thinking",
                      "display_name": "Claude Opus 4.6 (Thinking)",
                      "quota": {
                        "name": "claude-opus-4-6-thinking",
                        "display_name": "Claude Opus 4.6 (Thinking)",
                        "used_percent": 5,
                        "remaining_percent": 95,
                        "reset_at": 1780561524
                      }
                    }
                  ]
                }
              }
            ]
          },
          "sites": [],
          "api_keys": [],
          "dashboard": {},
          "health_sites": [],
          "cooldowns": [],
          "requests": []
        }
        """.data(using: .utf8)!
        let payload = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        let snapshot = try XlyraAPISnapshotBuilder.snapshot(
            ready: (),
            version: [:],
            siteTypes: [],
            overview: payload["dashboard"]!,
            oauth: payload["oauth"]!,
            sites: payload["sites"]!,
            apiKeys: payload["api_keys"]!,
            healthSites: payload["health_sites"]!,
            cooldowns: payload["cooldowns"]!,
            requests: payload["requests"]!
        )

        let account = try #require(snapshot.oauth.rows.first)
        #expect(account.modelQuotas.map(\.model) == ["gemini-pro-agent", "claude-opus-4-6-thinking"])
        #expect(account.quotaText == "Gemini 剩 18% · Opus 剩 95%")
        #expect(account.quotaDisplays.map(\.title) == ["Gemini", "Opus"])
        #expect(account.quotaDisplays.first?.usedPercent == 82)
        #expect(account.quotaProgressColorName(remainingPercent: account.quotaDisplays.first?.remainingPercent) == "orange")
    }

    @Test
    func testXlyraSitesAndOAuthSortByStatusThenDescendingPriority() throws {
        let json = """
        {
          "ready": true,
          "version": {},
          "site_types": [],
          "dashboard": {},
          "oauth": [
            { "id": "oauth-error-high", "provider": "codex", "status": "error", "account_id": "5", "email": "error-high@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-error-high" },
            { "id": "oauth-error-low", "provider": "codex", "status": "error", "account_id": "4", "email": "error-low@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-error-low" },
            { "id": "oauth-cooldown-low", "provider": "codex", "status": "connected", "account_id": "3", "email": "cooldown-low@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-cooldown-low" },
            { "id": "oauth-cooldown-high", "provider": "codex", "status": "connected", "account_id": "2", "email": "cooldown-high@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-cooldown-high" },
            { "id": "oauth-normal-low", "provider": "codex", "status": "connected", "account_id": "1", "email": "normal-low@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-normal-low" },
            { "id": "oauth-normal-high", "provider": "codex", "status": "connected", "account_id": "0", "email": "normal-high@example.com", "available": true, "limit_reached": false, "tokens24h": 0, "cost24h": 0, "site_slug": "site-normal-high" }
          ],
          "sites": [
            { "id": "site-disabled", "name": "Disabled", "slug": "site-disabled", "site_type": "codex", "status": "active", "enabled": false, "routing_priority": 4, "api_key_count": 1, "model_count": 1 },
            { "id": "site-error-low", "name": "Error Low", "slug": "site-error-low", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 3, "api_key_count": 1, "model_count": 1, "validation_ok": false },
            { "id": "site-error-high", "name": "Error High", "slug": "site-error-high", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 9, "api_key_count": 1, "model_count": 1, "validation_ok": false },
            { "id": "site-cooldown-low", "name": "Cooldown Low", "slug": "site-cooldown-low", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 2, "api_key_count": 1, "model_count": 1 },
            { "id": "site-cooldown-high", "name": "Cooldown High", "slug": "site-cooldown-high", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 8, "api_key_count": 1, "model_count": 1 },
            { "id": "site-normal-low", "name": "Normal Low", "slug": "site-normal-low", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 1, "api_key_count": 1, "model_count": 1 },
            { "id": "site-normal-high", "name": "Normal High", "slug": "site-normal-high", "site_type": "codex", "status": "active", "enabled": true, "routing_priority": 10, "api_key_count": 1, "model_count": 1 }
          ],
          "api_keys": [],
          "health_sites": [],
          "cooldowns": [{ "site_id": "site-cooldown-low" }, { "site_id": "site-cooldown-high" }],
          "requests": []
        }
        """.data(using: .utf8)!
        let payload = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        let snapshot = try XlyraAPISnapshotBuilder.snapshot(
            ready: (),
            version: payload["version"]!,
            siteTypes: payload["site_types"]!,
            overview: payload["dashboard"]!,
            oauth: payload["oauth"]!,
            sites: payload["sites"]!,
            apiKeys: payload["api_keys"]!,
            healthSites: payload["health_sites"]!,
            cooldowns: payload["cooldowns"]!,
            requests: payload["requests"]!
        )

        #expect(snapshot.sites.rows.map(\.slug) == [
            "site-normal-high",
            "site-normal-low",
            "site-cooldown-high",
            "site-cooldown-low",
            "site-error-high",
            "site-error-low",
            "site-disabled"
        ])
        #expect(snapshot.oauth.rows.map(\.id) == [
            "oauth-normal-high",
            "oauth-normal-low",
            "oauth-cooldown-high",
            "oauth-cooldown-low",
            "oauth-error-high",
            "oauth-error-low"
        ])
        #expect(snapshot.oauth.rows.map(\.priority) == [10, 1, 8, 2, 9, 3])
    }

    @MainActor
    @Test
    func testXlyraMenuRendersScrollableDetailArea() throws {
        let snapshot = try JSONDecoder().decode(XlyraSnapshot.self, from: Self.longRenderSnapshotData)
        let state = XlyraMonitorState()
        state.applySuccess(snapshot)

        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let monitorPreferences = XlyraMonitorPreferences(
            configURL: Self.temporaryXlyraConfigURL()
        )
        let monitor = XlyraMonitor(state: state, preferences: monitorPreferences)
        let view = XlyraStatusMenuView(
            state: state,
            preferences: preferences,
            monitorPreferences: monitorPreferences,
            monitor: monitor,
            updateCoordinator: XlyraAppUpdateCoordinator()
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 460, height: 620)
        hostingView.layoutSubtreeIfNeeded()

        #expect(Self.containsScrollView(hostingView))

        if let previewPath = ProcessInfo.processInfo.environment["XLYRA_RENDER_PREVIEW_PATH"],
           previewPath.isEmpty == false {
            try Self.writePNG(hostingView, to: previewPath)
        }
    }

    @Test
    func testXlyraAPISnapshotUsesDocumentedAdminAccessTokenEndpoints() async throws {
        let http = XlyraFakeHTTPClient(responses: [
            "/readyz": Data(),
            "/api/v1/system/version": Self.apiVersionData,
            "/api/v1/site-types": Self.apiSiteTypesData,
            "/api/v1/dashboard/overview": Self.apiOverviewData,
            "/api/v1/oauth/connections": Self.apiOAuthData,
            "/api/v1/sites?oauth=exclude": Self.apiSitesData,
            "/api/v1/api-keys": Self.apiKeysData,
            "/api/v1/health/sites": Self.apiHealthSitesData,
            "/api/v1/routes/cooldowns": Self.apiCooldownsData,
            "/api/v1/requests?page=1&page_size=50": Self.apiRequestsData
        ])
        let preferences = XlyraMonitorPreferences(
            configURL: Self.temporaryXlyraConfigURL()
        )
        preferences.consoleURL = URL(string: "https://xlyra.example.test")!
        try preferences.saveAdminAccessToken("test-admin-access-token")

        let snapshot = try await XlyraAPIMonitorService(httpClient: http).fetchSnapshot(preferences: preferences)

        #expect(snapshot.oauth.total == 1)
        #expect(snapshot.oauth.rows.first?.displayName == "codex@example.com")
        #expect(snapshot.oauth.rows.first?.planType == "team")
        #expect(snapshot.oauth.rows.first?.fiveHourRemainingPercent == 96)
        #expect(snapshot.oauth.rows.first?.weeklyUsedPercent == 55)
        #expect(snapshot.oauth.rows.first?.creditsBalance == "2")
        #expect(snapshot.oauth.rows.first?.lastRefreshAt == "2026-05-27T05:01:06.765101+00:00")
        #expect(snapshot.sites.healthy == 0)
        #expect(snapshot.sites.rows.first?.stateText == "冷却中")
        #expect(snapshot.oauth.rows.first?.stateText == "可用")
        #expect(snapshot.sites.rows.first?.tokens24h == 111)
        #expect(snapshot.sites.rows.first?.cost24h == 2.5)
        #expect(snapshot.sites.rows.first?.validationOK == true)
        #expect(snapshot.sites.rows.first?.syncStatus == "synced")
        #expect(snapshot.sites.rows.first?.recentHealth?.latencyMS == 345)
        #expect(snapshot.apiKeys.active == 1)
        #expect(snapshot.requests.failed24h == 1)
        #expect(snapshot.requests.last24h == 10)
        #expect(snapshot.requests.ok24h == 9)
        #expect(snapshot.usage.tokens24h == 111)
        #expect(snapshot.errors.first?.errorType == "upstream_timeout")
        #expect(snapshot.cooldowns.active == 2)
        #expect(snapshot.usage.cost24h == 2.5)

        let requests = http.receivedRequests()
        #expect(requests.count == 10)
        #expect(Set(requests.map { Self.key(for: $0.url) }) == Set([
            "/readyz",
            "/api/v1/system/version",
            "/api/v1/site-types",
            "/api/v1/dashboard/overview",
            "/api/v1/oauth/connections",
            "/api/v1/sites?oauth=exclude",
            "/api/v1/api-keys",
            "/api/v1/health/sites",
            "/api/v1/routes/cooldowns",
            "/api/v1/requests?page=1&page_size=50"
        ]))
        let publicProbePaths = Set(["/readyz", "/api/v1/system/version", "/api/v1/site-types"])
        #expect(requests.filter { publicProbePaths.contains(Self.key(for: $0.url)) }.allSatisfy {
            $0.value(forHTTPHeaderField: "X-Access-Token") == nil
        })
        #expect(requests.filter { publicProbePaths.contains(Self.key(for: $0.url)) == false }.allSatisfy {
            $0.value(forHTTPHeaderField: "X-Access-Token") == "test-admin-access-token"
        })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "X-API-Key") == nil })
    }

    @Test
    func testXlyraOAuthRefreshUsesDocumentedConnectionRefreshEndpoint() async throws {
        let http = XlyraFakeHTTPClient(responses: [
            "/api/v1/oauth/connections/oauth-1/refresh": Data(),
            "/api/v1/oauth/connections/oauth-2/refresh": Data()
        ])
        let preferences = XlyraMonitorPreferences(
            configURL: Self.temporaryXlyraConfigURL()
        )
        preferences.consoleURL = URL(string: "https://xlyra.example.test")!
        try preferences.saveAdminAccessToken("test-admin-access-token")

        try await XlyraAPIMonitorService(httpClient: http).refreshOAuthConnections(
            preferences: preferences,
            connectionIDs: ["oauth-1", "oauth-2"]
        )

        let requests = http.receivedRequests()
        #expect(requests.map { $0.httpMethod } == ["POST", "POST"])
        #expect(requests.map { Self.key(for: $0.url) } == [
            "/api/v1/oauth/connections/oauth-1/refresh",
            "/api/v1/oauth/connections/oauth-2/refresh"
        ])
        #expect(requests.allSatisfy {
            $0.value(forHTTPHeaderField: "X-Access-Token") == "test-admin-access-token"
        })
    }

    @Test
    func testXlyraOAuthImportUsesDocumentedImportEndpoint() async throws {
        let responseData = #"{"message":"ok","data":{"imported":2,"failed":0}}"#.data(using: .utf8)!
        let http = XlyraFakeHTTPClient(responses: [
            "/api/v1/oauth/import": responseData
        ])
        let preferences = XlyraMonitorPreferences(
            configURL: Self.temporaryXlyraConfigURL()
        )
        preferences.consoleURL = URL(string: "https://xlyra.example.test")!
        try preferences.saveAdminAccessToken("test-admin-access-token")

        let payload = #"{"items":[{"provider":"codex","refresh_token":"test-refresh-token"}]}"#.data(using: .utf8)!
        let result = try await XlyraAPIMonitorService(httpClient: http).importOAuthAccounts(
            preferences: preferences,
            payload: payload
        )

        #expect(result.message == "ok · 导入 2 · 失败 0")
        let requests = http.receivedRequests()
        #expect(requests.count == 1)
        #expect(requests.first?.httpMethod == "POST")
        #expect(Self.key(for: requests.first?.url) == "/api/v1/oauth/import")
        #expect(requests.first?.value(forHTTPHeaderField: "X-Access-Token") == "test-admin-access-token")
        #expect(requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(requests.first?.httpBody == payload)
    }

    @MainActor
    private static func containsScrollView(_ view: NSView) -> Bool {
        if view is NSScrollView {
            return true
        }
        return view.subviews.contains { containsScrollView($0) }
    }

    @MainActor
    private static func writePNG(_ view: NSView, to path: String) throws {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private static func key(for url: URL?) -> String {
        guard let url else { return "" }
        if let query = url.query, query.isEmpty == false {
            return "\(url.path)?\(query)"
        }
        return url.path
    }

    private static func temporaryXlyraConfigURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xlyra-monitor-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private static var longRenderSnapshotData: Data {
        let oauthRowValues: [String] = (1...4).map { index -> String in
            let email: String = index == 1 ? "laments_jabbers_8x@icloud.com" : "cording_forum2j+hx\(index)@icloud.com"
            let plan: String = index == 1 ? "team" : "plus"
            let fiveHourUsed: Double = index == 4 ? 84 : Double(index * 4)
            let weeklyUsed: Double = index == 1 ? 55 : Double(22 + index * 7)
            let tokens = 120_000 * index
            let cost = Double(index) * 12.34

            return oauthRowJSON(
                index: index,
                email: email,
                plan: plan,
                fiveHourUsed: fiveHourUsed,
                weeklyUsed: weeklyUsed,
                tokens: tokens,
                cost: cost
            )
        }
        let oauthRows = oauthRowValues.joined(separator: ",")

        let siteRowValues: [String] = (1...8).map { index -> String in
            let name: String = index <= 2 ? "Codex_\(index)_long_display_name" : "站点-\(index)"
            let type: String = index <= 2 ? "codex" : "openai"
            let healthy = index != 8
            let tokens = 80_000 * index
            let cost = Double(index) * 4.56

            return siteRowJSON(
                index: index,
                name: name,
                type: type,
                healthy: healthy,
                tokens: tokens,
                cost: cost
            )
        }
        let siteRows = siteRowValues.joined(separator: ",")

        let json = """
        {
          "generated_at": "2026-05-27T07:24:55.881939+00:00",
          "sites": { "total": 8, "healthy": 7, "rows": [\(siteRows)] },
          "oauth": { "total": 4, "healthy": 4, "limited": 0, "rows": [\(oauthRows)] },
          "api_keys": {
            "total": 2,
            "active": 2,
            "exhausted": 0,
            "rows": [
              { "name": "default", "masked_key": "sk-9...3786", "status": "active", "quota_limit": null, "quota_used": 473.80399505, "quota_unlimited": true, "last_used_at": "2026-05-27T07:24:36.423566+00:00", "expires_at": null },
              { "name": "zz", "masked_key": "****", "status": "active", "quota_limit": null, "quota_used": 0.00992, "quota_unlimited": true, "last_used_at": "2026-05-27T07:02:25.917869+00:00", "expires_at": null }
            ]
          },
          "requests": { "total": 3233, "last_hour": 313, "last_24h": 838, "ok_24h": 798, "failed_24h": 40, "avg_latency_24h": 16493 },
          "usage": { "tokens_24h": 69611061, "cost_24h": 111.55439685 },
          "errors": [
            { "error_type": "downstream_client_cancelled", "count": 24 },
            { "error_type": "upstream_timeout", "count": 9 }
          ],
          "cooldowns": { "active": 0 }
        }
        """
        return json.data(using: String.Encoding.utf8)!
    }

    private static func oauthRowJSON(
        index: Int,
        email: String,
        plan: String,
        fiveHourUsed: Double,
        weeklyUsed: Double,
        tokens: Int,
        cost: Double
    ) -> String {
        """
        {
          "id": "oauth-\(index)",
          "provider": "codex",
          "site_name": "Codex_account_site_\(index)",
          "site_slug": "codex-account-site-\(index)",
          "status": "connected",
          "account_id": "user-\(index)",
          "email": "\(email)",
          "plan_type": "\(plan)",
          "available": true,
          "limit_reached": false,
          "five_hour_used_percent": \(fiveHourUsed),
          "five_hour_remaining_percent": \(100 - fiveHourUsed),
          "five_hour_reset_at": \(1_779_875_344 + index * 900),
          "weekly_used_percent": \(weeklyUsed),
          "weekly_remaining_percent": \(100 - weeklyUsed),
          "weekly_reset_at": \(1_780_296_607 + index * 1800),
          "credits_balance": "\(index - 1)",
          "credits_unlimited": false,
          "last_refresh_at": "2026-05-27T05:0\(index):06.765101+00:00",
          "last_sync_at": "2026-05-27T06:0\(index):03.745145+00:00",
          "expires_at": "2026-06-06T05:06:06.765101+00:00",
          "tokens24h": \(tokens),
          "cost24h": \(cost)
        }
        """
    }

    private static func siteRowJSON(
        index: Int,
        name: String,
        type: String,
        healthy: Bool,
        tokens: Int,
        cost: Double
    ) -> String {
        """
        {
          "name": "\(name)",
          "slug": "site-\(index)",
          "type": "\(type)",
          "status": "active",
          "enabled": true,
          "priority": \(index),
          "validation_ok": \(healthy ? "true" : "false"),
          "sync_status": "\(healthy ? "synced" : "error")",
          "api_key_count": \(index % 3),
          "model_count": \(8 + index),
          "last_synced_at": "2026-05-27T06:00:02.650771+00:00",
          "tokens24h": \(tokens),
          "cost24h": \(cost),
          "recent_health": { "success": \(healthy ? "true" : "false"), "status_code": 200, "latency_ms": \(400 + index * 120), "error_type": null, "checked_at": "2026-05-27T07:10:01.539529+00:00" }
        }
        """
    }

    private static let renderSnapshotData = """
    {
      "generated_at": "2026-05-27T07:24:55.881939+00:00",
      "sites": {
        "total": 1,
        "healthy": 1,
        "rows": [
          {
            "name": "Codex_cord_jxxc",
            "slug": "codex-cord-jxxc",
            "type": "codex",
            "status": "active",
            "enabled": true,
            "priority": 4.0,
            "validation_ok": true,
            "sync_status": "synced",
            "api_key_count": 1,
            "model_count": 8,
            "last_synced_at": "2026-05-27T06:00:02.650771+00:00",
            "tokens24h": 18986032,
            "cost24h": 61.568621,
            "recent_health": { "success": true, "status_code": 200, "latency_ms": 522, "error_type": null, "checked_at": "2026-05-27T07:10:01.539529+00:00" }
          }
        ]
      },
      "oauth": {
        "total": 1,
        "healthy": 1,
        "limited": 0,
        "rows": [
          {
            "id": "oauth-1",
            "provider": "codex",
            "site_name": "Codex_cord_jxxc",
            "site_slug": "codex-cord-jxxc",
            "status": "connected",
            "account_id": "user-123",
            "email": "codex@example.com",
            "plan_type": "plus",
            "available": true,
            "limit_reached": false,
            "five_hour_used_percent": 4,
            "five_hour_remaining_percent": 96,
            "five_hour_reset_at": 1779875344,
            "weekly_used_percent": 27,
            "weekly_remaining_percent": 73,
            "weekly_reset_at": 1780296607,
            "credits_balance": "0",
            "credits_unlimited": false,
            "last_refresh_at": "2026-05-27T05:06:06.765101+00:00",
            "last_sync_at": "2026-05-27T06:00:03.745145+00:00",
            "expires_at": "2026-06-06T05:06:06.765101+00:00",
            "tokens24h": 18986032,
            "cost24h": 61.568621
          }
        ]
      },
      "api_keys": { "total": 0, "active": 0, "exhausted": 0, "rows": [] },
      "requests": { "total": 3233, "last_hour": 313, "last_24h": 838, "ok_24h": 798, "failed_24h": 40, "avg_latency_24h": 16493 },
      "usage": { "tokens_24h": 69611061, "cost_24h": 111.55439685 },
      "errors": [{ "error_type": "upstream_timeout", "count": 9 }],
      "cooldowns": { "active": 0 }
    }
    """.data(using: .utf8)!

    private static let apiOverviewData = """
    {
      "meta": {
        "generated_at": "2026-05-27T07:24:55.881939Z"
      },
      "kpis": {
        "cost": {
          "today": 2.5,
          "total": 10.75,
          "currency": "USD"
        },
        "requests": {
          "today": 10,
          "today_tokens": "111",
          "success_rate": 0.9
        },
        "rate_limit": {
          "rpm": { "used": 2 },
          "tpm": { "used": 3456, "actual": 111, "reserved": 0 }
        }
      },
      "errors": [
        { "error_type": "upstream_timeout", "count": 1 }
      ],
      "windows": {
        "7": {
          "site_cost_summary": [
            {
              "site_id": "site-1",
              "site_name": "Codex Site",
              "request_count": 10,
              "success_count": 9,
              "success_rate": 0.9,
              "total_tokens": "111",
              "cost": 2.5,
              "currency": "USD"
            }
          ]
        }
      }
    }
    """.data(using: .utf8)!

    private static let apiVersionData = """
    {
      "version": "1.0.0",
      "build": "test"
    }
    """.data(using: .utf8)!

    private static let apiSiteTypesData = """
    {
      "data": ["openai", "codex", "xlyra"]
    }
    """.data(using: .utf8)!

    private static let apiOAuthData = """
    {
      "items": [
        {
          "id": "oauth-1",
          "provider": "codex",
          "site": {
            "name": "Codex_account_site_1",
            "slug": "codex-account-site-1",
            "site_type": "codex",
            "model_count": 8,
            "routing_priority": 1,
            "oauth_account": { "plan_type": "team" },
            "sync_state": {
              "status": "synced",
              "validation_ok": true,
              "last_synced_at": "2026-05-27T06:01:03.745145+00:00"
            },
            "usage": {
              "request_count": 10,
              "success_count": 9,
              "failed_count": 1,
              "total_tokens": "120000",
              "estimated_cost": 12.34,
              "currency": "USD"
            }
          },
          "status": "connected",
          "account_id": "user-1",
          "email": "codex@example.com",
          "meta": {
            "plan_type": "team",
            "quota": {
              "plan_type": "team",
              "available": true,
              "limit_reached": false,
              "allowed": true,
              "five_hour": { "used_percent": 4, "remaining_percent": 96, "reset_at": 1779875344 },
              "weekly": { "used_percent": 55, "remaining_percent": 45, "reset_at": 1780296607 },
              "credits": { "balance": "2", "unlimited": false }
            }
          },
          "last_refresh_at": "2026-05-27T05:01:06.765101+00:00",
          "last_sync_at": "2026-05-27T06:01:03.745145+00:00",
          "expires_at": "2026-06-06T05:06:06.765101+00:00"
        }
      ],
      "meta": { "count": 1 }
    }
    """.data(using: .utf8)!

    private static let apiSitesData = """
    {
      "items": [
        {
          "id": "site-1",
          "name": "Codex Site",
          "slug": "codex-site",
          "site_type": "codex",
          "status": "active",
          "enabled": true,
          "routing_priority": 1,
          "api_key_count": 1,
          "model_count": 8,
          "sync_state": {
            "status": "synced",
            "validation_ok": true,
            "last_synced_at": "2026-05-27T06:00:02.650771+00:00"
          },
          "validation": { "ok": true },
          "usage": {
            "request_count": 10,
            "success_count": 9,
            "failed_count": 1,
            "total_tokens": "120000",
            "estimated_cost": 12.34,
            "currency": "USD"
          }
        }
      ],
      "meta": { "count": 1 }
    }
    """.data(using: .utf8)!

    private static let apiKeysData = """
    {
      "items": [
        {
          "name": "default",
          "masked_key": "sk-9...3786",
          "status": "active",
          "quota_unlimited": true,
          "quota_used": 4.5
        }
      ],
      "meta": { "count": 1 }
    }
    """.data(using: .utf8)!

    private static let apiHealthSitesData = """
    {
      "items": [
        {
          "health": {
            "site_id": "site-1",
            "status": "healthy",
            "recent_avg_latency_ms": 345,
            "recent_success_rate": 1,
            "checked_at": "2026-05-27T07:10:01Z",
            "message": "ok"
          },
          "site": {
            "id": "site-1",
            "slug": "codex-site",
            "name": "Codex Site",
            "site_type": "codex",
            "enabled": true,
            "status": "active"
          }
        }
      ],
      "meta": { "count": 1 }
    }
    """.data(using: .utf8)!

    private static let apiCooldownsData = """
    {
      "items": [
        { "site_id": "site-1", "reason": "rate_limit" },
        { "site_id": "site-2", "reason": "upstream_error" }
      ],
      "meta": { "count": 2 }
    }
    """.data(using: .utf8)!

    private static let apiRequestsData = """
    {
      "items": [
        { "id": "req-1", "success": false, "error_type": "upstream_timeout" }
      ],
      "meta": {
        "total": 1,
        "rate_usage": { "rpm": 12, "tpm": 3456 }
      }
    }
    """.data(using: .utf8)!
}

private final class XlyraFakeHTTPClient: XlyraHTTPClient {
    private let queue = DispatchQueue(label: "XlyraFakeHTTPClient.requests")
    private let responses: [String: Data]
    private var requests: [URLRequest] = []

    init(responses: [String: Data]) {
        self.responses = responses
    }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> XlyraHTTPResponse {
        queue.sync {
            requests.append(request)
        }

        let key = Self.key(for: request.url)
        guard let data = responses[key] else {
            return XlyraHTTPResponse(statusCode: 404, data: Data())
        }
        return XlyraHTTPResponse(statusCode: 200, data: data)
    }

    func receivedRequests() -> [URLRequest] {
        queue.sync { requests }
    }

    private static func key(for url: URL?) -> String {
        guard let url else { return "" }
        if let query = url.query, query.isEmpty == false {
            return "\(url.path)?\(query)"
        }
        return url.path
    }
}
