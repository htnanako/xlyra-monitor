import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("QuotaModelsTests")
struct QuotaModelsTests {
    @Test
    func missingUnitFallsBackToDefaultDisplayUnit() {
        let quota = QuotaSnapshot(
            available: true,
            remaining: 12.5,
            unit: nil,
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 10)
        )

        #expect(quota.displayUnit == "额度")
    }

    @Test
    func blankUnitFallsBackToDefaultDisplayUnit() {
        let quota = QuotaSnapshot(
            available: true,
            remaining: 12.5,
            unit: "  \n\t",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 10)
        )

        #expect(quota.displayUnit == "额度")
    }

    @Test
    func displayUnitReturnsTrimmedUnit() {
        let quota = QuotaSnapshot(
            available: true,
            remaining: 12.5,
            unit: " USD ",
            backendUpdatedAt: nil,
            clientRefreshedAt: Date(timeIntervalSince1970: 10)
        )

        #expect(quota.displayUnit == "USD")
    }

    @Test
    func menuTimePrefersBackendUpdatedAt() {
        let backend = Date(timeIntervalSince1970: 20)
        let client = Date(timeIntervalSince1970: 10)
        let quota = QuotaSnapshot(
            available: true,
            remaining: 12.5,
            unit: "USD",
            backendUpdatedAt: backend,
            clientRefreshedAt: client
        )

        #expect(quota.menuLastUpdatedAt == backend)
    }

    @Test
    func menuTimeFallsBackToClientRefreshTime() {
        let client = Date(timeIntervalSince1970: 10)
        let quota = QuotaSnapshot(
            available: true,
            remaining: 12.5,
            unit: "USD",
            backendUpdatedAt: nil,
            clientRefreshedAt: client
        )

        #expect(quota.menuLastUpdatedAt == client)
    }
}
