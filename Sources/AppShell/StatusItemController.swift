import AppKit
import Core
import Localization
import Symbols

@MainActor
final class StatusItemController: NSObject {
    var onToggleReveal: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    // The symbol is drawn by an embedded image view (not `button.image`) so that state changes
    // can use an SF Symbols content transition. The button therefore needs a fixed length.
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let symbolView = StatusSymbolImageView()
    private var displayedRevealState: RevealState?

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
        setSymbol(for: revealState)
        button.setAccessibilityLabel(L10n.string("app.name"))
        button.toolTip = hiddenCount > 0 ? L10n.format("status.tooltip.hidden_count", hiddenCount) : L10n.string("status.tooltip")
    }

    func reloadLocalization(revealState: RevealState, hiddenCount: Int) {
        configureMenu()
        update(revealState: revealState, hiddenCount: hiddenCount)
    }

    /// Swaps the symbol only when the reveal state actually changes (`update` is also called for
    /// every item-list change). The first image and "Reduce Motion" use a plain swap.
    private func setSymbol(for revealState: RevealState) {
        guard revealState != displayedRevealState else { return }
        let isInitial = displayedRevealState == nil
        displayedRevealState = revealState

        let name = revealState == .expanded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        // Template image: the status bar tints it for the current menu bar appearance,
        // including the transparent menu bar on macOS 26.
        image.isTemplate = true

        if isInitial || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            symbolView.image = image
        } else {
            symbolView.setSymbolImage(image, contentTransition: .replace.downUp, options: .default)
        }
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
        button.image = nil

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.setAccessibilityElement(false)
        button.addSubview(symbolView)
        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

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

/// Lets clicks fall through to the status bar button underneath.
private final class StatusSymbolImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
