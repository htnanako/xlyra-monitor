import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("CredentialImportPathParserTests")
struct CredentialImportPathParserTests {
    @Test
    func parsesPlainAbsolutePath() throws {
        let url = try CredentialImportPathParser.parse("/Users/name/Downloads/codex_credentials_2026.zip")

        #expect(url.path == "/Users/name/Downloads/codex_credentials_2026.zip")
        #expect(url.isFileURL)
    }

    @Test
    func parsesQuotedAndWhitespacePath() throws {
        let url = try CredentialImportPathParser.parse("  \"/Users/name/Downloads/codex_credentials_2026.zip\"  ")

        #expect(url.path == "/Users/name/Downloads/codex_credentials_2026.zip")
    }

    @Test
    func parsesSingleQuotedPath() throws {
        let url = try CredentialImportPathParser.parse("'/Users/name/Downloads/codex_credentials_2026.zip'")

        #expect(url.path == "/Users/name/Downloads/codex_credentials_2026.zip")
    }

    @Test
    func parsesFileURLPath() throws {
        let url = try CredentialImportPathParser.parse("file:///Users/name/Downloads/codex_credentials_2026.zip")

        #expect(url.path == "/Users/name/Downloads/codex_credentials_2026.zip")
    }

    @Test
    func rejectsEmptyInput() {
        #expect(throws: CredentialImportError.invalidPath) {
            _ = try CredentialImportPathParser.parse("   ")
        }
    }
}

