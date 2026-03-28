import ApplicationServices
import Foundation

public final class AXElementCache {
    public nonisolated(unsafe) static let shared = AXElementCache()

    private var elements: [String: AXUIElement] = [:]
    private let lock = NSLock()

    private init() {}

    public func replace(with entries: [String: AXUIElement]) {
        lock.lock()
        defer { lock.unlock() }
        elements = entries
    }

    public func element(for itemID: String) -> AXUIElement? {
        lock.lock()
        defer { lock.unlock() }
        return elements[itemID]
    }

    public func removeValue(for itemID: String) {
        lock.lock()
        defer { lock.unlock() }
        elements[itemID] = nil
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        elements.removeAll()
    }
}
