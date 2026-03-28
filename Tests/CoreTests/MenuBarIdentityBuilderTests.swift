import Core
import Testing
import CoreGraphics

@Test
func stableIDPrefersAccessibilityIdentifier() {
    let seed = ItemIdentitySeed(
        bundleID: "com.example.app",
        axIdentifier: "wifi-status",
        title: "Wi-Fi",
        role: "AXMenuBarItem",
        subrole: nil,
        bounds: CGRect(x: 100, y: 100, width: 24, height: 22)
    )

    #expect(MenuBarIdentityBuilder.stableID(from: seed) == "com.example.app#wifi-status")
}

@Test
func stableIDFallsBackToTitleThenGeometry() {
    let titleSeed = ItemIdentitySeed(
        bundleID: "com.example.app",
        axIdentifier: nil,
        title: " Now Playing ",
        role: "AXMenuBarItem",
        subrole: nil,
        bounds: CGRect(x: 100, y: 100, width: 24, height: 22)
    )
    let geometrySeed = ItemIdentitySeed(
        bundleID: "com.example.app",
        axIdentifier: nil,
        title: nil,
        role: "AXMenuBarItem",
        subrole: "AXUnknown",
        bounds: CGRect(x: 98.7, y: 100, width: 24.2, height: 22.1)
    )

    #expect(MenuBarIdentityBuilder.stableID(from: titleSeed) == "com.example.app#now_playing")
    #expect(MenuBarIdentityBuilder.stableID(from: geometrySeed) == "com.example.app#axmenubaritem#axunknown#99:24:22")
}
