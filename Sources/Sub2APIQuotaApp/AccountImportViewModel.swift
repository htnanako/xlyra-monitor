import Foundation
import Sub2APIQuotaCore

enum AccountImportItemState: Equatable {
    case pending
    case importing
    case imported
    case failed
}

struct AccountImportItem: Identifiable {
    let id: String
    let package: CredentialImportPackage
    var isSelected: Bool
    var state: AccountImportItemState
    var resultSummary: String?
    var errorMessage: String?

    var fileName: String { package.fileName }
    var accountCount: Int { package.accountCount }
    var proxyCount: Int { package.proxyCount }
}

@MainActor
final class AccountImportViewModel: ObservableObject {
    @Published var pathText = ""
    @Published var importDirectoryText = ""
    @Published private(set) var items: [AccountImportItem] = []
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isImporting = false
    @Published private(set) var isCleaningRevokedAccounts = false

    private let credentialStore: CredentialLoading
    private let preferences: AppPreferences
    private let reader: CredentialImportReading
    private let scanner: CredentialImportDirectoryScanning
    private let importer: AccountImporting
    private let revokedAccountCleaner: RevokedAccountCleaning
    private let historyStore: ImportHistoryStore
    private let refresher: ManualRefreshing
    private let now: () -> Date

    init(
        credentialStore: CredentialLoading,
        preferences: AppPreferences,
        reader: CredentialImportReading,
        scanner: CredentialImportDirectoryScanning,
        importer: AccountImporting,
        revokedAccountCleaner: RevokedAccountCleaning,
        historyStore: ImportHistoryStore,
        refresher: ManualRefreshing,
        now: @escaping () -> Date = Date.init
    ) {
        self.credentialStore = credentialStore
        self.preferences = preferences
        self.reader = reader
        self.scanner = scanner
        self.importer = importer
        self.revokedAccountCleaner = revokedAccountCleaner
        self.historyStore = historyStore
        self.refresher = refresher
        self.now = now
        importDirectoryText = preferences.importDirectoryPath
    }

    func refreshFromPreferences() {
        importDirectoryText = preferences.importDirectoryPath
    }

    func saveImportDirectory() {
        preferences.updateImportDirectoryPath(importDirectoryText)
        statusMessage = "已保存导入目录"
    }

    func loadClipboardTextIfPossible(_ text: String?) async {
        guard let text,
              (try? CredentialImportPathParser.parse(text)) != nil else {
            return
        }

        await loadPathText(text)
    }

    func loadPathText(_ text: String) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            let url = try CredentialImportPathParser.parse(text)
            let package = try reader.readPackage(at: url)
            pathText = url.path
            items = [makeItem(package: package)]
            statusMessage = "已读取 \(package.fileName)，账号 \(package.accountCount) 个"
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func scanImportDirectory() async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            preferences.updateImportDirectoryPath(importDirectoryText)
            let directoryURL = URL(fileURLWithPath: (importDirectoryText as NSString).expandingTildeInPath)
            let candidates = try scanner.scan(directory: directoryURL)
            guard candidates.isEmpty == false else {
                items = []
                statusMessage = "没有发现未导入文件"
                return
            }

            items = try candidates.map { candidate in
                makeItem(package: try reader.readPackage(at: candidate.fileURL))
            }
            statusMessage = "发现 \(items.count) 个未导入文件"
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func setSelected(_ itemID: String, isSelected: Bool) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        items[index].isSelected = isSelected
    }

    func importSelected() async {
        clearMessages()
        guard items.contains(where: \.isSelected) else {
            errorMessage = "请选择要导入的文件"
            return
        }

        guard let configuration = loadConfiguration() else {
            return
        }

        isImporting = true
        defer { isImporting = false }

        var didAttemptImport = false
        for index in items.indices where items[index].isSelected {
            didAttemptImport = true
            items[index].state = .importing
            do {
                let result = try await importer.importAccounts(
                    configuration: ServiceConfiguration(
                        serviceRoot: configuration.serviceRoot,
                        quotaURL: configuration.quotaURL
                    ),
                    credential: LoginCredential(email: configuration.email, password: configuration.apiKey),
                    payload: items[index].package.payloadObject
                )
                items[index].resultSummary = result.summary
                if result.isFullySuccessful {
                    items[index].state = .imported
                    try historyStore.recordSuccessfulImport(
                        ImportHistoryRecord(
                            fileName: items[index].package.fileName,
                            fileSize: items[index].package.fileSize,
                            modifiedAt: items[index].package.modifiedAt,
                            importedAt: now(),
                            accountCreated: result.accountCreated,
                            accountFailed: result.accountFailed,
                            proxyCreated: result.proxyCreated,
                            proxyFailed: result.proxyFailed,
                            summary: result.summary
                        )
                    )
                } else {
                    items[index].state = .failed
                    items[index].errorMessage = result.errors.first ?? "部分账号导入失败"
                }
            } catch {
                items[index].state = .failed
                items[index].errorMessage = userMessage(for: error)
            }
        }

        if didAttemptImport {
            await refresher.refresh(source: .manual)
            statusMessage = "导入完成，已刷新额度"
        }
    }

    func clearHistory() {
        historyStore.clear()
        statusMessage = "已清空导入历史"
    }

    func deleteRevoked401Accounts() async {
        clearMessages()
        guard let configuration = loadConfiguration() else {
            return
        }

        isCleaningRevokedAccounts = true
        defer { isCleaningRevokedAccounts = false }

        do {
            let result = try await revokedAccountCleaner.deleteRevoked401Accounts(
                configuration: ServiceConfiguration(
                    serviceRoot: configuration.serviceRoot,
                    quotaURL: configuration.quotaURL
                ),
                credential: LoginCredential(email: configuration.email, password: configuration.apiKey)
            )
            await refresher.refresh(source: .manual)
            statusMessage = "401 错误账号清理完成，\(result.summary)"
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    private func makeItem(package: CredentialImportPackage) -> AccountImportItem {
        AccountImportItem(
            id: package.fileURL.path,
            package: package,
            isSelected: true,
            state: .pending,
            resultSummary: nil,
            errorMessage: nil
        )
    }

    private func loadConfiguration() -> StoredConfiguration? {
        do {
            guard let configuration = try credentialStore.load() else {
                errorMessage = "请先配置服务地址、邮箱和密码"
                return nil
            }
            return configuration
        } catch {
            errorMessage = "读取配置失败"
            return nil
        }
    }

    private func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }

    private func userMessage(for error: Error) -> String {
        switch error {
        case CredentialImportError.invalidPath:
            return "导入路径无效"
        case CredentialImportError.fileNotFound:
            return "导入文件不存在"
        case CredentialImportError.notZipFile:
            return "请选择 zip 或 json 文件"
        case CredentialImportError.unreadableZip:
            return "无法读取 zip 文件"
        case CredentialImportError.missingImportJSON:
            return "zip 内缺少 sub2api-import.json"
        case CredentialImportError.invalidJSON:
            return "导入 JSON 格式错误"
        case CredentialImportError.missingAccounts:
            return "导入 JSON 缺少 accounts"
        case CredentialImportError.unreadableDirectory:
            return "导入目录不可读"
        case QuotaErrorKind.authenticationFailed:
            return "Sub2API 登录失败"
        case QuotaErrorKind.timeout:
            return "导入请求超时"
        case QuotaErrorKind.network:
            return "网络异常"
        case QuotaErrorKind.serviceUnavailable:
            return "Sub2API 服务不可用"
        default:
            return "导入失败"
        }
    }
}
