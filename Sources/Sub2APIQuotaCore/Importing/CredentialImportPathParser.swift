import Foundation

public enum CredentialImportError: Error, Equatable {
    case invalidPath
    case fileNotFound
    case notZipFile
    case unreadableZip
    case missingImportJSON
    case invalidJSON
    case missingAccounts
    case unreadableDirectory
}

public struct CredentialImportPathParser {
    public static func parse(_ text: String) throws -> URL {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else {
            throw CredentialImportError.invalidPath
        }

        if value.count >= 2,
           let first = value.first,
           let last = value.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            value.removeFirst()
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if value.hasPrefix("file://") {
            guard let url = URL(string: value), url.isFileURL else {
                throw CredentialImportError.invalidPath
            }
            return url
        }

        guard value.hasPrefix("/") || value.hasPrefix("~") else {
            throw CredentialImportError.invalidPath
        }

        let expanded = (value as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }
}

