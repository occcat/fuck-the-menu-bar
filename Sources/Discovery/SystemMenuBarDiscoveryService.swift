import AppKit
import ApplicationServices
import Core
import Foundation
import Localization

@MainActor
public final class SystemMenuBarDiscoveryService: MenuBarDiscoveryServiceProtocol {
    public private(set) var items: [MenuBarItemDescriptor] = []
    public var onItemsDidChange: (([MenuBarItemDescriptor]) -> Void)?

    private var timer: Timer?
    private var automaticScanningPaused = false

    public init() {}

    public func start() {
        rescan()
        scheduleTimerIfNeeded()
    }

    public func setAutomaticScanningPaused(_ paused: Bool) {
        automaticScanningPaused = paused
        if paused {
            timer?.invalidate()
            timer = nil
        } else {
            scheduleTimerIfNeeded()
        }
    }

    private func scheduleTimerIfNeeded() {
        guard timer == nil, !automaticScanningPaused else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rescan()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func rescan() {
        let axItems = Self.scanAccessibilityItems()
        let windowItems = Self.scanWindowServerCandidates()
        let merged = Self.merge(accessibilityItems: axItems, windowItems: windowItems)
        guard merged != items else { return }
        items = merged
        onItemsDidChange?(merged)
    }

    private static func merge(
        accessibilityItems: [MenuBarItemDescriptor],
        windowItems: [MenuBarItemDescriptor]
    ) -> [MenuBarItemDescriptor] {
        var result: [String: MenuBarItemDescriptor] = [:]
        for item in windowItems {
            result[item.id] = item
        }
        for item in accessibilityItems {
            if let existing = result[item.id] {
                result[item.id] = mergedDescriptor(preferred: item, fallback: existing)
            } else {
                result[item.id] = item
            }
        }
        return result.values.sorted { lhs, rhs in
            if lhs.bounds.minX == rhs.bounds.minX {
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.bounds.minX < rhs.bounds.minX
        }
    }

    private static func mergedDescriptor(
        preferred: MenuBarItemDescriptor,
        fallback: MenuBarItemDescriptor
    ) -> MenuBarItemDescriptor {
        MenuBarItemDescriptor(
            id: preferred.id,
            bundleID: preferred.bundleID,
            displayName: preferred.displayName.isEmpty ? fallback.displayName : preferred.displayName,
            ownerPID: preferred.ownerPID,
            axIdentifier: preferred.axIdentifier ?? fallback.axIdentifier,
            role: preferred.role ?? fallback.role,
            subrole: preferred.subrole ?? fallback.subrole,
            bounds: preferred.bounds == .zero ? fallback.bounds : preferred.bounds,
            source: preferred.source,
            capabilities: ItemCapabilities(
                canPerformPress: preferred.capabilities.canPerformPress || fallback.capabilities.canPerformPress,
                canHover: preferred.capabilities.canHover || fallback.capabilities.canHover,
                canSnapshot: preferred.capabilities.canSnapshot || fallback.capabilities.canSnapshot,
                requiresRealHitTarget: preferred.capabilities.requiresRealHitTarget && fallback.capabilities.requiresRealHitTarget
            )
        )
    }

    private static func scanAccessibilityItems() -> [MenuBarItemDescriptor] {
        guard AXIsProcessTrusted() else {
            AXElementCache.shared.clear()
            return []
        }

        var descriptors: [MenuBarItemDescriptor] = []
        var cache: [String: AXUIElement] = [:]
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier > 0 {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            let bars = [attribute(element, name: "AXExtrasMenuBar"), attribute(element, name: kAXMenuBarAttribute as String)]
                .compactMap { $0 }

            for bar in bars {
                let children = recursiveChildren(of: bar, depth: 2)
                for child in children {
                    guard let bounds = frame(for: child), bounds.width > 0, bounds.height > 0 else { continue }
                    guard isLikelyMenuBarItem(bounds: bounds) else { continue }

                    let title = stringAttribute(child, name: kAXTitleAttribute as String)
                        ?? stringAttribute(child, name: kAXDescriptionAttribute as String)
                        ?? app.localizedName
                        ?? app.bundleIdentifier
                        ?? L10n.string("fallback.untitled")
                    let role = stringAttribute(child, name: kAXRoleAttribute as String)
                    let subrole = stringAttribute(child, name: kAXSubroleAttribute as String)
                    let identifier = stringAttribute(child, name: kAXIdentifierAttribute as String)
                    let actions = actionNames(for: child)
                    let seed = ItemIdentitySeed(
                        bundleID: app.bundleIdentifier ?? app.localizedName ?? "unknown.bundle",
                        axIdentifier: identifier,
                        title: title,
                        role: role,
                        subrole: subrole,
                        bounds: bounds
                    )
                    let capabilities = ItemCapabilities(
                        canPerformPress: actions.contains("AXPress"),
                        canHover: actions.contains("AXShowMenu"),
                        canSnapshot: CGPreflightScreenCaptureAccess(),
                        requiresRealHitTarget: !actions.contains("AXPress")
                    )

                    let id = MenuBarIdentityBuilder.stableID(from: seed)
                    cache[id] = child
                    descriptors.append(
                        MenuBarItemDescriptor(
                            id: id,
                            bundleID: app.bundleIdentifier ?? app.localizedName ?? "unknown.bundle",
                            displayName: title,
                            ownerPID: app.processIdentifier,
                            axIdentifier: identifier,
                            role: role,
                            subrole: subrole,
                            bounds: bounds,
                            source: .accessibility,
                            capabilities: capabilities
                        )
                    )
                }
            }
        }
        AXElementCache.shared.replace(with: cache)
        return descriptors
    }

    private static func scanWindowServerCandidates() -> [MenuBarItemDescriptor] {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return infoList.compactMap { info in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                isLikelyMenuBarItem(bounds: bounds),
                bounds.width > 10,
                bounds.width < 180
            else {
                return nil
            }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? L10n.string("fallback.unknown")
            let bundleID = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier ?? ownerName
            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? ownerName
            let seed = ItemIdentitySeed(
                bundleID: bundleID,
                axIdentifier: nil,
                title: title,
                role: "CGWindow",
                subrole: nil,
                bounds: bounds
            )

            return MenuBarItemDescriptor(
                id: MenuBarIdentityBuilder.stableID(from: seed),
                bundleID: bundleID,
                displayName: title,
                ownerPID: ownerPID,
                bounds: bounds,
                source: .windowServer,
                capabilities: ItemCapabilities(canSnapshot: CGPreflightScreenCaptureAccess(), requiresRealHitTarget: true)
            )
        }
    }

    private static func isLikelyMenuBarItem(bounds: CGRect) -> Bool {
        NSScreen.screens.contains { screen in
            let topInset = screen.frame.maxY - bounds.maxY
            return topInset >= -4 && topInset <= 40 && bounds.maxX <= screen.frame.maxX && bounds.minX >= screen.frame.minX
        }
    }

    private static func attribute(_ element: AXUIElement, name: String) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func stringAttribute(_ element: AXUIElement, name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func recursiveChildren(of element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth >= 0 else { return [] }
        var children: [AXUIElement] = []

        if let directChildren = arrayAttribute(element, name: kAXChildrenAttribute as String) {
            children.append(contentsOf: directChildren)
            guard depth > 0 else { return children }
            for child in directChildren {
                children.append(contentsOf: recursiveChildren(of: child, depth: depth - 1))
            }
        }

        return children
    }

    private static func arrayAttribute(_ element: AXUIElement, name: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private static func frame(for element: AXUIElement) -> CGRect? {
        guard
            let positionValue = valueAttribute(element, name: kAXPositionAttribute as String),
            let sizeValue = valueAttribute(element, name: kAXSizeAttribute as String)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetType(positionValue) == .cgPoint,
            AXValueGetValue(positionValue, .cgPoint, &position),
            AXValueGetType(sizeValue) == .cgSize,
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private static func valueAttribute(_ element: AXUIElement, name: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as! AXValue?
    }

    private static func actionNames(for element: AXUIElement) -> [String] {
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success else { return [] }
        return actions as? [String] ?? []
    }
}
