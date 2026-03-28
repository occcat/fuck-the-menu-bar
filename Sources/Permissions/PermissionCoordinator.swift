import Core
import ApplicationServices
import Foundation
import ServiceManagement

@MainActor
public final class PermissionCoordinator {
    public init() {}

    public func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            launchAtLoginEnabled: launchAtLoginEnabled
        )
    }

    @discardableResult
    public func requestAccessibilityPermission(prompt: Bool = true) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    public func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func setLaunchAtLogin(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
