import AppKit
import Core
import LayoutEngine
import Localization
import SharedUI
import SwiftUI

/// Pure geometry for the shelf bubble. Shared by frame computation and the SwiftUI layout,
/// so the hit-test rect (`bubbleFrame`) always matches what is drawn.
public enum ShelfBubbleMetrics {
    public static let collapsedPanelHeight: CGFloat = 44
    public static let panelPadding: CGFloat = 8
    public static let bubbleBottomInset: CGFloat = 18
    public static let minimumMenuBarClearance: CGFloat = 24
    public static let bubbleWidth: CGFloat = 268
    public static let rowHeight: CGFloat = 48
    public static let rowSpacing: CGFloat = 4
    public static let maxVisibleRows = 5
    public static let bubbleCornerRadius: CGFloat = 24
    public static let iconTileSize: CGFloat = 34

    /// Concentric with the bubble: inner radius = outer radius - padding.
    public static var rowCornerRadius: CGFloat { bubbleCornerRadius - panelPadding }
    /// Concentric with the row.
    public static var iconTileCornerRadius: CGFloat { rowCornerRadius - (rowHeight - iconTileSize) / 2 }

    public static func visibleRowCount(for itemCount: Int) -> Int {
        min(max(itemCount, 1), maxVisibleRows)
    }

    public static func contentHeight(rows: Int) -> CGFloat {
        let rows = max(rows, 0)
        return CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * rowSpacing
    }

    public static func bubbleHeight(itemCount: Int) -> CGFloat {
        contentHeight(rows: visibleRowCount(for: itemCount)) + panelPadding * 2
    }

    public static func needsScrolling(itemCount: Int) -> Bool {
        itemCount > maxVisibleRows
    }
}

@MainActor
public final class MenuBarOverlayController {
    public final class State: ObservableObject {
        @Published var layout = MenuBarLayoutResult(visibleItems: [], maskedItems: [], shelfItems: [])
        @Published var appearance = AppearanceSettings()
        @Published var revealState: RevealState = .collapsed
        @Published var windowFrame: CGRect = .zero
        @Published var screenFrame: CGRect = .zero
        @Published var anchorFrame: CGRect?
        @Published var bubbleFrame: CGRect = .zero
        @Published var temporarilyRevealed: Set<String> = []

        var onActivate: ((ManagedMenuBarItem, MenuBarClickButton) -> Void)?
        var onRequestCollapse: (() -> Void)?
    }

    private let state = State()
    private var window: NSPanel?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var collapseWorkItem: DispatchWorkItem?

    public init() {}

    public func update(
        on screen: NSScreen?,
        revealState: RevealState,
        layout: MenuBarLayoutResult,
        appearance: AppearanceSettings,
        anchorFrame: CGRect?,
        onActivate: @escaping (ManagedMenuBarItem, MenuBarClickButton) -> Void,
        onRequestCollapse: @escaping () -> Void
    ) {
        guard let screen else {
            hide()
            return
        }

        collapseWorkItem?.cancel()
        let shouldHoldExpandedFrameForCollapse =
            state.revealState == .expanded &&
            revealState == .collapsed &&
            !state.layout.shelfItems.isEmpty
        let frameRevealState: RevealState = shouldHoldExpandedFrameForCollapse ? .expanded : revealState
        // While collapsing, keep the previous shelf geometry so the removal transition is not clipped.
        let frameLayout = shouldHoldExpandedFrameForCollapse ? state.layout : layout
        let panelHeight = panelHeight(
            for: frameLayout,
            revealState: frameRevealState,
            screenFrame: screen.frame,
            anchorFrame: anchorFrame,
            bubbleAnchorGap: CGFloat(appearance.bubbleVerticalOffset)
        )
        let windowFrame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - panelHeight,
            width: screen.frame.width,
            height: panelHeight
        )
        let bubbleFrame = bubbleFrame(
            in: windowFrame,
            layout: frameLayout,
            revealState: frameRevealState,
            anchorFrame: anchorFrame,
            bubbleAnchorGap: CGFloat(appearance.bubbleVerticalOffset)
        )

