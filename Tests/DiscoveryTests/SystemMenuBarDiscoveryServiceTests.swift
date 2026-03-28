import Core
@testable import Discovery
import Testing
import CoreGraphics

@Test
func activeAppKeepsBackgroundSnapshotForPresentation() {
    let cachedItem = MenuBarItemDescriptor(
        id: "cached-item",
        bundleID: "com.example.cached",
        displayName: "Cached",
        ownerPID: 1,
        bounds: CGRect(x: 120, y: 860, width: 24, height: 24),
        source: .windowServer,
        capabilities: ItemCapabilities()
    )
    let freshForegroundItem = MenuBarItemDescriptor(
        id: "foreground-item",
        bundleID: "com.example.foreground",
        displayName: "Foreground",
        ownerPID: 2,
        bounds: CGRect(x: 180, y: 860, width: 24, height: 24),
        source: .windowServer,
        capabilities: ItemCapabilities()
    )

    let resolution = SystemMenuBarDiscoveryService.resolvePresentationItems(
        mergedItems: [freshForegroundItem],
        backgroundSnapshot: [cachedItem],
        appIsActive: true,
        scanningPaused: true
    )

    #expect(resolution.itemsToPublish == [cachedItem])
    #expect(resolution.updatedBackgroundSnapshot == [cachedItem])
}

@Test
func inactiveAppPublishesFreshScanAndUpdatesCache() {
    let backgroundItem = MenuBarItemDescriptor(
        id: "background-item",
        bundleID: "com.example.background",
        displayName: "Background",
        ownerPID: 3,
        bounds: CGRect(x: 240, y: 860, width: 24, height: 24),
        source: .accessibility,
        capabilities: ItemCapabilities(canPerformPress: true)
    )

    let resolution = SystemMenuBarDiscoveryService.resolvePresentationItems(
        mergedItems: [backgroundItem],
        backgroundSnapshot: [],
        appIsActive: false,
        scanningPaused: false
    )

    #expect(resolution.itemsToPublish == [backgroundItem])
    #expect(resolution.updatedBackgroundSnapshot == [backgroundItem])
}

@Test
func activeAppWithoutBackgroundSnapshotDoesNotPublishForegroundScan() {
    let foregroundItem = MenuBarItemDescriptor(
        id: "foreground-item",
        bundleID: "com.example.foreground",
        displayName: "Foreground",
        ownerPID: 4,
        bounds: CGRect(x: 300, y: 860, width: 24, height: 24),
        source: .windowServer,
        capabilities: ItemCapabilities()
    )

    let resolution = SystemMenuBarDiscoveryService.resolvePresentationItems(
        mergedItems: [foregroundItem],
        backgroundSnapshot: [],
        appIsActive: true,
        scanningPaused: true
    )

    #expect(resolution.itemsToPublish == nil)
    #expect(resolution.updatedBackgroundSnapshot.isEmpty)
}
