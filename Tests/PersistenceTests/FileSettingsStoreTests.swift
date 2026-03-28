import Core
import Persistence
import Testing
import Foundation

@Test
func saveAndLoadRoundTripsSettings() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = tempDirectory.appendingPathComponent("settings.json")
    let store = FileSettingsStore(url: url)
    let settings = AppSettings(
        rules: [
            "item-1": VisibilityRule(itemID: "item-1", kind: .hiddenInBar, customName: "VPN")
        ],
        hiddenOrder: ["item-1"],
        appearance: .init(itemSpacing: 12, showLabels: true),
        hotkey: .init(keyCode: 11, modifiers: 2048, isEnabled: true),
        preferredLanguage: .japanese,
        launchAtLogin: true,
        completedOnboarding: true
    )

    try store.save(settings)
    let loaded = try store.load()

    #expect(loaded == settings)
}

@Test
func legacyPayloadMigratesIntoCurrentSettings() throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    let url = tempDirectory.appendingPathComponent("settings.json")

    let legacy = """
    {
      "rules": {
        "item-2": {
          "itemID": "item-2",
          "kind": "alwaysHidden",
          "customName": null,
          "interactionMode": "proxyPreferred"
        }
      },
      "itemOrder": ["item-2"],
      "launchAtLogin": true
    }
    """
    try legacy.data(using: .utf8)?.write(to: url)

    let store = FileSettingsStore(url: url)
    let loaded = try store.load()

    #expect(loaded.rules["item-2"]?.kind == .alwaysHidden)
    #expect(loaded.hiddenOrder == ["item-2"])
    #expect(loaded.launchAtLogin)
    #expect(loaded.preferredLanguage == .system)
    #expect(loaded.schemaVersion == 1)
}