        state.layout = layout
        state.appearance = appearance
        state.revealState = revealState
        state.windowFrame = windowFrame
        state.screenFrame = screen.frame
        state.anchorFrame = anchorFrame
        state.bubbleFrame = bubbleFrame
        state.onActivate = onActivate
        state.onRequestCollapse = onRequestCollapse

        if window == nil {
            let panel = NSPanel(
                contentRect: windowFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.contentView = NSHostingView(rootView: OverlayRootView(state: state))
            window = panel
        }

        window?.setFrame(windowFrame, display: true)
        window?.ignoresMouseEvents = !(revealState == .expanded && !layout.shelfItems.isEmpty)
        if layout.maskedItems.isEmpty {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }

        updateEventMonitors(isExpanded: revealState == .expanded && !layout.shelfItems.isEmpty)

        if shouldHoldExpandedFrameForCollapse {
            let collapseDelay = LiquidMotion.settleDuration(
                base: appearance.animationDuration,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.state.revealState == .collapsed else { return }
                let collapsedFrame = CGRect(
                    x: screen.frame.minX,
                    y: screen.frame.maxY - ShelfBubbleMetrics.collapsedPanelHeight,
                    width: screen.frame.width,
                    height: ShelfBubbleMetrics.collapsedPanelHeight
                )
                self.state.windowFrame = collapsedFrame
                self.state.bubbleFrame = .zero
                self.window?.setFrame(collapsedFrame, display: true)
            }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: workItem)
        }
    }

    public func temporarilyReveal(itemID: String, duration: TimeInterval = 0.8) {
        state.temporarilyRevealed.insert(itemID)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak state] in
            state?.temporarilyRevealed.remove(itemID)
        }
    }

    public func hide() {
        collapseWorkItem?.cancel()
        removeEventMonitors()
        window?.orderOut(nil)
    }

    private func topClearance(
        maxY: CGFloat,
        anchorFrame: CGRect?,
        bubbleAnchorGap: CGFloat
    ) -> CGFloat {
        if let anchorFrame {
            return maxY - anchorFrame.minY + bubbleAnchorGap
        }
        return max(bubbleAnchorGap, ShelfBubbleMetrics.minimumMenuBarClearance)
    }

    private func panelHeight(
        for layout: MenuBarLayoutResult,
        revealState: RevealState,
        screenFrame: CGRect,
        anchorFrame: CGRect?,
        bubbleAnchorGap: CGFloat
    ) -> CGFloat {
        guard revealState == .expanded, !layout.shelfItems.isEmpty else {
            return ShelfBubbleMetrics.collapsedPanelHeight
        }

        let bubbleHeight = ShelfBubbleMetrics.bubbleHeight(itemCount: layout.shelfItems.count)
        let clearance = topClearance(maxY: screenFrame.maxY, anchorFrame: anchorFrame, bubbleAnchorGap: bubbleAnchorGap)
        return max(
            ShelfBubbleMetrics.collapsedPanelHeight,
            bubbleHeight + clearance + ShelfBubbleMetrics.bubbleBottomInset
        )
    }

    private func bubbleFrame(
        in windowFrame: CGRect,
        layout: MenuBarLayoutResult,
        revealState: RevealState,
        anchorFrame: CGRect?,
        bubbleAnchorGap: CGFloat
    ) -> CGRect {
        guard revealState == .expanded, !layout.shelfItems.isEmpty else {
            return .zero
        }

        let width = ShelfBubbleMetrics.bubbleWidth
        let padding = ShelfBubbleMetrics.panelPadding
        let bubbleHeight = ShelfBubbleMetrics.bubbleHeight(itemCount: layout.shelfItems.count)
        let maxX = windowFrame.maxX - padding - width
        let minX = windowFrame.minX + padding
        let anchoredMidX = anchorFrame?.midX ?? windowFrame.midX
        let originX = min(max(anchoredMidX - (width / 2), minX), maxX)
        let clearance = topClearance(maxY: windowFrame.maxY, anchorFrame: anchorFrame, bubbleAnchorGap: bubbleAnchorGap)
        let preferredBubbleMaxY = windowFrame.maxY - clearance
        let minimumBubbleMaxY = windowFrame.minY + bubbleHeight + ShelfBubbleMetrics.bubbleBottomInset
        let maximumBubbleMaxY = windowFrame.maxY - ShelfBubbleMetrics.minimumMenuBarClearance
        let bubbleMaxY = min(max(preferredBubbleMaxY, minimumBubbleMaxY), maximumBubbleMaxY)
        let originY = bubbleMaxY - bubbleHeight

        return CGRect(x: originX, y: originY, width: width, height: bubbleHeight)
    }

    private func updateEventMonitors(isExpanded: Bool) {
        guard isExpanded else {
            removeEventMonitors()
            return
        }

        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                self?.handleInteraction(at: NSEvent.mouseLocation)
                return event
            }
        }

        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                self?.handleInteraction(at: NSEvent.mouseLocation)
            }
        }
    }

    private func removeEventMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    private func handleInteraction(at screenLocation: CGPoint) {
        guard state.revealState == .expanded else { return }
        if state.bubbleFrame.contains(screenLocation) {
            return
        }
        if let anchorFrame = state.anchorFrame, anchorFrame.insetBy(dx: -10, dy: -10).contains(screenLocation) {
            return
        }
        state.onRequestCollapse?()
    }
}

