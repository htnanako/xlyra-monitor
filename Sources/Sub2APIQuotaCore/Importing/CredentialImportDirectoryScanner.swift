import Foundation

public struct CredentialImportCandidate: Equatable, Identifiable {
    public var id: String { fileURL.path }
    public let fileURL: URL
    public let fileName: String
    public let fileSize: Int64
    public let modifiedAt: Date?

    public init(fileURL: URL, fileName: String, fileSize: Int64, modifiedAt: Date?) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}

public protocol CredentialImportDirectoryScanning {
    func scan(directory: URL) throws -> [CredentialImportCandidate]
}

public struct CredentialImportDirectoryScanner: CredentialImportDirectoryScanning {
    private let historyStore: ImportHistoryStore

    public init(historyStore: ImportHistoryStore) {
        self.historyStore = historyStore
    }

    public func scan(directory: URL) throws -> [CredentialImportCandidate] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CredentialImportError.unreadableDirectory
        }

        let imported = historyStore.successfullyImportedFileNames()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            let name = url.lastPathComponent
            guard isSupportedImportFile(name: name, pathExtension: url.pathExtension),
                  imported.contains(name) == false else {
                return nil
            }

            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return CredentialImportCandidate(
                fileURL: url,
                fileName: name,
                fileSize: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate
            )
        }
        .sorted { left, right in
            switch (left.modifiedAt, right.modifiedAt) {
            case let (leftDate?, rightDate?):
                return leftDate > rightDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return left.fileName > right.fileName
            }
        }
    }

    private func isSupportedImportFile(name: String, pathExtension: String) -> Bool {
        let lowercasedName = name.lowercased()
        let lowercasedExtension = pathExtension.lowercased()

        if lowercasedExtension == "zip" {
            return lowercasedName.hasPrefix("codex_credentials_")
        }

        if lowercasedExtension == "json" {
            return lowercasedName.hasPrefix("sub2_") ||
                lowercasedName.hasPrefix("sub2api-import")
        }

        return false
    }
}
