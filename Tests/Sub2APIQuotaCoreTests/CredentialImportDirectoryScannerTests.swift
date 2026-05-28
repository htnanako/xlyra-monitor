import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("CredentialImportDirectoryScannerTests")
struct CredentialImportDirectoryScannerTests {
    @Test
    func returnsSupportedImportFilesNotInHistory() throws {
        let directory = try TemporaryDirectory()
        _ = try directory.makeFile(name: "notes.txt")
        _ = try directory.makeFile(name: "other.zip")
        let oldZip = try directory.makeFile(name: "codex_credentials_2026-05-09.zip")
        let newZip = try directory.makeFile(name: "codex_credentials_2026-05-10.zip")
        let sub2JSON = try directory.makeFile(name: "sub2_person@example.com.json")
        let exportJSON = try directory.makeFile(name: "sub2api-import.json")
        let history = ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        try history.recordSuccessfulImport(
            ImportHistoryRecord(
                fileName: oldZip.lastPathComponent,
                fileSize: 1,
                modifiedAt: nil,
                importedAt: Date(),
                accountCreated: 1,
                accountFailed: 0,
                proxyCreated: 0,
                proxyFailed: 0,
                summary: "ok"
            )
        )
        let scanner = CredentialImportDirectoryScanner(historyStore: history)

        let files = try scanner.scan(directory: directory.url)

        #expect(Set(files.map(\.fileName)) == [
            exportJSON.lastPathComponent,
            sub2JSON.lastPathComponent,
            newZip.lastPathComponent
        ])
    }

    @Test
    func sortsNewestFilesFirst() throws {
        let directory = try TemporaryDirectory()
        let older = try directory.makeFile(name: "codex_credentials_older.zip")
        let newer = try directory.makeFile(name: "codex_credentials_newer.zip")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2)], ofItemAtPath: newer.path)
        let scanner = CredentialImportDirectoryScanner(historyStore: ImportHistoryStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))

        let files = try scanner.scan(directory: directory.url)

        #expect(files.map(\.fileName) == ["codex_credentials_newer.zip", "codex_credentials_older.zip"])
    }
}

final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func makeFile(name: String, contents: String = "x") throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: fileURL)
        return fileURL
    }

    func makeZip(name: String, entries: [String: String]) throws -> URL {
        let source = url.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        for (entryName, contents) in entries {
            let entryURL = source.appendingPathComponent(entryName)
            try FileManager.default.createDirectory(at: entryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.data(using: .utf8)!.write(to: entryURL)
        }

        let zipURL = url.appendingPathComponent(name)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-r", zipURL.path, "."]
        process.currentDirectoryURL = source
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        return zipURL
    }
}
