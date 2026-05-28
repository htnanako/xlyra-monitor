import Foundation
import Testing
@testable import Sub2APIQuotaApp
@testable import Sub2APIQuotaCore

@Suite("AccountImportViewModelTests")
@MainActor
struct AccountImportViewModelTests {
    @Test
    func loadsClipboardStylePathTextAndReadsPackage() async throws {
        let package = samplePackage(fileName: "codex_credentials_one.zip")
        let model = AccountImportViewModel(
            credentialStore: FakeImportCredentialStore(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            reader: FakeImportReader(packagesByPath: [package.fileURL.path: package]),
            scanner: FakeImportScanner(candidates: []),
            importer: FakeAccountImporter(),
            revokedAccountCleaner: FakeRevokedAccountCleaner(),
            historyStore: ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            refresher: FakeManualRefresher()
        )

        await model.loadPathText("  \"\(package.fileURL.path)\"  ")

        #expect(model.pathText == package.fileURL.path)
        #expect(model.items.map(\.fileName) == ["codex_credentials_one.zip"])
        #expect(model.items.first?.accountCount == 1)
        #expect(model.items.first?.isSelected == true)
    }

    @Test
    func scansDirectoryAndSelectsAllNewPackages() async throws {
        let first = samplePackage(fileName: "codex_credentials_a.zip")
        let second = samplePackage(fileName: "codex_credentials_b.zip")
        let model = AccountImportViewModel(
            credentialStore: FakeImportCredentialStore(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            reader: FakeImportReader(packagesByPath: [
                first.fileURL.path: first,
                second.fileURL.path: second
            ]),
            scanner: FakeImportScanner(
                candidates: [
                    CredentialImportCandidate(fileURL: first.fileURL, fileName: first.fileName, fileSize: first.fileSize, modifiedAt: nil),
                    CredentialImportCandidate(fileURL: second.fileURL, fileName: second.fileName, fileSize: second.fileSize, modifiedAt: nil)
                ]
            ),
            importer: FakeAccountImporter(),
            revokedAccountCleaner: FakeRevokedAccountCleaner(),
            historyStore: ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            refresher: FakeManualRefresher()
        )

        await model.scanImportDirectory()

        #expect(model.items.map(\.fileName) == ["codex_credentials_a.zip", "codex_credentials_b.zip"])
        #expect(model.items.map(\.isSelected) == [true, true])
        #expect(model.statusMessage == "发现 2 个未导入文件")
    }

    @Test
    func successfulImportRecordsHistoryAndRefreshesQuota() async throws {
        let package = samplePackage(fileName: "codex_credentials_success.zip")
        let history = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let refresher = FakeManualRefresher()
        let importer = FakeAccountImporter(result: AccountImportResult(accountCreated: 1, accountFailed: 0, proxyCreated: 0, proxyReused: 0, proxyFailed: 0))
        let model = AccountImportViewModel(
            credentialStore: FakeImportCredentialStore(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            reader: FakeImportReader(packagesByPath: [package.fileURL.path: package]),
            scanner: FakeImportScanner(candidates: []),
            importer: importer,
            revokedAccountCleaner: FakeRevokedAccountCleaner(),
            historyStore: history,
            refresher: refresher
        )
        await model.loadPathText(package.fileURL.path)

        await model.importSelected()

        #expect(try history.loadRecords().map(\.fileName) == ["codex_credentials_success.zip"])
        #expect(refresher.refreshSources == [.manual])
        #expect(model.items.first?.resultSummary?.contains("账号创建 1") == true)
    }

    @Test
    func partialFailureDoesNotRecordHistoryButStillRefreshesQuota() async throws {
        let package = samplePackage(fileName: "codex_credentials_partial.zip")
        let history = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let refresher = FakeManualRefresher()
        let importer = FakeAccountImporter(result: AccountImportResult(accountCreated: 1, accountFailed: 1, proxyCreated: 0, proxyReused: 0, proxyFailed: 0))
        let model = AccountImportViewModel(
            credentialStore: FakeImportCredentialStore(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            reader: FakeImportReader(packagesByPath: [package.fileURL.path: package]),
            scanner: FakeImportScanner(candidates: []),
            importer: importer,
            revokedAccountCleaner: FakeRevokedAccountCleaner(),
            historyStore: history,
            refresher: refresher
        )
        await model.loadPathText(package.fileURL.path)

        await model.importSelected()

        #expect(try history.loadRecords().isEmpty)
        #expect(refresher.refreshSources == [.manual])
        #expect(model.items.first?.state == .failed)
    }

    @Test
    func deletingRevokedAccountsRefreshesQuotaAndShowsSummary() async throws {
        let refresher = FakeManualRefresher()
        let cleaner = FakeRevokedAccountCleaner(result: RevokedAccountCleanupResult(matchedCount: 6, deletedCount: 6, failedCount: 0))
        let model = AccountImportViewModel(
            credentialStore: FakeImportCredentialStore(),
            preferences: AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            reader: FakeImportReader(packagesByPath: [:]),
            scanner: FakeImportScanner(candidates: []),
            importer: FakeAccountImporter(),
            revokedAccountCleaner: cleaner,
            historyStore: ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            refresher: refresher
        )

        await model.deleteRevoked401Accounts()

        #expect(cleaner.callCount == 1)
        #expect(refresher.refreshSources == [.manual])
        #expect(model.statusMessage == "401 错误账号清理完成，匹配 6 个，删除 6 个，失败 0 个")
    }

    private func samplePackage(fileName: String) -> CredentialImportPackage {
        let url = URL(fileURLWithPath: "/tmp/\(fileName)")
        return CredentialImportPackage(
            fileURL: url,
            fileName: fileName,
            fileSize: 100,
            modifiedAt: Date(timeIntervalSince1970: 10),
            accountCount: 1,
            proxyCount: 0,
            payloadData: Data(),
            payloadObject: ["accounts": [["name": "hidden"]], "proxies": []]
        )
    }
}

private struct FakeImportReader: CredentialImportReading {
    let packagesByPath: [String: CredentialImportPackage]

    func readPackage(at fileURL: URL) throws -> CredentialImportPackage {
        guard let package = packagesByPath[fileURL.path] else {
            throw CredentialImportError.fileNotFound
        }
        return package
    }
}

private struct FakeImportScanner: CredentialImportDirectoryScanning {
    let candidates: [CredentialImportCandidate]

    func scan(directory: URL) throws -> [CredentialImportCandidate] {
        candidates
    }
}

private final class FakeAccountImporter: AccountImporting {
    let result: AccountImportResult

    init(result: AccountImportResult = AccountImportResult(accountCreated: 0, accountFailed: 0, proxyCreated: 0, proxyReused: 0, proxyFailed: 0)) {
        self.result = result
    }

    func importAccounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential,
        payload: [String: Any]
    ) async throws -> AccountImportResult {
        result
    }
}

private final class FakeRevokedAccountCleaner: RevokedAccountCleaning {
    let result: RevokedAccountCleanupResult
    private(set) var callCount = 0

    init(result: RevokedAccountCleanupResult = RevokedAccountCleanupResult(matchedCount: 0, deletedCount: 0, failedCount: 0)) {
        self.result = result
    }

    func deleteRevoked401Accounts(
        configuration: ServiceConfiguration,
        credential: LoginCredential
    ) async throws -> RevokedAccountCleanupResult {
        callCount += 1
        return result
    }
}

private final class FakeImportCredentialStore: CredentialLoading {
    func load() throws -> StoredConfiguration? {
        StoredConfiguration(
            serviceRoot: URL(string: "https://example.com")!,
            quotaURL: URL(string: "https://example.com/api/quota")!,
            email: "admin@example.com",
            apiKey: "secret",
            threshold: Decimal(10)
        )
    }
}

private final class FakeManualRefresher: ManualRefreshing {
    private(set) var refreshSources: [RefreshSource] = []

    func refresh(source: RefreshSource) async {
        refreshSources.append(source)
    }
}
