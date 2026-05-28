import Foundation

public struct AccountImportResult: Equatable {
    public let accountCreated: Int
    public let accountFailed: Int
    public let proxyCreated: Int
    public let proxyReused: Int
    public let proxyFailed: Int
    public let errors: [String]

    public init(
        accountCreated: Int,
        accountFailed: Int,
        proxyCreated: Int,
        proxyReused: Int,
        proxyFailed: Int,
        errors: [String] = []
    ) {
        self.accountCreated = accountCreated
        self.accountFailed = accountFailed
        self.proxyCreated = proxyCreated
        self.proxyReused = proxyReused
        self.proxyFailed = proxyFailed
        self.errors = errors
    }

    public var isFullySuccessful: Bool {
        accountFailed == 0 && proxyFailed == 0
    }

    public var summary: String {
        "账号创建 \(accountCreated)，账号失败 \(accountFailed)，代理创建 \(proxyCreated)，代理失败 \(proxyFailed)"
    }
}

public struct ImportHistoryRecord: Codable, Equatable, Identifiable {
    public var id: String { fileName }
    public let fileName: String
    public let fileSize: Int64
    public let modifiedAt: Date?
    public let importedAt: Date
    public let accountCreated: Int
    public let accountFailed: Int
    public let proxyCreated: Int
    public let proxyFailed: Int
    public let summary: String

    public init(
        fileName: String,
        fileSize: Int64,
        modifiedAt: Date?,
        importedAt: Date,
        accountCreated: Int,
        accountFailed: Int,
        proxyCreated: Int,
        proxyFailed: Int,
        summary: String
    ) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.importedAt = importedAt
        self.accountCreated = accountCreated
        self.accountFailed = accountFailed
        self.proxyCreated = proxyCreated
        self.proxyFailed = proxyFailed
        self.summary = summary
    }
}

public final class ImportHistoryStore {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "sub2api.importHistory"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadRecords() throws -> [ImportHistoryRecord] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return try decoder.decode([ImportHistoryRecord].self, from: data)
    }

    public func successfullyImportedFileNames() -> Set<String> {
        (try? Set(loadRecords().map(\.fileName))) ?? []
    }

    public func recordSuccessfulImport(_ record: ImportHistoryRecord) throws {
        var records = try loadRecords().filter { $0.fileName != record.fileName }
        records.insert(record, at: 0)
        userDefaults.set(try encoder.encode(records), forKey: key)
    }

    public func clear() {
        userDefaults.removeObject(forKey: key)
    }
}

