import AppKit
import Foundation

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var items: [NSStatusItem] = []
    private var timer: Timer?
    private let dynamicItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let wifi = makeItem(symbol: "wifi", title: nil)
        let cloud = makeItem(symbol: "icloud", title: nil)
        let sync = makeItem(symbol: "arrow.triangle.2.circlepath", title: "Sync")
        let build = makeItem(symbol: "hammer", title: "Build")
        items = [wifi, cloud, sync, build]

        dynamicItem.button?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Dynamic")
        dynamicItem.button?.title = "Idle"
        dynamicItem.button?.toolTip = "Dynamic width fixture"

        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dynamicItem.button?.title = Bool.random() ? "Working…" : "Idle"
            }
        }
    }

    @MainActor
    private func makeItem(symbol: String, title: String?) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title ?? symbol)
        item.button?.title = title ?? ""
        return item
    }
}

let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.run()
