import AppKit
import Core
import Foundation

@MainActor
public final class MenuBarSnapshotProvider {
    private struct ResolvedIcon {
        let filePath: String?
        let image: NSImage?
    }

    private struct CacheEntry {
        let signature: String
        let snapshot: ManagedItemSnapshot
    }

    private var cache: [String: CacheEntry] = [:]

    public init() {}

    public func snapshot(for item: MenuBarItemDescriptor) -> ManagedItemSnapshot {
        let resolvedIcon = resolveIcon(for: item)
        let signature = cacheSignature(for: item, iconFilePath: resolvedIcon.filePath)
        if let cached = cache[item.id], cached.signature == signature {
            return cached.snapshot
        }

        let snapshot = ManagedItemSnapshot(
            id: item.id,
            image: resolvedIcon.image,
            iconFilePath: resolvedIcon.filePath,
            displayName: item.displayName,
            size: NSSize(width: 20, height: 20)
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

    private func resolveIcon(for item: MenuBarItemDescriptor) -> ResolvedIcon {
        guard let applicationURL = resolveApplicationURL(for: item),
              let iconFilePath = resolveIconFilePath(for: item, applicationURL: applicationURL),
              FileManager.default.fileExists(atPath: iconFilePath) else {
            return ResolvedIcon(filePath: nil, image: nil)
        }

        let image = NSImage(contentsOfFile: iconFilePath)
        image?.size = NSSize(width: 20, height: 20)
        return ResolvedIcon(filePath: iconFilePath, image: image)
    }

    private func resolveApplicationURL(for item: MenuBarItemDescriptor) -> URL? {
        if let runningApp = NSRunningApplication(processIdentifier: item.ownerPID),
           let bundleURL = runningApp.bundleURL {
            return bundleURL
        }

        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
            return bundleURL
        }

        let candidateNames = [
            item.displayName,
            item.bundleID.components(separatedBy: ".").last ?? item.bundleID,
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let searchRoots = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        ]

        for root in searchRoots {
            for name in candidateNames {
                let candidate = root.appendingPathComponent("\(name).app", isDirectory: true)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    private func resolveIconFilePath(for item: MenuBarItemDescriptor, applicationURL: URL) -> String? {
        guard let bundle = Bundle(url: applicationURL) else {
            return nil
        }

        let resourcesURL = bundle.resourceURL ?? applicationURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let candidateBaseNames = iconCandidateBaseNames(for: item, bundle: bundle)
        let fileManager = FileManager.default

        for baseName in candidateBaseNames {
            let trimmed = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let explicitURL = resourcesURL.appendingPathComponent(trimmed)
            if fileManager.fileExists(atPath: explicitURL.path) {
                return explicitURL.path
            }

            for ext in ["icns", "png", "pdf"] {
                let candidateURL = resourcesURL.appendingPathComponent(trimmed).appendingPathExtension(ext)
                if fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL.path
                }
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: resourcesURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let preferredNeedles = candidateBaseNames
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        var fallbackPath: String?

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ["icns", "png", "pdf"].contains(ext) else { continue }
            let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()

            if preferredNeedles.contains(where: { needle in baseName == needle || baseName.contains(needle) }) {
                return fileURL.path
            }

            if fallbackPath == nil, ext == "icns" {
                fallbackPath = fileURL.path
            }
        }

        return fallbackPath
    }

    private func iconCandidateBaseNames(for item: MenuBarItemDescriptor, bundle: Bundle) -> [String] {
        var candidates: [String] = []

        if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            candidates.append(iconFile)
        }

        if let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
            candidates.append(iconName)
        }

        if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primary["CFBundleIconFiles"] as? [String] {
            candidates.append(contentsOf: iconFiles)
        }

        candidates.append(item.displayName)
        candidates.append(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "")
        candidates.append(bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "")
        candidates.append(applicationName(from: bundle.bundleURL))

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func applicationName(from bundleURL: URL) -> String {
        bundleURL.deletingPathExtension().lastPathComponent
    }

    private func cacheSignature(for item: MenuBarItemDescriptor, iconFilePath: String?) -> String {
        [
            item.displayName,
            item.bundleID,
            iconFilePath ?? "missing-icon",
            "\(Int(item.bounds.minX.rounded()))",
            "\(Int(item.bounds.minY.rounded()))",
            "\(Int(item.bounds.width.rounded()))",
            "\(Int(item.bounds.height.rounded()))",
        ].joined(separator: "|")
    }
}
