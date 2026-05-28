import Foundation

public struct CredentialImportPackage {
    public let fileURL: URL
    public let fileName: String
    public let fileSize: Int64
    public let modifiedAt: Date?
    public let accountCount: Int
    public let proxyCount: Int
    public let payloadData: Data
    public let payloadObject: [String: Any]

    public init(
        fileURL: URL,
        fileName: String,
        fileSize: Int64,
        modifiedAt: Date?,
        accountCount: Int,
        proxyCount: Int,
        payloadData: Data,
        payloadObject: [String: Any]
    ) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.accountCount = accountCount
        self.proxyCount = proxyCount
        self.payloadData = payloadData
        self.payloadObject = payloadObject
    }
}

public protocol CredentialImportReading {
    func readPackage(at fileURL: URL) throws -> CredentialImportPackage
}

public struct CredentialImportReader: CredentialImportReading {
    public init() {}

    public func readPackage(at fileURL: URL) throws -> CredentialImportPackage {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CredentialImportError.fileNotFound
        }

        guard ["zip", "json"].contains(fileURL.pathExtension.lowercased()) else {
            throw CredentialImportError.notZipFile
        }

        let payloadData = try readImportJSONData(from: fileURL)
        let object: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
                throw CredentialImportError.invalidJSON
            }
            object = try normalizeImportObject(parsed)
        } catch let error as CredentialImportError {
            throw error
        } catch {
            throw CredentialImportError.invalidJSON
        }

        guard let accounts = object["accounts"] as? [Any] else {
            throw CredentialImportError.missingAccounts
        }

        let proxies = object["proxies"] as? [Any] ?? []
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = attributes[.modificationDate] as? Date

        return CredentialImportPackage(
            fileURL: fileURL,
            fileName: fileURL.lastPathComponent,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            accountCount: accounts.count,
            proxyCount: proxies.count,
            payloadData: payloadData,
            payloadObject: object
        )
    }

    private func readImportJSONData(from fileURL: URL) throws -> Data {
        if fileURL.pathExtension.lowercased() == "json" {
            do {
                let data = try Data(contentsOf: fileURL)
                guard data.isEmpty == false else {
                    throw CredentialImportError.missingImportJSON
                }
                return data
            } catch let error as CredentialImportError {
                throw error
            } catch {
                throw CredentialImportError.invalidJSON
            }
        }

        return try readImportJSONDataFromZip(fileURL)
    }

    private func readImportJSONDataFromZip(_ zipURL: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zipURL.path, "sub2api-import.json"]

        let output = Pipe()
        let errorOutput = Pipe()
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CredentialImportError.unreadableZip
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? ""
            if errorText.contains("filename not matched") {
                return try readFallbackCredentialJSONData(from: zipURL)
            }
            throw CredentialImportError.unreadableZip
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard data.isEmpty == false else {
            throw CredentialImportError.missingImportJSON
        }
        return data
    }

    private func readFallbackCredentialJSONData(from zipURL: URL) throws -> Data {
        let entryNames = try listEntryNames(in: zipURL)
        guard let credentialEntryName = entryNames.first(where: { entryName in
            entryName.lowercased().hasSuffix(".json") &&
                entryName.split(separator: "/").last != "sub2api-import.json"
        }) else {
            throw CredentialImportError.missingImportJSON
        }

        return try readEntryData(named: credentialEntryName, from: zipURL)
    }

    private func listEntryNames(in zipURL: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", zipURL.path]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CredentialImportError.unreadableZip
        }

        guard process.terminationStatus == 0 else {
            throw CredentialImportError.unreadableZip
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.hasSuffix("/") == false }
    }

    private func readEntryData(named entryName: String, from zipURL: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zipURL.path, entryName]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CredentialImportError.unreadableZip
        }

        guard process.terminationStatus == 0 else {
            throw CredentialImportError.unreadableZip
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard data.isEmpty == false else {
            throw CredentialImportError.missingImportJSON
        }
        return data
    }

    private func normalizeImportObject(_ object: [String: Any]) throws -> [String: Any] {
        if object["accounts"] is [Any] {
            return object
        }

        guard let email = trimmedString(object["email"]),
              let refreshToken = trimmedString(object["refresh_token"]) else {
            return object
        }

        var credentials: [String: Any] = [
            "email": email,
            "refresh_token": refreshToken
        ]

        copyString("access_token", from: object, to: &credentials)
        copyString("id_token", from: object, to: &credentials)
        copyString("account_id", from: object, to: &credentials, as: "chatgpt_account_id")
        copyString("expired", from: object, to: &credentials, as: "expires_at")

        let type = trimmedString(object["type"]) ?? "codex"
        let account: [String: Any] = [
            "name": email,
            "platform": "openai",
            "type": type,
            "credentials": credentials,
            "concurrency": 10,
            "priority": 1,
            "rate_multiplier": 1,
            "auto_pause_on_expired": true,
            "extra": [
                "email": email,
                "privacy_mode": false
            ]
        ]

        return [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "proxies": [],
            "accounts": [account]
        ]
    }

    private func copyString(
        _ sourceKey: String,
        from source: [String: Any],
        to target: inout [String: Any],
        as targetKey: String? = nil
    ) {
        guard let value = trimmedString(source[sourceKey]) else {
            return
        }

        target[targetKey ?? sourceKey] = value
    }

    private func trimmedString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
