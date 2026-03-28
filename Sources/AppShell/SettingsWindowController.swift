import AppKit
import SwiftUI
import Localization

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private var onboardingWindow: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let rootView = SettingsRootView(model: model)
            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: controller)
            window.title = L10n.string("window.settings.title")
            window.setContentSize(NSSize(width: 880, height: 620))
            window.styleMask.insert(.titled)
            window.styleMask.insert(.closable)
            window.styleMask.insert(.miniaturizable)
            window.styleMask.insert(.resizable)
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
            window.toolbarStyle = .unifiedCompact
            window.backgroundColor = .clear
            window.isOpaque = false
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding(model: AppModel) {
        if onboardingWindow == nil {
            let controller = NSHostingController(rootView: OnboardingRootView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = L10n.string("window.welcome.title")
            window.setContentSize(NSSize(width: 540, height: 420))
            window.styleMask.insert(.titled)
            window.styleMask.insert(.closable)
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            onboardingWindow = window
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func refreshTitles() {
        window?.title = L10n.string("window.settings.title")
        onboardingWindow?.title = L10n.string("window.welcome.title")
    }
}
