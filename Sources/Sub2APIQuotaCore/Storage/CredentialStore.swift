import Foundation
import Security

public struct StoredConfiguration: Equatable {
    public let serviceRoot: URL
    public let quotaURL: URL
    public let email: String
    public let apiKey: String
    public let inspectedAPIKey: String?
    public let threshold: Decimal

    public init(
        serviceRoot: URL,
        quotaURL: URL,
        email: String,
        apiKey: String,
        inspectedAPIKey: String? = nil,
        threshold: Decimal
    ) {
        self.serviceRoot = serviceRoot
        self.quotaURL = quotaURL
        self.email = email
        self.apiKey = apiKey
        self.inspectedAPIKey = inspectedAPIKey
        self.threshold = threshold
    }

    public var loginCredential: String {
        "\(email)\n\(apiKey)"
    }
}

public protocol SecretStore {
    func readAPIKey() throws -> String?
    func writeAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

public protocol SettingsStore: AnyObject {
    var serviceURLString: String? { get set }
    var emailString: String? { get set }
    var thresholdString: String? { get set }
    var apiKeyString: String? { get set }
    var inspectedAPIKeyString: String? { get set }
    var modelCheckBaseURLString: String? { get set }
    var modelCheckAPIKeyString: String? { get set }
    var modelCheckModelString: String? { get set }
}

public protocol CredentialLoading {
    func load() throws -> StoredConfiguration?
}

public protocol CredentialSaving {
    func save(serviceURL: String, email: String, apiKey: String, threshold: Decimal) throws
    func update(serviceURL: String, email: String, apiKey: String?, inspectedAPIKey: String?, threshold: Decimal) throws
}

public protocol ModelCheckConfigurationLoading {
    func loadModelCheckConfiguration() throws -> ModelCheckConfiguration?
}

public protocol ModelCheckConfigurationSaving {
    func saveModelCheckConfiguration(baseURL: String, apiKey: String, model: String) throws
}

public protocol ModelCheckPreferenceLoading {
    func loadModelCheckModel() throws -> String?
}

public protocol ModelCheckPreferenceSaving {
    func saveModelCheckModel(_ model: String) throws
}

public final class CredentialStore: CredentialLoading, CredentialSaving, ModelCheckConfigurationLoading, ModelCheckConfigurationSaving, ModelCheckPreferenceLoading, ModelCheckPreferenceSaving {
    private let settings: SettingsStore
    private let secrets: SecretStore

    public init(settings: SettingsStore, keychain: SecretStore) {
        self.settings = settings
        self.secrets = keychain
    }

    public init(settings: SettingsStore, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
    }

    public func load() throws -> StoredConfiguration? {
        let apiKey: String?
        do {
            apiKey = try secrets.readAPIKey()
        } catch {
            throw QuotaErrorKind.credentialReadFailed
        }

        guard let serviceURLString = settings.serviceURLString,
              serviceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        guard let email = settings.emailString?.trimmingCharacters(in: .whitespacesAndNewlines),
              email.isEmpty == false else {
            return nil
        }

        guard let apiKey, apiKey.isEmpty == false else {
            return nil
        }

        let serviceConfiguration = try ServiceURLNormalizer.normalize(serviceURLString)
        return StoredConfiguration(
            serviceRoot: serviceConfiguration.serviceRoot,
            quotaURL: serviceConfiguration.quotaURL,
            email: email,
            apiKey: apiKey,
            inspectedAPIKey: loadInspectedAPIKey(),
            threshold: loadThreshold()
        )
    }

    public func save(serviceURL: String, email: String, apiKey: String, threshold: Decimal) throws {
        try update(serviceURL: serviceURL, email: email, apiKey: apiKey, inspectedAPIKey: nil, threshold: threshold)
    }

    public func update(
        serviceURL: String,
        email: String,
        apiKey: String?,
        inspectedAPIKey: String?,
        threshold: Decimal
    ) throws {
        let serviceConfiguration = try ServiceURLNormalizer.normalize(serviceURL)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let thresholdString = NSDecimalNumber(decimal: threshold).stringValue

        if let apiKey {
            do {
                try secrets.writeAPIKey(apiKey)
            } catch {
                throw QuotaErrorKind.credentialWriteFailed
            }
        }

        settings.serviceURLString = serviceConfiguration.serviceRoot.absoluteString
        settings.emailString = normalizedEmail
        settings.thresholdString = thresholdString

        if let inspectedAPIKey {
            let normalizedInspectedAPIKey = inspectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.inspectedAPIKeyString = normalizedInspectedAPIKey.isEmpty ? nil : normalizedInspectedAPIKey
        }
    }

    public func delete() throws {
        do {
            try secrets.deleteAPIKey()
        } catch {
            throw QuotaErrorKind.credentialWriteFailed
        }

        settings.serviceURLString = nil
        settings.emailString = nil
        settings.thresholdString = nil
        settings.inspectedAPIKeyString = nil
    }

    public func loadModelCheckConfiguration() throws -> ModelCheckConfiguration? {
        guard let baseURLString = settings.modelCheckBaseURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let apiKey = settings.modelCheckAPIKeyString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let model = settings.modelCheckModelString?.trimmingCharacters(in: .whitespacesAndNewlines),
              baseURLString.isEmpty == false,
              apiKey.isEmpty == false,
              model.isEmpty == false,
              let baseURL = URL(string: baseURLString),
              ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""),
              baseURL.host?.isEmpty == false else {
            return nil
        }

