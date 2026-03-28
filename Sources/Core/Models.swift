import AppKit
import Carbon
import Foundation

public enum DiscoverySource: String, Codable, Hashable, Sendable {
    case accessibility
    case windowServer
    case synthesized
}

public enum VisibilityRuleKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case alwaysVisible
    case hiddenInBar
    case alwaysHidden

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alwaysVisible: "Always Visible"
        case .hiddenInBar: "Hidden in Shelf"
        case .alwaysHidden: "Always Hidden"
        }
    }
}

public enum ProxyInteractionMode: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case proxyPreferred
    case revealBeforeAction
    case realClickOnly

    public var id: String { rawValue }
}

public enum RevealState: String, Codable, Hashable, Sendable {
    case collapsed
    case expanded
}

public enum AppLanguage: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    public var id: String { rawValue }
}

public struct ItemCapabilities: Codable, Hashable, Sendable {
    public var canPerformPress: Bool
    public var canHover: Bool
    public var canSnapshot: Bool
    public var requiresRealHitTarget: Bool

    public init(
        canPerformPress: Bool = false,
        canHover: Bool = false,
        canSnapshot: Bool = false,
        requiresRealHitTarget: Bool = false
    ) {
        self.canPerformPress = canPerformPress
        self.canHover = canHover
        self.canSnapshot = canSnapshot
        self.requiresRealHitTarget = requiresRealHitTarget
    }
}

public struct MenuBarItemDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var bundleID: String
    public var displayName: String
    public var ownerPID: pid_t
    public var axIdentifier: String?
    public var role: String?
    public var subrole: String?
    public var bounds: CGRect
    public var source: DiscoverySource
    public var capabilities: ItemCapabilities

    public init(
        id: String,
        bundleID: String,
        displayName: String,
        ownerPID: pid_t,
        axIdentifier: String? = nil,
        role: String? = nil,
        subrole: String? = nil,
        bounds: CGRect,
        source: DiscoverySource,
        capabilities: ItemCapabilities
    ) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.ownerPID = ownerPID
        self.axIdentifier = axIdentifier
        self.role = role
        self.subrole = subrole
        self.bounds = bounds
        self.source = source
        self.capabilities = capabilities
    }
}

public struct ItemIdentitySeed: Sendable {
    public var bundleID: String
    public var axIdentifier: String?
    public var title: String?
    public var role: String?
    public var subrole: String?
    public var bounds: CGRect

    public init(
        bundleID: String,
        axIdentifier: String?,
        title: String?,
        role: String?,
        subrole: String?,
        bounds: CGRect
    ) {
        self.bundleID = bundleID
        self.axIdentifier = axIdentifier
        self.title = title
        self.role = role
        self.subrole = subrole
        self.bounds = bounds
    }
}

public enum MenuBarIdentityBuilder {
    public static func stableID(from seed: ItemIdentitySeed) -> String {
        if let identifier = normalized(seed.axIdentifier) {
            return "\(seed.bundleID)#\(identifier)"
        }

        if let title = normalized(seed.title) {
            return "\(seed.bundleID)#\(title)"
        }

        let role = normalized(seed.role) ?? "unknown-role"
        let subrole = normalized(seed.subrole) ?? "unknown-subrole"
        let signature = geometrySignature(for: seed.bounds)
        return "\(seed.bundleID)#\(role)#\(subrole)#\(signature)"
    }

    public static func geometrySignature(for bounds: CGRect) -> String {
        "\(Int(bounds.minX.rounded())):\(Int(bounds.width.rounded())):\(Int(bounds.height.rounded()))"
    }

    private static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return trimmed.isEmpty ? nil : trimmed.replacingOccurrences(of: " ", with: "_")
    }
}

public struct VisibilityRule: Identifiable, Codable, Hashable, Sendable {
    public var itemID: String
    public var kind: VisibilityRuleKind
    public var customName: String?
    public var interactionMode: ProxyInteractionMode

    public init(
        itemID: String,
        kind: VisibilityRuleKind = .hiddenInBar,
        customName: String? = nil,
        interactionMode: ProxyInteractionMode = .proxyPreferred
    ) {
        self.itemID = itemID
        self.kind = kind
        self.customName = customName
        self.interactionMode = interactionMode
    }

    public var id: String { itemID }
}

public struct ManagedItemSnapshot: Identifiable {
    public var id: String
    public var image: NSImage?
    public var displayName: String
    public var size: CGSize
    public var capturedAt: Date