private struct OverlayRootView: View {
    @ObservedObject var state: MenuBarOverlayController.State
    @ObservedObject private var localization = LocalizationController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(state.layout.maskedItems) { item in
                if !state.temporarilyRevealed.contains(item.id) {
                    MaskedMenuBarItemView(maskOpacity: maskOpacity)
                        .frame(width: max(item.descriptor.bounds.width + 8, 22), height: max(item.descriptor.bounds.height + 8, 22))
                        .position(position(for: item.descriptor.bounds))
                }
            }

            if state.revealState == .expanded, !state.layout.shelfItems.isEmpty {
                shelfBubble
                    .transition(bubbleTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .animation(motion, value: state.revealState)
        .animation(motion, value: state.layout.shelfItems.map(\.id))
    }

    private var motion: Animation {
        LiquidMotion.spring(base: state.appearance.animationDuration, reduceMotion: reduceMotion)
    }

    private var shelfBubble: some View {
        LiquidGlassGroup(spacing: ShelfBubbleMetrics.rowSpacing) {
            shelfContent
                .padding(ShelfBubbleMetrics.panelPadding)
                .frame(width: state.bubbleFrame.width, height: state.bubbleFrame.height, alignment: .topLeading)
                .liquidGlass(
                    .regular,
                    in: RoundedRectangle(cornerRadius: ShelfBubbleMetrics.bubbleCornerRadius, style: .continuous)
                )
        }
        .position(
            x: state.bubbleFrame.midX - state.windowFrame.minX,
            y: state.bubbleFrame.midY - state.windowFrame.minY
        )
    }

    @ViewBuilder
    private var shelfContent: some View {
        if ShelfBubbleMetrics.needsScrolling(itemCount: state.layout.shelfItems.count) {
            ScrollView(.vertical, showsIndicators: false) {
                shelfRows
            }
            .frame(height: ShelfBubbleMetrics.contentHeight(rows: ShelfBubbleMetrics.maxVisibleRows))
        } else {
            shelfRows
        }
    }

    private var shelfRows: some View {
        VStack(alignment: .leading, spacing: ShelfBubbleMetrics.rowSpacing) {
            ForEach(state.layout.shelfItems) { item in
                ShelfItemButton(
                    item: item,
                    onLeftClick: { state.onActivate?(item, .left) },
                    onRightClick: { state.onActivate?(item, .right) }
                )
            }
        }
    }

    /// Bubble grows out of the status item (Liquid Glass "materialise from the control" motion).
    private var bubbleTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let anchor = bubbleScaleAnchor
        return .asymmetric(
            insertion: .scale(scale: 0.82, anchor: anchor)
                .combined(with: .opacity)
                .combined(with: .offset(y: -6)),
            removal: .scale(scale: 0.92, anchor: anchor)
                .combined(with: .opacity)
        )
    }

