import AppKit
import Core
import Localization

@MainActor
final class StatusItemController: NSObject {
    var onToggleReveal: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    override init() {
        super.init()
        configureButton()
        configureMenu()
    }

    var anchorFrame: CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func update(revealState: RevealState, hiddenCount: Int) {
        guard let button = statusItem.button else { return }
        let imageName = revealState == .expanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: L10n.string("app.name"))
        button.image?.isTemplate = true
        button.toolTip = hiddenCount > 0 ? L10n.format("status.tooltip.hidden_count", hiddenCount) : L10n.string("status.tooltip")
    }

    func reloadLocalization(revealState: RevealState, hiddenCount: Int) {
        configureMenu()
        update(revealState: revealState, hiddenCount: hiddenCount)
    }

    @objc private func handleButtonPress(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onToggleReveal?()
            return
        }

        switch event.type {
        case .rightMouseUp:
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        default:
            onToggleReveal?()
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleButtonPress(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        update(revealState: .collapsed, hiddenCount: 0)
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.addItem(withTitle: L10n.string("action.open_settings"), action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.string("action.quit"), action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
