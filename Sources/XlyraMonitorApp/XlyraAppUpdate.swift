import AppKit
import Combine
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
    case installFailed

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
        case .installFailed:
            return "更新安装失败"
        }
    }
}

enum XlyraUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(XlyraAppUpdate)
    case downloading(XlyraAppUpdate)
    case installing(XlyraAppUpdate)
    case failed(String)

    var availableUpdate: XlyraAppUpdate? {
        switch self {
        case .available(let update), .downloading(let update), .installing(let update):
            return update
        default:
            return nil
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
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

    func launchInstaller(
        for downloadedDMGURL: URL,
        targetAppURL: URL = Bundle.main.bundleURL,
        currentProcessID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlyra-monitor-update-\(UUID().uuidString).sh")
        let mountURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlyra-monitor-update-\(UUID().uuidString)")
        let appName = targetAppURL.lastPathComponent
        let temporaryTargetURL = targetAppURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(appName).updating")

        let script = """
        #!/bin/sh
        set -eu

        DMG=\(Self.shellQuote(downloadedDMGURL.path))
        TARGET=\(Self.shellQuote(targetAppURL.path))
        TMP_TARGET=\(Self.shellQuote(temporaryTargetURL.path))
        MOUNT=\(Self.shellQuote(mountURL.path))
        APP_NAME=\(Self.shellQuote(appName))
        OLD_PID=\(currentProcessID)

        cleanup() {
          /usr/bin/hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
          /bin/rm -rf "$MOUNT" "$TMP_TARGET" "$0"
        }
        trap cleanup EXIT

        while /bin/kill -0 "$OLD_PID" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done

        /bin/mkdir -p "$MOUNT"
        /usr/bin/hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT" >/dev/null
        SOURCE="$MOUNT/$APP_NAME"
        if [ ! -d "$SOURCE" ]; then
          SOURCE="$(/usr/bin/find "$MOUNT" -maxdepth 2 -name '*.app' -print -quit)"
        fi
        if [ -z "${SOURCE:-}" ] || [ ! -d "$SOURCE" ]; then
          exit 1
        fi

        /bin/rm -rf "$TMP_TARGET"
        /usr/bin/ditto "$SOURCE" "$TMP_TARGET"
        /bin/rm -rf "$TARGET"
        /bin/mv "$TMP_TARGET" "$TARGET"
        /usr/bin/open "$TARGET"
        """

        do {
            try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [scriptURL.path]
            try process.run()
        } catch {
            throw XlyraAppUpdateError.installFailed
        }
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

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

@MainActor
final class XlyraAppUpdateCoordinator: ObservableObject {
    static let automaticCheckInterval: TimeInterval = 300

    @Published private(set) var updateStatus: XlyraUpdateStatus = .idle

    private let updateService: XlyraAppUpdateService
    private var automaticCheckTask: Task<Void, Never>?

    init(updateService: XlyraAppUpdateService = XlyraAppUpdateService()) {
        self.updateService = updateService
    }

    deinit {
        automaticCheckTask?.cancel()
    }

    func startAutomaticChecks() {
        guard automaticCheckTask == nil else { return }
        automaticCheckTask = Task { [weak self] in
            await self?.checkForUpdate(silent: true)

            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: UInt64(Self.automaticCheckInterval * 1_000_000_000))
                guard Task.isCancelled == false else { return }
                await self?.checkForUpdate(silent: true)
            }
        }
    }

    func checkForUpdate(silent: Bool = false) async {
        guard updateStatus.isBusy == false else { return }
        if silent == false {
            updateStatus = .checking
        }

        do {
            if let update = try await updateService.latestUpdate(currentVersion: XlyraMonitorAppMetadata.appVersion) {
                updateStatus = .available(update)
            } else if silent == false || updateStatus.availableUpdate == nil {
                updateStatus = .upToDate
            }
        } catch let error as XlyraAppUpdateError {
            if silent == false {
                updateStatus = .failed(error.message)
            }
        } catch {
            if silent == false {
                updateStatus = .failed("检查更新失败")
            }
        }
    }

    func installAvailableUpdate() {
        guard let update = updateStatus.availableUpdate, updateStatus.isBusy == false else {
            return
        }

        updateStatus = .downloading(update)
        Task { [updateService] in
            do {
                let downloadedURL = try await updateService.download(update)
                updateStatus = .installing(update)
                try updateService.launchInstaller(for: downloadedURL)
                NSApplication.shared.terminate(nil)
            } catch let error as XlyraAppUpdateError {
                updateStatus = .failed(error.message)
            } catch {
                updateStatus = .failed("更新安装失败")
            }
        }
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
