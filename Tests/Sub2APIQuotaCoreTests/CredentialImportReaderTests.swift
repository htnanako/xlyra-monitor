import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("CredentialImportReaderTests")
struct CredentialImportReaderTests {
    @Test
    func readsSub2APIImportJSONFromZip() throws {
        let directory = try TemporaryDirectory()
        let zipURL = try directory.makeZip(
            name: "codex_credentials_2026.zip",
            entries: [
                "sub2api-import.json": #"{"exported_at":"2026-05-10T00:00:00Z","proxies":[],"accounts":[{"name":"hidden","credentials":{"token":"secret"}}]}"#
            ]
        )
        let reader = CredentialImportReader()

        let package = try reader.readPackage(at: zipURL)

        #expect(package.fileName == "codex_credentials_2026.zip")
        #expect(package.accountCount == 1)
        #expect(package.proxyCount == 0)
        #expect(package.fileSize > 0)
        #expect(package.payloadData.isEmpty == false)
    }

    @Test
    func readsSingleCodexCredentialJSONFromZip() throws {
        let directory = try TemporaryDirectory()
        let zipURL = try directory.makeZip(
            name: "codex_credentials_single.zip",
            entries: [
                "person@example.com.json": """
                {
                  "type": "codex",
                  "email": "person@example.com",
                  "expired": "2026-05-19T18:45:40+08:00",
                  "account_id": "acct_123",
                  "access_token": "hidden-access",
                  "refresh_token": "hidden-refresh",
                  "id_token": "hidden-id"
                }
                """
            ]
        )
        let reader = CredentialImportReader()

        let package = try reader.readPackage(at: zipURL)

        #expect(package.accountCount == 1)
        let accounts = try #require(package.payloadObject["accounts"] as? [[String: Any]])
        let account = try #require(accounts.first)
        #expect(account["name"] as? String == "person@example.com")
        #expect(account["platform"] as? String == "openai")
        #expect(account["type"] as? String == "codex")
        let credentials = try #require(account["credentials"] as? [String: Any])
        #expect(credentials["email"] as? String == "person@example.com")
        #expect(credentials["refresh_token"] as? String == "hidden-refresh")
        #expect(credentials["chatgpt_account_id"] as? String == "acct_123")
    }

    @Test
    func readsSub2APIImportJSONFileDirectly() throws {
        let directory = try TemporaryDirectory()
        let jsonURL = try directory.makeFile(
            name: "sub2_person@example.com.json",
            contents: #"{"exported_at":"2026-05-10T00:00:00Z","proxies":[],"accounts":[{"name":"person@example.com","credentials":{"token":"secret"}}]}"#
        )
        let reader = CredentialImportReader()

        let package = try reader.readPackage(at: jsonURL)

        #expect(package.fileName == "sub2_person@example.com.json")
        #expect(package.accountCount == 1)
        #expect(package.proxyCount == 0)
        #expect(package.fileSize > 0)
    }

    @Test
    func readsSingleCodexCredentialJSONFileDirectly() throws {
        let directory = try TemporaryDirectory()
        let jsonURL = try directory.makeFile(
            name: "sub2_person@example.com.json",
            contents: """
            {
              "type": "codex",
              "email": "person@example.com",
              "expired": "2026-05-19T18:45:40+08:00",
              "account_id": "acct_123",
              "access_token": "hidden-access",
              "refresh_token": "hidden-refresh",
              "id_token": "hidden-id"
            }
            """
        )
        let reader = CredentialImportReader()

        let package = try reader.readPackage(at: jsonURL)

        #expect(package.accountCount == 1)
        let accounts = try #require(package.payloadObject["accounts"] as? [[String: Any]])
        let account = try #require(accounts.first)
        #expect(account["name"] as? String == "person@example.com")
        let credentials = try #require(account["credentials"] as? [String: Any])
        #expect(credentials["refresh_token"] as? String == "hidden-refresh")
        #expect(credentials["chatgpt_account_id"] as? String == "acct_123")
    }

    @Test
    func throwsWhenZipDoesNotContainImportJSON() throws {
        let directory = try TemporaryDirectory()
        let zipURL = try directory.makeZip(name: "codex_credentials_2026.zip", entries: ["other.json": #"{}"#])
        let reader = CredentialImportReader()

        #expect(throws: CredentialImportError.missingAccounts) {
            _ = try reader.readPackage(at: zipURL)
        }
    }

    @Test
    func throwsWhenImportJSONIsInvalid() throws {
        let directory = try TemporaryDirectory()
        let zipURL = try directory.makeZip(name: "codex_credentials_2026.zip", entries: ["sub2api-import.json": "not-json"])
        let reader = CredentialImportReader()

        #expect(throws: CredentialImportError.invalidJSON) {
            _ = try reader.readPackage(at: zipURL)
        }
    }

    @Test
    func throwsWhenAccountsArrayIsMissing() throws {
        let directory = try TemporaryDirectory()
        let zipURL = try directory.makeZip(name: "codex_credentials_2026.zip", entries: ["sub2api-import.json": #"{"proxies":[]}"#])
        let reader = CredentialImportReader()

        #expect(throws: CredentialImportError.missingAccounts) {
            _ = try reader.readPackage(at: zipURL)
        }
    }
}