    private var bubbleScaleAnchor: UnitPoint {
        guard let anchorFrame = state.anchorFrame, state.bubbleFrame.width > 0 else { return .top }
        let x = (anchorFrame.midX - state.bubbleFrame.minX) / state.bubbleFrame.width
        return UnitPoint(x: min(max(x, 0), 1), y: 0)
    }

    private var maskOpacity: Double {
        min(max(state.appearance.collapsedMaskOpacity, 0.5), 1.0)
    }

    private func position(for rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.midX - state.windowFrame.minX,
            y: rect.midY - state.windowFrame.minY
        )
    }
}

private struct MaskedMenuBarItemView: View {
    let maskOpacity: Double

    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            // The opaque base is what actually hides the icon; glass only adds the sheen on top.
            shape.fill(Color.black.opacity(maskOpacity))
            if maskOpacity < 1.0 {
                shape.fill(.ultraThinMaterial.opacity(0.14))
            }
        }
        .liquidGlassHighlight(in: shape)
    }
}

private struct ShelfItemRow: View {
    let item: ManagedMenuBarItem
    let isHovered: Bool
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 22, height: 22)
                .frame(width: ShelfBubbleMetrics.iconTileSize, height: ShelfBubbleMetrics.iconTileSize)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: ShelfBubbleMetrics.iconTileCornerRadius, style: .continuous)
                )

            Text(item.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, (ShelfBubbleMetrics.rowHeight - ShelfBubbleMetrics.iconTileSize) / 2)
        .frame(height: ShelfBubbleMetrics.rowHeight)
        .background(
            Color.primary.opacity(isPressed ? 0.14 : (isHovered ? 0.09 : 0)),
            in: RoundedRectangle(cornerRadius: ShelfBubbleMetrics.rowCornerRadius, style: .continuous)
        )
        .scaleEffect(isPressed ? 0.97 : 1)
    }

    @ViewBuilder
    private var iconView: some View {
        if let image = item.snapshot?.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShelfItemButton: View {
    let item: ManagedMenuBarItem
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ShelfItemRow(item: item, isHovered: isHovered, isPressed: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: ShelfBubbleMetrics.rowCornerRadius, style: .continuous))
            .overlay {
                MouseClickCapture(
                    onLeftClick: onLeftClick,
                    onRightClick: onRightClick,
                    onHoverChanged: { isHovered = $0 },
                    onPressChanged: { isPressed = $0 }
                )
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.22, bounce: 0.3), value: isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.displayName)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onLeftClick() }
    }
}

private struct MouseClickCapture: NSViewRepresentable {
    let onLeftClick: () -> Void
    let onRightClick: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onPressChanged: (Bool) -> Void

    func makeNSView(context: Context) -> MouseClickCaptureView {
        let view = MouseClickCaptureView()
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: MouseClickCaptureView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: MouseClickCaptureView) {
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        view.onHoverChanged = onHoverChanged
        view.onPressChanged = onPressChanged
    }
}

private final class MouseClickCaptureView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onPressChanged: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    // The overlay is a non-activating panel; without this the first click is swallowed.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
        onPressChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onPressChanged?(true)
    }

    override func rightMouseDown(with event: NSEvent) {
        onPressChanged?(true)
    }

    override func mouseUp(with event: NSEvent) {
        onPressChanged?(false)
        guard isInside(event) else { return }
        onLeftClick?()
    }

    override func rightMouseUp(with event: NSEvent) {
        onPressChanged?(false)
        guard isInside(event) else { return }
        onRightClick?()
    }

    private func isInside(_ event: NSEvent) -> Bool {
        bounds.contains(convert(event.locationInWindow, from: nil))
    }
}
