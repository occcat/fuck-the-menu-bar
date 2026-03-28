import ApplicationServices
import Foundation

@MainActor
public final class AXElementCache {
    public static let shared = AXElementCache()

    private var elements: [String: AXUIElement] = [:]

    private init() {}

    public func replace(with entries: [String: AXUIElement]) {
        elements = entries
    }

    public func element(for itemID: String) -> AXUIElement? {
        elements[itemID]
    }

    public func removeValue(for itemID: String) {
        elements[itemID] = nil
    }

    public func clear() {
        elements.removeAll()
    }
}
