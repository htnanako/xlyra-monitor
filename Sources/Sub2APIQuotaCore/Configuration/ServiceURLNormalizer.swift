import Foundation

public struct ServiceConfiguration: Equatable {
    public let serviceRoot: URL
    public let quotaURL: URL

    public init(serviceRoot: URL, quotaURL: URL) {
        self.serviceRoot = serviceRoot
        self.quotaURL = quotaURL
    }
}

public enum ServiceURLValidationError: Error, Equatable {
    case invalidServiceRoot
}

public enum ServiceURLNormalizer {
    public static func normalize(_ rawValue: String) throws -> ServiceConfiguration {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = URLComponents(string: trimmedValue),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            host.isEmpty == false,
            components.user == nil,
            components.password == nil,
            components.query == nil,
            components.fragment == nil,
            isSupportedPath(components.path)
        else {
            throw ServiceURLValidationError.invalidServiceRoot
        }

        var normalizedComponents = components
        let normalizedPath = normalizeServiceRootPath(components.path)
        normalizedComponents.scheme = scheme
        normalizedComponents.host = host
        normalizedComponents.query = nil
        normalizedComponents.fragment = nil
        normalizedComponents.path = normalizedPath

        guard let serviceRoot = normalizedComponents.url else {
            throw ServiceURLValidationError.invalidServiceRoot
        }

        var quotaComponents = normalizedComponents
        let basePath = normalizedPath.isEmpty ? "/" : normalizedPath
        quotaComponents.path = (basePath as NSString).appendingPathComponent("api/quota")

        guard let quotaURL = quotaComponents.url else {
            throw ServiceURLValidationError.invalidServiceRoot
        }

        return ServiceConfiguration(serviceRoot: serviceRoot, quotaURL: quotaURL)
    }

    private static func normalizeServiceRootPath(_ path: String) -> String {
        guard path.isEmpty == false, path != "/" else {
            return ""
        }

        var normalizedPath = path
        while normalizedPath.count > 1, normalizedPath.hasSuffix("/") {
            normalizedPath.removeLast()
        }
        return normalizedPath
    }

    private static func isSupportedPath(_ path: String) -> Bool {
        guard path.isEmpty == false, path != "/" else {
            return true
        }

        let trimmedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        let segments = trimmedPath.split(separator: "/", omittingEmptySubsequences: false)
        for segment in segments.dropFirst() {
            if segment.isEmpty || segment == "." || segment == ".." {
                return false
            }
        }

        return true
    }
}