        return ModelCheckConfiguration(baseURL: baseURL, apiKey: apiKey, model: model)
    }

    public func saveModelCheckConfiguration(baseURL: String, apiKey: String, model: String) throws {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedBaseURL),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false,
              trimmedAPIKey.isEmpty == false,
              trimmedModel.isEmpty == false else {
            throw ModelCheckError.invalidConfiguration
        }

        settings.modelCheckBaseURLString = trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        settings.modelCheckAPIKeyString = trimmedAPIKey
        settings.modelCheckModelString = trimmedModel
    }

    public func loadModelCheckModel() throws -> String? {
        guard let model = settings.modelCheckModelString?.trimmingCharacters(in: .whitespacesAndNewlines),
              model.isEmpty == false else {
            return nil
        }

        return model
    }

    public func saveModelCheckModel(_ model: String) throws {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedModel.isEmpty == false else {
            throw ModelCheckError.invalidConfiguration
        }

        settings.modelCheckModelString = trimmedModel
    }

    private func loadThreshold() -> Decimal {
        guard let thresholdString = settings.thresholdString,
              let threshold = try? ThresholdValidator.parse(thresholdString) else {
            return Decimal(10)
        }

        return threshold
    }

    private func loadInspectedAPIKey() -> String? {
        guard let inspectedAPIKey = settings.inspectedAPIKeyString?.trimmingCharacters(in: .whitespacesAndNewlines),
              inspectedAPIKey.isEmpty == false else {
            return nil
        }

        return inspectedAPIKey
    }
}

public final class UserDefaultsSettingsStore: SettingsStore {
    private let userDefaults: UserDefaults
    private let serviceURLKey: String
    private let emailKey: String
    private let thresholdKey: String
    private let apiKeyKey: String
    private let inspectedAPIKeyKey: String
    private let modelCheckBaseURLKey: String
    private let modelCheckAPIKeyKey: String
    private let modelCheckModelKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        serviceURLKey: String = "sub2api.serviceURL",
        emailKey: String = "sub2api.email",
        thresholdKey: String = "sub2api.threshold",
        apiKeyKey: String = "sub2api.apiKey",
        inspectedAPIKeyKey: String = "sub2api.inspectedAPIKey",
        modelCheckBaseURLKey: String = "sub2api.modelCheckBaseURL",
        modelCheckAPIKeyKey: String = "sub2api.modelCheckAPIKey",
        modelCheckModelKey: String = "sub2api.modelCheckModel"
    ) {
        self.userDefaults = userDefaults
        self.serviceURLKey = serviceURLKey
        self.emailKey = emailKey
        self.thresholdKey = thresholdKey
        self.apiKeyKey = apiKeyKey
        self.inspectedAPIKeyKey = inspectedAPIKeyKey
        self.modelCheckBaseURLKey = modelCheckBaseURLKey
        self.modelCheckAPIKeyKey = modelCheckAPIKeyKey
        self.modelCheckModelKey = modelCheckModelKey
    }

    public var serviceURLString: String? {
        get { userDefaults.string(forKey: serviceURLKey) }
        set { set(newValue, forKey: serviceURLKey) }
    }

    public var emailString: String? {
        get { userDefaults.string(forKey: emailKey) }
        set { set(newValue, forKey: emailKey) }
    }

    public var thresholdString: String? {
        get { userDefaults.string(forKey: thresholdKey) }
        set { set(newValue, forKey: thresholdKey) }
    }

    public var apiKeyString: String? {
        get { userDefaults.string(forKey: apiKeyKey) }
        set { set(newValue, forKey: apiKeyKey) }
    }

    public var inspectedAPIKeyString: String? {
        get { userDefaults.string(forKey: inspectedAPIKeyKey) }
        set { set(newValue, forKey: inspectedAPIKeyKey) }
    }

    public var modelCheckBaseURLString: String? {
        get { userDefaults.string(forKey: modelCheckBaseURLKey) }
        set { set(newValue, forKey: modelCheckBaseURLKey) }
    }

    public var modelCheckAPIKeyString: String? {
        get { userDefaults.string(forKey: modelCheckAPIKeyKey) }
        set { set(newValue, forKey: modelCheckAPIKeyKey) }
    }

    public var modelCheckModelString: String? {
        get { userDefaults.string(forKey: modelCheckModelKey) }
        set { set(newValue, forKey: modelCheckModelKey) }
    }

    private func set(_ value: String?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}

public final class UserDefaultsSecretStore: SecretStore {
    private let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func readAPIKey() throws -> String? {
        settings.apiKeyString
    }

    public func writeAPIKey(_ apiKey: String) throws {
        settings.apiKeyString = apiKey
    }

    public func deleteAPIKey() throws {
        settings.apiKeyString = nil
    }
}

public struct SecurityKeychainClient: SecretStore {
    private let service: String
    private let account: String

    public init(
        service: String = "Sub2APIQuota",
        account: String = "apiKey"
    ) {
        self.service = service
        self.account = account
    }

    public func readAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw QuotaErrorKind.credentialReadFailed
        }

        return apiKey
    }

    public func writeAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw QuotaErrorKind.credentialWriteFailed
        }

        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw QuotaErrorKind.credentialWriteFailed
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw QuotaErrorKind.credentialWriteFailed
        }
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw QuotaErrorKind.credentialWriteFailed
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
