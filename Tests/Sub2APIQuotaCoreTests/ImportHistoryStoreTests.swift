import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("ImportHistoryStoreTests")
struct ImportHistoryStoreTests {
    @Test
    func recordsSuccessfulImportAndFiltersByFilename() throws {
        let store = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let record = ImportHistoryRecord(
            fileName: "codex_credentials_2026.zip",
            fileSize: 123,
            modifiedAt: Date(timeIntervalSince1970: 10),
            importedAt: Date(timeIntervalSince1970: 20),
            accountCreated: 1,
            accountFailed: 0,
            proxyCreated: 0,
            proxyFailed: 0,
            summary: "ok"
        )

        try store.recordSuccessfulImport(record)

        #expect(store.successfullyImportedFileNames() == ["codex_credentials_2026.zip"])
        #expect(try store.loadRecords().first?.accountCreated == 1)
    }

    @Test
    func doesNotRecordFailedResultAsSuccessfulImport() throws {
        let store = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let result = AccountImportResult(
            accountCreated: 1,
            accountFailed: 1,
            proxyCreated: 0,
            proxyReused: 0,
            proxyFailed: 0,
            errors: ["failed"]
        )

        #expect(result.isFullySuccessful == false)
        #expect(store.successfullyImportedFileNames().isEmpty)
    }

    @Test
    func clearRemovesRecords() throws {
        let store = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        try store.recordSuccessfulImport(
            ImportHistoryRecord(
                fileName: "codex_credentials_2026.zip",
                fileSize: 123,
                modifiedAt: nil,
                importedAt: Date(),
                accountCreated: 1,
                accountFailed: 0,
                proxyCreated: 0,
                proxyFailed: 0,
                summary: "ok"
            )
        )

        store.clear()

        #expect(try store.loadRecords().isEmpty)
    }
}

