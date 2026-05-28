import Testing
@testable import Sub2APIQuotaCore

@Suite("SmokeTests")
struct SmokeTests {
    @Test
    func testCoreModuleLoads() {
        #expect(QuotaStatus.notConfigured.menuBarColorName == "gray")
    }
}
