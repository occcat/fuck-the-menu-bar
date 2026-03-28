import AppKit
import Core
import Discovery
import Hotkey
import LayoutEngine
import Localization
import Overlay
import Permissions
import Persistence
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var discoveredItems: [MenuBarItemDescriptor] = []
    @Published private(set) var managedItems: [ManagedMenuBarItem] = []
    @Published private(set) var permissionsSnapshot = PermissionSnapshot()
    @Published private(set) var isRescanning = false
    @Published var settings: AppSettings
    @Published var revealState: RevealState = .collapsed
    @Published var searchText = ""
    @Published var selectedTab = SettingsTab.items
    @Published var lastErrorMessage: String?
    @Published private(set) var preferredLanguage: AppLanguage

    var onOpenSettingsWindow: ((SettingsTab) -> Void)?
    var onCompleteOnboarding: (() -> Void)?
    var onLanguageDidChange: (() -> Void)?

    private let store: FileSettingsStore
    private let permissions: PermissionCoordinator
    private let discovery: SystemMenuBarDiscoveryService
    private let layoutEngine: DefaultMenuBarLayoutEngine
    private let snapshotProvider: MenuBarSnapshotProvider
    private let overlayController: MenuBarOverlayController
    private let interactionRouter: DefaultMenuBarInteractionRouter
    private let hotkeyMonitor: GlobalHotkeyMonitor

    private var statusAnchorFrame: CGRect?
    private var pendingForegroundRescanTab: SettingsTab?

    init(
        store: FileSettingsStore = .init(),
        permissions: PermissionCoordinator = .init(),
        discovery: SystemMenuBarDiscoveryService = .init(),
        layoutEngine: DefaultMenuBarLayoutEngine = .init(),
        snapshotProvider: MenuBarSnapshotProvider = .init(),
        overlayController: MenuBarOverlayController = .init(),
        interactionRouter: DefaultMenuBarInteractionRouter = .init(),
        hotkeyMonitor: GlobalHotkeyMonitor = .init()
    ) {
        self.store = store
        self.permissions = permissions
        self.discovery = discovery
        self.layoutEngine = layoutEngine
        self.snapshotProvider = snapshotProvider
        self.overlayController = overlayController
        self.interactionRouter = interactionRouter
        self.hotkeyMonitor = hotkeyMonitor
        let loadedSettings = (try? store.load()) ?? AppSettings()
        self.settings = loadedSettings
        self.preferredLanguage = loadedSettings.preferredLanguage
        LocalizationController.shared.apply(language: loadedSettings.preferredLanguage)
        if !FileManager.default.fileExists(atPath: store.url.path) {
            try? store.save(loadedSettings)
        }

        discovery.onItemsDidChange = { [weak self] items in
            self?.discoveredItems = items.filter { item in
                item.bundleID != Bundle.main.bundleIdentifier
            }
            self?.rebuildManagedItems()
        }
    }

    func start() {
        refreshPermissions()
        startPermissionRefreshObservers()
        discovery.start()
        applyHotkey()
    }

    func stop() {
        discovery.stop()
        overlayController.hide()
        hotkeyMonitor.unregister()
        NotificationCenter.default.removeObserver(self)
    }

    func setStatusAnchorFrame(_ frame: CGRect?) {
        statusAnchorFrame = frame
        updateOverlay()
    }

    func refreshPermissions() {
        let previous = permissionsSnapshot
        permissionsSnapshot = permissions.currentSnapshot()
        if previous.screenRecordingGranted != permissionsSnapshot.screenRecordingGranted {
            snapshotProvider.invalidateAll()
            rebuildManagedItems(recaptureSnapshots: true)
        }
    }

    func requestAccessibilityPermission() {
        _ = permissions.requestAccessibilityPermission()
        refreshPermissions()
    }

    func requestScreenRecordingPermission() {
        _ = permissions.requestScreenRecordingPermission()
        refreshPermissions()
        snapshotProvider.invalidateAll()
        rebuildManagedItems(recaptureSnapshots: true)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try permissions.setLaunchAtLogin(enabled: enabled)
            settings.launchAtLogin = enabled
            persist()
            refreshPermissions()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func openSettings(tab: SettingsTab = .items) {
        selectedTab = tab
        onOpenSettingsWindow?(tab)
    }

    func rescan() {
        refreshPermissions()
        guard !isRescanning else { return }
        isRescanning = true

        if NSApplication.shared.isActive {
            pendingForegroundRescanTab = selectedTab

            guard NSRunningApplication.current.hide() else {
                pendingForegroundRescanTab = nil
                performControlledRescan(reopenSettingsTab: nil)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.pendingForegroundRescanTab != nil else { return }
                let tab = self.pendingForegroundRescanTab
                self.pendingForegroundRescanTab = nil
                self.performControlledRescan(reopenSettingsTab: tab)
            }
            return
        }

        performControlledRescan(reopenSettingsTab: nil)
    }

    func setAutomaticScanningPaused(_ paused: Bool) {
        if paused {
            discovery.setAutomaticScanningPaused(true)
            return
        }

        if let tab = pendingForegroundRescanTab {
            pendingForegroundRescanTab = nil
            discovery.setAutomaticScanningPaused(false, refreshOnResume: false)
            performControlledRescan(reopenSettingsTab: tab)
            return
        }

        discovery.setAutomaticScanningPaused(false)
    }

    private func performControlledRescan(reopenSettingsTab tab: SettingsTab?) {
        discovery.rescan(forcePublishingResults: true) { [weak self] in
            guard let self else { return }
            self.isRescanning = false
            guard let tab else { return }
            DispatchQueue.main.async {
                self.openSettings(tab: tab)
            }
        }
    }

    func toggleReveal() {
        revealState = revealState == .collapsed ? .expanded : .collapsed
        updateOverlay()
    }

    func collapseReveal() {
        revealState = .collapsed
        updateOverlay()
    }

    func rule(for item: MenuBarItemDescriptor) -> VisibilityRule {
        settings.rules[item.id] ?? VisibilityRule(itemID: item.id, kind: .alwaysVisible)
    }

    func updateRule(itemID: String, kind: VisibilityRuleKind) {
        var rule = settings.rules[itemID] ?? VisibilityRule(itemID: itemID, kind: .alwaysVisible)
        rule.kind = kind
        settings.rules[itemID] = rule
        syncHiddenOrder()
        persist()
        rebuildManagedItems()
    }

    func updateCustomName(itemID: String, customName: String) {
        var rule = settings.rules[itemID] ?? VisibilityRule(itemID: itemID, kind: .alwaysVisible)
        rule.customName = customName.isEmpty ? nil : customName
        settings.rules[itemID] = rule
        persist()
        rebuildManagedItems()
    }

    func updateInteractionMode(itemID: String, mode: ProxyInteractionMode) {
        var rule = settings.rules[itemID] ?? VisibilityRule(itemID: itemID, kind: .alwaysVisible)
        rule.interactionMode = mode
        settings.rules[itemID] = rule
        persist()
        rebuildManagedItems()
    }

    func moveShelfItems(from offsets: IndexSet, to destination: Int) {
        var shelfIDs = managedItems.filter { $0.rule.kind == .hiddenInBar }.map(\.id)
        shelfIDs.move(fromOffsets: offsets, toOffset: destination)
        settings.hiddenOrder = shelfIDs
        persist()
        rebuildManagedItems()
    }

    func moveShelfItem(_ itemID: String, direction: MoveDirection) {
        var shelfIDs = managedItems.filter { $0.rule.kind == .hiddenInBar }.map(\.id)
        guard let index = shelfIDs.firstIndex(of: itemID) else { return }

        let destination: Int
        switch direction {
        case .up:
            guard index > 0 else { return }
            destination = index - 1
        case .down:
            guard index < shelfIDs.count - 1 else { return }
            destination = index + 1
        }

        shelfIDs.swapAt(index, destination)
        settings.hiddenOrder = shelfIDs
        persist()
        rebuildManagedItems()
    }

    func updateAppearance(_ update: (inout AppearanceSettings) -> Void) {
        update(&settings.appearance)
        persist()
        updateOverlay()
    }

    func updateHotkey(_ configuration: HotkeyConfiguration) {
        settings.hotkey = configuration
        persist()
        applyHotkey()
    }

    func updatePreferredLanguage(_ language: AppLanguage) {
        guard settings.preferredLanguage != language else { return }
        settings.preferredLanguage = language
        preferredLanguage = language
        LocalizationController.shared.apply(language: language)
        persist()
        objectWillChange.send()
        onLanguageDidChange?()
    }

    func completeOnboarding() {
        settings.completedOnboarding = true
        persist()
        onCompleteOnboarding?()
    }

    var shouldShowOnboarding: Bool {
        !settings.completedOnboarding
    }

    var filteredManagedItems: [ManagedMenuBarItem] {
        guard !searchText.isEmpty else { return managedItems }
        return managedItems.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.descriptor.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    func activate(_ item: ManagedMenuBarItem) {
        if item.rule.interactionMode != .proxyPreferred {
            overlayController.temporarilyReveal(itemID: item.id)
        }
        interactionRouter.activate(item: item.descriptor, interactionMode: item.rule.interactionMode)
        if item.rule.interactionMode != .proxyPreferred {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.collapseReveal()
            }
        }
    }

    private func rebuildManagedItems(recaptureSnapshots: Bool = false) {
        let itemIDs = Set(discoveredItems.map(\.id))
        snapshotProvider.prune(keeping: itemIDs)
        if recaptureSnapshots {
            snapshotProvider.invalidateAll()
        }

        managedItems = discoveredItems.map { item in
            ManagedMenuBarItem(
                descriptor: item,
                rule: rule(for: item),
                snapshot: snapshotProvider.snapshot(for: item)
            )
        }
        syncHiddenOrder()
        updateOverlay()
    }

    private func syncHiddenOrder() {
        let hiddenIDs = Set(managedItems.filter { $0.rule.kind == .hiddenInBar }.map(\.id))
        settings.hiddenOrder = settings.hiddenOrder.filter { hiddenIDs.contains($0) }
        for item in managedItems where item.rule.kind == .hiddenInBar && !settings.hiddenOrder.contains(item.id) {
            settings.hiddenOrder.append(item.id)
        }
    }

    private func updateOverlay() {
        let layout = layoutEngine.computeLayout(
            input: MenuBarLayoutInput(
                items: managedItems,
                hiddenOrder: settings.hiddenOrder,
                revealState: revealState,
                anchorFrame: statusAnchorFrame,
                appearance: settings.appearance
            )
        )

        overlayController.update(
            on: screenForOverlay(),
            revealState: revealState,
            layout: layout,
            appearance: settings.appearance,
            anchorFrame: statusAnchorFrame,
            onActivate: { [weak self] item in self?.activate(item) },
            onOpenSettings: { [weak self] in self?.openSettings(tab: .items) },
            onMove: { [weak self] offsets, destination in self?.moveShelfItems(from: offsets, to: destination) }
        )
    }

    private func screenForOverlay() -> NSScreen? {
        guard let anchor = statusAnchorFrame else { return NSScreen.main }
        return NSScreen.screens.first(where: { $0.frame.contains(anchor.origin) }) ?? NSScreen.main
    }

    private func applyHotkey() {
        hotkeyMonitor.update(configuration: settings.hotkey) { [weak self] in
            self?.toggleReveal()
        }
    }

    private func startPermissionRefreshObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
            }
        }
    }

    private func persist() {
        do {
            try store.save(settings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case items
    case appearance
    case shortcuts
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .items: L10n.string("settings.tab.items")
        case .appearance: L10n.string("settings.tab.appearance")
        case .shortcuts: L10n.string("settings.tab.shortcuts")
        case .general: L10n.string("settings.tab.general")
        }
    }
}

enum MoveDirection {
    case up
    case down
}
