import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("ServiceURLNormalizerTests")
struct ServiceURLNormalizerTests {
    @Test
    func hostOnlyNormalizesServiceRootAndQuotaURL() throws {
        let configuration = try ServiceURLNormalizer.normalize("https://sub2api.example.com")

        #expect(configuration.serviceRoot == URL(string: "https://sub2api.example.com"))
        #expect(configuration.quotaURL == URL(string: "https://sub2api.example.com/api/quota"))
    }

    @Test
    func rootTrailingSlashNormalizesToAbsoluteQuotaPath() throws {
        let configuration = try ServiceURLNormalizer.normalize("https://example.com/")

        #expect(configuration.serviceRoot == URL(string: "https://example.com"))
        #expect(configuration.quotaURL == URL(string: "https://example.com/api/quota"))
    }

    @Test
    func basePathTrailingSlashNormalizesServiceRootAndQuotaURL() throws {
        let configuration = try ServiceURLNormalizer.normalize("https://example.com/sub2api/")

        #expect(configuration.serviceRoot == URL(string: "https://example.com/sub2api"))
        #expect(configuration.quotaURL == URL(string: "https://example.com/sub2api/api/quota"))
    }

    @Test
    func localhostWithPortKeepsPortInQuotaURL() throws {
        let configuration = try ServiceURLNormalizer.normalize("http://127.0.0.1:3000")

        #expect(configuration.serviceRoot == URL(string: "http://127.0.0.1:3000"))
        #expect(configuration.quotaURL == URL(string: "http://127.0.0.1:3000/api/quota"))
    }

    @Test
    func surroundingWhitespaceAndNewlinesAreTrimmedBeforeNormalization() throws {
        let configuration = try ServiceURLNormalizer.normalize(" \nhttps://example.com/sub2api/\n ")

        #expect(configuration.serviceRoot == URL(string: "https://example.com/sub2api"))
        #expect(configuration.quotaURL == URL(string: "https://example.com/sub2api/api/quota"))
    }

    @Test
    func missingSchemeIsRejected() {
        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("example.com")
        }
    }

    @Test
    func queryAndFragmentAreRejected() {
        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://example.com?x=1")
        }

        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://example.com#token")
        }
    }

    @Test
    func credentialsAreRejected() {
        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://user:pass@example.com")
        }
    }

    @Test
    func repeatedSlashesAndDotSegmentsAreRejected() {
        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://example.com//sub2api/")
        }

        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://example.com/sub2api/../admin")
        }

        #expect(throws: ServiceURLValidationError.invalidServiceRoot) {
            try ServiceURLNormalizer.normalize("https://example.com/./sub2api")
        }
    }
}
