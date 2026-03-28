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
            guard let self else { return }
            self.discoveredItems = items.filter { !self.isCurrentAppItem($0) }
            self.rebuildManagedItems()
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

    func activate(_ item: ManagedMenuBarItem, button: MenuBarClickButton = .left) {
        // AXPress works without mouse coordinates — try it before collapsing the overlay
        if button == .left && item.rule.interactionMode == .proxyPreferred {
            if interactionRouter.tryAccessibilityPress(item: item.descriptor) {
                collapseReveal()
                return
            }
        }

        // Real clicks post CGEvents at screen coordinates — hide overlay first to avoid interception
        overlayController.hide()
        revealState = .collapsed

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.interactionRouter.activate(
                item: item.descriptor,
                interactionMode: item.rule.interactionMode,
                button: button
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.updateOverlay()
            }
        }
    }

    private func rebuildManagedItems(recaptureSnapshots: Bool = false) {
        let itemIDs = Set(discoveredItems.map(\.id))
        snapshotProvider.prune(keeping: itemIDs)
        if recaptureSnapshots {
            snapshotProvider.invalidateAll()
        }

        let rawManagedItems = discoveredItems.map { item in
            ManagedMenuBarItem(
                descriptor: item,
                rule: rule(for: item),
                snapshot: snapshotProvider.snapshot(for: item)
            )
        }
        managedItems = deduplicateManagedItems(rawManagedItems)
        syncHiddenOrder()
        updateOverlay()
    }

    private func deduplicateManagedItems(_ items: [ManagedMenuBarItem]) -> [ManagedMenuBarItem] {
        var bestItemByKey: [String: ManagedMenuBarItem] = [:]

        for item in items {
            let appName = resolvedAppName(for: item.descriptor)
            let dedupeKey = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let candidate = item.withDisplayName(appName)

            guard let existing = bestItemByKey[dedupeKey] else {
                bestItemByKey[dedupeKey] = candidate
                continue
            }

            if preferredManagedItem(candidate, over: existing) {
                bestItemByKey[dedupeKey] = candidate
            }
        }

        return bestItemByKey.values.sorted {
            if $0.descriptor.bounds.minX == $1.descriptor.bounds.minX {
                return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
            }
            return $0.descriptor.bounds.minX < $1.descriptor.bounds.minX
        }
    }

    private func preferredManagedItem(_ candidate: ManagedMenuBarItem, over existing: ManagedMenuBarItem) -> Bool {
        let candidateScore = dedupeScore(for: candidate)
        let existingScore = dedupeScore(for: existing)
        if candidateScore != existingScore {
            return candidateScore > existingScore
        }

        if candidate.descriptor.bounds.minX != existing.descriptor.bounds.minX {
            return candidate.descriptor.bounds.minX < existing.descriptor.bounds.minX
        }

        return candidate.displayName.localizedCompare(existing.displayName) == .orderedAscending
    }

    private func dedupeScore(for item: ManagedMenuBarItem) -> Int {
        var score = 0

        if settings.rules[item.id] != nil {
            score += 100
        }
        if item.descriptor.capabilities.canPerformPress {
            score += 20
        }
        if item.descriptor.source == .accessibility {
            score += 10
        }
        if item.rule.kind == .hiddenInBar {
            score += 4
        } else if item.rule.kind == .alwaysHidden {
            score += 2
        }

        return score
    }

    private func resolvedAppName(for item: MenuBarItemDescriptor) -> String {
        if let runningApp = NSRunningApplication(processIdentifier: item.ownerPID),
           let localizedName = runningApp.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localizedName.isEmpty {
            return localizedName
        }

        if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID),
           let bundle = Bundle(url: applicationURL) {
            let displayName =
                (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                (bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ??
                applicationURL.deletingPathExtension().lastPathComponent
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let fallback = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? item.bundleID : fallback
    }

    private func isCurrentAppItem(_ item: MenuBarItemDescriptor) -> Bool {
        if item.ownerPID == ProcessInfo.processInfo.processIdentifier {
            return true
        }

        let currentBundleIdentifier = normalizedAppIdentity(Bundle.main.bundleIdentifier)
        let itemBundleIdentifier = normalizedAppIdentity(item.bundleID)
        if let currentBundleIdentifier, itemBundleIdentifier == currentBundleIdentifier {
            return true
        }

        let currentDisplayNames = Set([
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String,
            ProcessInfo.processInfo.processName,
            "去他妈的菜单栏",
            "fuck-the-menu-bar",
        ].compactMap(normalizedAppIdentity))

        let candidateNames = Set([
            item.displayName,
            resolvedAppName(for: item),
            item.bundleID,
        ].compactMap(normalizedAppIdentity))

        return !currentDisplayNames.isDisjoint(with: candidateNames)
    }

    private func normalizedAppIdentity(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
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
            onActivate: { [weak self] item, button in self?.activate(item, button: button) },
            onRequestCollapse: { [weak self] in self?.collapseReveal() }
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
