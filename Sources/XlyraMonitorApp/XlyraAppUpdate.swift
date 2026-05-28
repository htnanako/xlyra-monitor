import Foundation

struct XlyraAppUpdate: Equatable {
    let version: String
    let releaseName: String
    let releasePageURL: URL
    let assetName: String
    let assetDownloadURL: URL
}

enum XlyraAppUpdateError: Error, Equatable {
    case invalidResponse
    case requestFailed(Int)
    case noInstallerAsset
    case downloadFailed

    var message: String {
        switch self {
        case .invalidResponse:
            return "更新信息不可读"
        case .requestFailed(let statusCode):
            return "检查更新失败 HTTP \(statusCode)"
        case .noInstallerAsset:
            return "最新版本没有可下载的 DMG 安装包"
        case .downloadFailed:
            return "更新包下载失败"
        }
    }
}

struct XlyraGitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [XlyraGitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }
}

struct XlyraGitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

enum XlyraVersionComparator {
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateComponents = numericComponents(candidate)
        let currentComponents = numericComponents(current)
        let componentCount = max(candidateComponents.count, currentComponents.count)

        for index in 0..<componentCount {
            let candidateValue = index < candidateComponents.count ? candidateComponents[index] : 0
            let currentValue = index < currentComponents.count ? currentComponents[index] : 0
            if candidateValue > currentValue { return true }
            if candidateValue < currentValue { return false }
        }

        return false
    }

    private static func numericComponents(_ version: String) -> [Int] {
        let cleaned = version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingPrefix("v")

        return cleaned
            .split { character in
                character.isNumber == false
            }
            .compactMap { Int($0) }
    }
}

struct XlyraAppUpdateService {
    private let latestReleaseURL: URL
    private let downloadsDirectoryURL: URL

    init(
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/z4jst/xlyra-monitor/releases/latest")!,
        downloadsDirectoryURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.downloadsDirectoryURL = downloadsDirectoryURL
    }

    func latestUpdate(currentVersion: String) async throws -> XlyraAppUpdate? {
        let release = try await latestRelease()
        guard release.draft == false else { return nil }

        let releaseVersion = release.tagName.trimmingPrefix("v")
        guard XlyraVersionComparator.isVersion(releaseVersion, newerThan: currentVersion) else {
            return nil
        }

        guard let asset = Self.installerAsset(from: release.assets) else {
            throw XlyraAppUpdateError.noInstallerAsset
        }

        return XlyraAppUpdate(
            version: releaseVersion,
            releaseName: release.name ?? release.tagName,
            releasePageURL: release.htmlURL,
            assetName: asset.name,
            assetDownloadURL: asset.browserDownloadURL
        )
    }

    func download(_ update: XlyraAppUpdate) async throws -> URL {
        var request = URLRequest(url: update.assetDownloadURL)
        request.setValue("xLyra Monitor", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw XlyraAppUpdateError.downloadFailed
        }

        try FileManager.default.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true)
        let destinationURL = uniqueDestinationURL(for: update.assetName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    static func installerAsset(from assets: [XlyraGitHubReleaseAsset]) -> XlyraGitHubReleaseAsset? {
        assets.first { asset in
            let name = asset.name.lowercased()
            return name.contains("xlyra") && name.hasSuffix(".dmg")
        } ?? assets.first { asset in
            asset.name.lowercased().hasSuffix(".dmg")
        }
    }

    private func latestRelease() async throws -> XlyraGitHubRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("xLyra Monitor", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XlyraAppUpdateError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw XlyraAppUpdateError.requestFailed(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(XlyraGitHubRelease.self, from: data)
        } catch {
            throw XlyraAppUpdateError.invalidResponse
        }
    }

    private func uniqueDestinationURL(for assetName: String) -> URL {
        let safeName = assetName.isEmpty ? "xLyra-Monitor.dmg" : assetName
        return downloadsDirectoryURL.appendingPathComponent(safeName)
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
