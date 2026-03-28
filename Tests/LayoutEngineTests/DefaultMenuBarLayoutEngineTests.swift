import Core
import LayoutEngine
import Testing
import CoreGraphics

private func makeItem(id: String, x: CGFloat, kind: VisibilityRuleKind) -> ManagedMenuBarItem {
    ManagedMenuBarItem(
        descriptor: MenuBarItemDescriptor(
            id: id,
            bundleID: "com.example.\(id)",
            displayName: id,
            ownerPID: 1,
            bounds: CGRect(x: x, y: 100, width: 24, height: 22),
            source: .accessibility,
            capabilities: .init(canPerformPress: true)
        ),
        rule: VisibilityRule(itemID: id, kind: kind)
    )
}

@Test
func layoutSeparatesVisibleMaskedAndShelfItems() {
    let engine = DefaultMenuBarLayoutEngine()
    let visible = makeItem(id: "visible", x: 10, kind: .alwaysVisible)
    let hiddenA = makeItem(id: "hidden-a", x: 40, kind: .hiddenInBar)
    let hiddenB = makeItem(id: "hidden-b", x: 70, kind: .hiddenInBar)
    let alwaysHidden = makeItem(id: "always-hidden", x: 90, kind: .alwaysHidden)

    let result = engine.computeLayout(
        input: MenuBarLayoutInput(
            items: [hiddenB, alwaysHidden, visible, hiddenA],
            hiddenOrder: ["hidden-b", "hidden-a"],
            revealState: .expanded,
            anchorFrame: nil,
            appearance: .init()
        )
    )

    #expect(result.visibleItems.map(\.id) == ["visible"])
    #expect(result.maskedItems.map(\.id) == ["hidden-a", "hidden-b", "always-hidden"])
    #expect(result.shelfItems.map(\.id) == ["hidden-b", "hidden-a"])
}
