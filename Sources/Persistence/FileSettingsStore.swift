import Core
import Foundation

private struct LegacyAppSettingsV0: Codable {
    var rules: [String: VisibilityRule]
    var itemOrder: [String]
    var launchAtLogin: Bool?
}

public final class FileSettingsStore: SettingsStoreProtocol {
    public let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> AppSettings {
        let loadURL = resolvedLoadURL()
        guard FileManager.default.fileExists(atPath: loadURL.path) else {
            return AppSettings()
        }

        let data = try Data(contentsOf: loadURL)
        if let settings = try? decoder.decode(AppSettings.self, from: data) {
            return settings
        }

        let legacy = try decoder.decode(LegacyAppSettingsV0.self, from: data)
        return AppSettings(
            rules: legacy.rules,
            hiddenOrder: legacy.itemOrder,
            launchAtLogin: legacy.launchAtLogin ?? false
        )
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }

    public static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("fuck-the-menu-bar", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    private func resolvedLoadURL() -> URL {
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let legacy = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MenuBarShelf", isDirectory: true)
            .appendingPathComponent("settings.json")
        return legacy ?? url
    }
}
