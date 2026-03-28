import AppKit
import ApplicationServices
import Core
import Foundation

@MainActor
public final class DefaultMenuBarInteractionRouter: MenuBarInteractionRouterProtocol {
    public init() {}

    public func tryAccessibilityPress(item: MenuBarItemDescriptor) -> Bool {
        performAccessibilityPress(for: item)
    }

    public func activate(item: MenuBarItemDescriptor, interactionMode: ProxyInteractionMode, button: MenuBarClickButton) {
        if button == .right {
            performRealClick(for: item, button: .right)
            return
        }

        switch interactionMode {
        case .proxyPreferred:
            if performAccessibilityPress(for: item) { return }
            performRealClick(for: item, button: .left)
        case .revealBeforeAction, .realClickOnly:
            performRealClick(for: item, button: .left)
        }
    }

    private func performAccessibilityPress(for item: MenuBarItemDescriptor) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        if let cached = AXElementCache.shared.element(for: item.id),
           AXUIElementPerformAction(cached, kAXPressAction as CFString) == .success {
            return true
        }

        AXElementCache.shared.removeValue(for: item.id)
        guard let element = findMatchingElement(for: item) else { return false }
        let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return status == .success
    }

    private func performRealClick(for item: MenuBarItemDescriptor, button: MenuBarClickButton) {
        let originalPosition = NSEvent.mouseLocation
        let center = CGPoint(x: item.bounds.midX, y: item.bounds.midY)
        let mouseTypeDown: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let mouseTypeUp: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
        let mouseButton: CGMouseButton = button == .right ? .right : .left
        guard
            let mouseDown = CGEvent(mouseEventSource: nil, mouseType: mouseTypeDown, mouseCursorPosition: center, mouseButton: mouseButton),
            let mouseUp = CGEvent(mouseEventSource: nil, mouseType: mouseTypeUp, mouseCursorPosition: center, mouseButton: mouseButton)
        else {
            return
        }
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)

        if let mainScreen = NSScreen.main {
            let cgY = mainScreen.frame.height - originalPosition.y
            CGWarpMouseCursorPosition(CGPoint(x: originalPosition.x, y: cgY))
        }
    }

    private func findMatchingElement(for item: MenuBarItemDescriptor) -> AXUIElement? {
        guard let app = NSRunningApplication(processIdentifier: item.ownerPID) else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        let bars = [
            attribute(root, name: "AXExtrasMenuBar"),
            attribute(root, name: kAXMenuBarAttribute as String),
        ].compactMap { $0 }

        for bar in bars {
            for child in recursiveChildren(of: bar, depth: 2) {
                guard let bounds = frame(for: child) else { continue }
                let title = stringAttribute(child, name: kAXTitleAttribute as String)
                    ?? stringAttribute(child, name: kAXDescriptionAttribute as String)
                let role = stringAttribute(child, name: kAXRoleAttribute as String)
                let subrole = stringAttribute(child, name: kAXSubroleAttribute as String)
                let identifier = stringAttribute(child, name: kAXIdentifierAttribute as String)
                let seed = ItemIdentitySeed(
                    bundleID: item.bundleID,
                    axIdentifier: identifier,
                    title: title,
                    role: role,
                    subrole: subrole,
                    bounds: bounds
                )
                if MenuBarIdentityBuilder.stableID(from: seed) == item.id {
                    return child
                }
            }
        }

        return nil
    }

    private func attribute(_ element: AXUIElement, name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as! AXUIElement?
    }

    private func recursiveChildren(of element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth >= 0 else { return [] }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }

        guard depth > 0 else { return children }
        return children + children.flatMap { recursiveChildren(of: $0, depth: depth - 1) }
    }

    private func frame(for element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let positionValue = positionRef,
            let sizeValue = sizeRef
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    private func stringAttribute(_ element: AXUIElement, name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
