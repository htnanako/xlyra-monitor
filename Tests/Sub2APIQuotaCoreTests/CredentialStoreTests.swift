import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("CredentialStoreTests")
struct CredentialStoreTests {
    @Test
    func loadReturnsNilWhenServiceURLIsMissing() throws {
        let keychain = FakeKeychainClient()
        try keychain.writeAPIKey("secret")
        let store = CredentialStore(settings: InMemorySettingsStore(), keychain: keychain)

        #expect(try store.load() == nil)
    }

    @Test
    func loadReturnsNilWhenAPIKeyIsMissing() throws {
        let settings = InMemorySettingsStore()
        settings.serviceURLString = "https://example.com"
        settings.emailString = "admin@example.com"
        settings.thresholdString = "10"
        let store = CredentialStore(settings: settings, keychain: FakeKeychainClient())

        #expect(try store.load() == nil)
    }

    @Test
    func loadReturnsNilWhenEmailIsMissing() throws {
        let settings = InMemorySettingsStore()
        settings.serviceURLString = "https://example.com"
        settings.thresholdString = "10"
        let keychain = FakeKeychainClient()
        try keychain.writeAPIKey("secret")
        let store = CredentialStore(settings: settings, keychain: keychain)

        #expect(try store.load() == nil)
    }

    @Test
    func saveThenLoadRoundTrip() throws {
        let store = CredentialStore(settings: InMemorySettingsStore(), keychain: FakeKeychainClient())

        try store.save(serviceURL: "https://example.com/sub2api/", email: "admin@example.com", apiKey: "secret", threshold: Decimal(10))

        let loaded = try #require(try store.load())
        #expect(loaded.serviceRoot.absoluteString == "https://example.com/sub2api")
        #expect(loaded.quotaURL.absoluteString == "https://example.com/sub2api/api/quota")
        #expect(loaded.email == "admin@example.com")
        #expect(loaded.apiKey == "secret")
        #expect(loaded.loginCredential == "admin@example.com\nsecret")
        #expect(loaded.threshold == Decimal(10))
    }

    @Test
    func saveFailureKeepsOldConfiguration() throws {
        let keychain = FakeKeychainClient()
        let settings = InMemorySettingsStore()
        let store = CredentialStore(settings: settings, keychain: keychain)
        try store.save(serviceURL: "https://old.example.com", email: "old@example.com", apiKey: "old", threshold: Decimal(10))

        keychain.writeError = QuotaErrorKind.credentialWriteFailed
        #expect(throws: QuotaErrorKind.credentialWriteFailed) {
            try store.save(serviceURL: "https://new.example.com", email: "new@example.com", apiKey: "new", threshold: Decimal(2))
        }

        #expect(try store.load()?.serviceRoot.absoluteString == "https://old.example.com")
        #expect(try store.load()?.email == "old@example.com")
        #expect(try store.load()?.apiKey == "old")
    }

    @Test
    func updateCanKeepExistingAPIKey() throws {
        let keychain = FakeKeychainClient()
        let settings = InMemorySettingsStore()
        let store = CredentialStore(settings: settings, keychain: keychain)
        try store.save(serviceURL: "https://old.example.com", email: "old@example.com", apiKey: "old", threshold: Decimal(10))

        try store.update(
            serviceURL: "https://new.example.com",
            email: "new@example.com",
            apiKey: nil,
            inspectedAPIKey: nil,
            threshold: Decimal(2)
        )

        let loaded = try #require(try store.load())
        #expect(loaded.serviceRoot.absoluteString == "https://new.example.com")
        #expect(loaded.email == "new@example.com")
        #expect(loaded.apiKey == "old")
        #expect(loaded.threshold == Decimal(2))
    }

    @Test
    func readFailureRethrowsCredentialReadFailed() {
        let keychain = FakeKeychainClient()
        keychain.readError = QuotaErrorKind.credentialReadFailed
        let store = CredentialStore(settings: InMemorySettingsStore(), keychain: keychain)

        #expect(throws: QuotaErrorKind.credentialReadFailed) {
            _ = try store.load()
        }
    }

    @Test
    func missingOrInvalidThresholdFallsBackToDefaultTen() throws {
        let keychain = FakeKeychainClient()
        let settings = InMemorySettingsStore()
        settings.serviceURLString = "https://example.com"
        settings.emailString = "admin@example.com"
        try keychain.writeAPIKey("secret")
        let store = CredentialStore(settings: settings, keychain: keychain)

        settings.thresholdString = nil
        #expect(try store.load()?.threshold == Decimal(10))

        settings.thresholdString = ""
        #expect(try store.load()?.threshold == Decimal(10))

        settings.thresholdString = "bad"
        #expect(try store.load()?.threshold == Decimal(10))
    }

    @Test
    func deleteSuccessClearsSettingsAndKeychain() throws {
        let keychain = FakeKeychainClient()
        let settings = InMemorySettingsStore()
        let store = CredentialStore(settings: settings, keychain: keychain)
        try store.save(serviceURL: "https://example.com", email: "admin@example.com", apiKey: "secret", threshold: Decimal(10))

        try store.delete()

        #expect(try store.load() == nil)
        #expect(settings.serviceURLString == nil)
        #expect(settings.emailString == nil)
        #expect(settings.thresholdString == nil)
        #expect(try keychain.readAPIKey() == nil)
    }

    @Test
    func deleteFailureKeepsConfiguration() throws {
        let keychain = FakeKeychainClient()
        let settings = InMemorySettingsStore()
        let store = CredentialStore(settings: settings, keychain: keychain)
        try store.save(serviceURL: "https://example.com", email: "admin@example.com", apiKey: "secret", threshold: Decimal(10))

        keychain.deleteError = QuotaErrorKind.credentialWriteFailed
        #expect(throws: QuotaErrorKind.credentialWriteFailed) {
            try store.delete()
        }

        #expect(try store.load()?.serviceRoot.absoluteString == "https://example.com")
        #expect(try store.load()?.apiKey == "secret")
    }
}

final class InMemorySettingsStore: SettingsStore {
    var serviceURLString: String?
    var emailString: String?
    var thresholdString: String?
    var apiKeyString: String?
    var inspectedAPIKeyString: String?
    var modelCheckBaseURLString: String?
    var modelCheckAPIKeyString: String?
    var modelCheckModelString: String?
}

final class FakeKeychainClient: SecretStore {
    var apiKey: String?
    var readError: Error?
    var writeError: Error?
    var deleteError: Error?

    func readAPIKey() throws -> String? {
        if let readError {
            throw readError
        }

        return apiKey
    }

    func writeAPIKey(_ apiKey: String) throws {
        if let writeError {
            throw writeError
        }

        self.apiKey = apiKey
    }

    func deleteAPIKey() throws {
        if let deleteError {
            throw deleteError
        }

        apiKey = nil
    }
}
