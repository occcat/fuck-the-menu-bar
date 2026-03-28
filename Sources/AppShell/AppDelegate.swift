import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private let statusItemController = StatusItemController()
    private let settingsController = SettingsWindowController()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        bindModel()

        statusItemController.onToggleReveal = { [weak self] in
            self?.refreshStatusAnchor()
            self?.model.toggleReveal()
        }
        statusItemController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        statusItemController.onQuit = {
            NSApp.terminate(nil)
        }
        model.onOpenSettingsWindow = { [weak self] tab in
            guard let self else { return }
            self.model.selectedTab = tab
            self.settingsController.show(model: self.model)
        }
        model.onCompleteOnboarding = { [weak self] in
            guard let self else { return }
            self.settingsController.closeOnboarding()
            self.openSettings(tab: .items)
        }
        model.onLanguageDidChange = { [weak self] in
            guard let self else { return }
            let hiddenCount = self.model.managedItems.filter { $0.rule.kind == .hiddenInBar }.count
            self.statusItemController.reloadLocalization(revealState: self.model.revealState, hiddenCount: hiddenCount)
            self.settingsController.refreshTitles()
        }

        refreshStatusAnchor()
        model.start()

        if model.shouldShowOnboarding {
            settingsController.showOnboarding(model: model)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsController.show(model: model)
        return true
    }

    func openSettings(tab: SettingsTab = .items) {
        model.openSettings(tab: tab)
        settingsController.show(model: model)
    }

    private func refreshStatusItem() {
        let hiddenCount = model.managedItems.filter { $0.rule.kind == .hiddenInBar }.count
        statusItemController.update(revealState: model.revealState, hiddenCount: hiddenCount)
    }

    private func refreshStatusAnchor() {
        model.setStatusAnchorFrame(statusItemController.anchorFrame)
    }

    private func bindModel() {
        model.$managedItems
            .combineLatest(model.$revealState)
            .sink { [weak self] _, _ in
                self?.refreshStatusAnchor()
                self?.refreshStatusItem()
            }
            .store(in: &cancellables)
    }
}

@main
struct MenuBarShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