    public init(
        id: String,
        image: NSImage?,
        displayName: String,
        size: CGSize,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.image = image
        self.displayName = displayName
        self.size = size
        self.capturedAt = capturedAt
    }
}

public struct HotkeyConfiguration: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var isEnabled: Bool

    public init(keyCode: UInt32 = 46, modifiers: UInt32 = UInt32(cmdKey | optionKey), isEnabled: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}

public struct AppearanceSettings: Codable, Hashable, Sendable {
    public var itemSpacing: Double
    public var showLabels: Bool
    public var collapsedMaskOpacity: Double
    public var animationDuration: Double
    public var stripPadding: Double

    public init(
        itemSpacing: Double = 8,
        showLabels: Bool = false,
        collapsedMaskOpacity: Double = 0.92,
        animationDuration: Double = 0.18,
        stripPadding: Double = 10
    ) {
        self.itemSpacing = itemSpacing
        self.showLabels = showLabels
        self.collapsedMaskOpacity = collapsedMaskOpacity
        self.animationDuration = animationDuration
        self.stripPadding = stripPadding
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var rules: [String: VisibilityRule]
    public var hiddenOrder: [String]
    public var appearance: AppearanceSettings
    public var hotkey: HotkeyConfiguration
    public var preferredLanguage: AppLanguage
    public var launchAtLogin: Bool
    public var completedOnboarding: Bool

    public init(
        schemaVersion: Int = 1,
        rules: [String: VisibilityRule] = [:],
        hiddenOrder: [String] = [],
        appearance: AppearanceSettings = .init(),
        hotkey: HotkeyConfiguration = .init(),
        preferredLanguage: AppLanguage = .system,
        launchAtLogin: Bool = false,
        completedOnboarding: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.rules = rules
        self.hiddenOrder = hiddenOrder
        self.appearance = appearance
        self.hotkey = hotkey
        self.preferredLanguage = preferredLanguage
        self.launchAtLogin = launchAtLogin
        self.completedOnboarding = completedOnboarding
    }
}

public struct PermissionSnapshot: Equatable, Sendable {
    public var accessibilityGranted: Bool
    public var screenRecordingGranted: Bool
    public var launchAtLoginEnabled: Bool

    public init(
        accessibilityGranted: Bool = false,
        screenRecordingGranted: Bool = false,
        launchAtLoginEnabled: Bool = false
    ) {
        self.accessibilityGranted = accessibilityGranted
        self.screenRecordingGranted = screenRecordingGranted
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }
}

public struct ManagedMenuBarItem: Identifiable, Hashable {
    public var descriptor: MenuBarItemDescriptor
    public var rule: VisibilityRule
    public var snapshot: ManagedItemSnapshot?

    public init(descriptor: MenuBarItemDescriptor, rule: VisibilityRule, snapshot: ManagedItemSnapshot? = nil) {
        self.descriptor = descriptor
        self.rule = rule
        self.snapshot = snapshot
    }

    public var id: String { descriptor.id }

    public var displayName: String {
        rule.customName ?? descriptor.displayName
    }

    public static func == (lhs: ManagedMenuBarItem, rhs: ManagedMenuBarItem) -> Bool {
        lhs.id == rhs.id && lhs.rule == rhs.rule
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(rule)
    }
}

public struct MenuBarLayoutInput {
    public var items: [ManagedMenuBarItem]
    public var hiddenOrder: [String]
    public var revealState: RevealState
    public var anchorFrame: CGRect?
    public var appearance: AppearanceSettings

    public init(
        items: [ManagedMenuBarItem],
        hiddenOrder: [String],
        revealState: RevealState,
        anchorFrame: CGRect?,
        appearance: AppearanceSettings
    ) {
        self.items = items
        self.hiddenOrder = hiddenOrder
        self.revealState = revealState
        self.anchorFrame = anchorFrame
        self.appearance = appearance
    }
}

public struct MenuBarLayoutResult {
    public var visibleItems: [ManagedMenuBarItem]
    public var maskedItems: [ManagedMenuBarItem]
    public var shelfItems: [ManagedMenuBarItem]

    public init(
        visibleItems: [ManagedMenuBarItem],
        maskedItems: [ManagedMenuBarItem],
        shelfItems: [ManagedMenuBarItem]
    ) {
        self.visibleItems = visibleItems
        self.maskedItems = maskedItems
        self.shelfItems = shelfItems
    }
}
