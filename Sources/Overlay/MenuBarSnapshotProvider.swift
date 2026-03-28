import AppKit
import Core
import Foundation

@MainActor
public final class MenuBarSnapshotProvider {
    private struct CacheEntry {
        let signature: String
        let snapshot: ManagedItemSnapshot
    }

    private var cache: [String: CacheEntry] = [:]

    public init() {}

    public func snapshot(for item: MenuBarItemDescriptor) -> ManagedItemSnapshot {
        let signature = cacheSignature(for: item)
        if let cached = cache[item.id], cached.signature == signature {
            return cached.snapshot
        }

        let image = CGPreflightScreenCaptureAccess() ? captureImage(for: item.bounds) : nil
        let snapshot = ManagedItemSnapshot(
            id: item.id,
            image: image ?? placeholderImage(for: item),
            displayName: item.displayName,
            size: image?.size ?? item.bounds.size
        )
        cache[item.id] = CacheEntry(signature: signature, snapshot: snapshot)
        return snapshot
    }

    public func invalidateAll() {
        cache.removeAll()
    }

    public func prune(keeping itemIDs: Set<String>) {
        cache = cache.filter { itemIDs.contains($0.key) }
    }

    private func captureImage(for rect: CGRect) -> NSImage? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) else {
            return nil
        }
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }

        let displayRect = CGRect(
            x: rect.minX - screen.frame.minX,
            y: rect.minY - screen.frame.minY,
            width: rect.width,
            height: rect.height
        )
        guard let cgImage = CGDisplayCreateImage(displayID, rect: displayRect) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: rect.size)
    }

    private func placeholderImage(for item: MenuBarItemDescriptor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let base = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: item.displayName)?
            .withSymbolConfiguration(config)
        guard let base else { return nil }

        let canvas = NSImage(size: NSSize(width: max(item.bounds.width, 18), height: 18))
        canvas.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvas.size)).fill()
        base.draw(in: NSRect(x: 2, y: 2, width: 14, height: 14))
        canvas.unlockFocus()
        return canvas
    }

    private func cacheSignature(for item: MenuBarItemDescriptor) -> String {
        [
            item.displayName,
            "\(Int(item.bounds.minX.rounded()))",
            "\(Int(item.bounds.minY.rounded()))",
            "\(Int(item.bounds.width.rounded()))",
            "\(Int(item.bounds.height.rounded()))",
            CGPreflightScreenCaptureAccess() ? "capture" : "placeholder",
        ].joined(separator: "|")
    }
}
