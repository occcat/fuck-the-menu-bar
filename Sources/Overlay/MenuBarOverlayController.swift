import AppKit
import Core
import LayoutEngine
import Localization
import SwiftUI

@MainActor
public final class MenuBarOverlayController {
    fileprivate static let collapsedPanelHeight: CGFloat = 44
    fileprivate static let expandedPanelPadding: CGFloat = 14
    fileprivate static let expandedBubbleTopInset: CGFloat = 52
    fileprivate static let expandedBubbleBottomInset: CGFloat = 18
    fileprivate static let bubbleWidth: CGFloat = 260
    fileprivate static let bubbleRowHeight: CGFloat = 48
    fileprivate static let bubbleSpacing: CGFloat = 8

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
        let panelHeight = panelHeight(
            for: layout,
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
            layout: layout,
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
            let collapseDelay = max(appearance.animationDuration, 0.18)
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.state.revealState == .collapsed else { return }
                let collapsedFrame = CGRect(
                    x: screen.frame.minX,
                    y: screen.frame.maxY - Self.collapsedPanelHeight,
                    width: screen.frame.width,
                    height: Self.collapsedPanelHeight
                )
                self.state.windowFrame = collapsedFrame
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

    private func panelHeight(
        for layout: MenuBarLayoutResult,
        revealState: RevealState,
        screenFrame: CGRect,
        anchorFrame: CGRect?,
        bubbleAnchorGap: CGFloat
    ) -> CGFloat {
        guard revealState == .expanded, !layout.shelfItems.isEmpty else {
            return Self.collapsedPanelHeight
        }

        let rows = min(max(layout.shelfItems.count, 1), 5)
        let bubbleHeight =
            CGFloat(rows) * Self.bubbleRowHeight +
            CGFloat(max(rows - 1, 0)) * Self.bubbleSpacing +
            Self.expandedPanelPadding * 2
        let minimumMenuBarClearance = min(Self.expandedBubbleTopInset, 24)
        let topClearance: CGFloat
        if let anchorFrame {
            topClearance = screenFrame.maxY - anchorFrame.minY + bubbleAnchorGap
        } else {
            topClearance = max(bubbleAnchorGap, minimumMenuBarClearance)
        }
        return max(
            Self.collapsedPanelHeight,
            bubbleHeight + topClearance + Self.expandedBubbleBottomInset
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

        let rows = min(max(layout.shelfItems.count, 1), 5)
        let bubbleHeight =
            CGFloat(rows) * Self.bubbleRowHeight +
            CGFloat(max(rows - 1, 0)) * Self.bubbleSpacing +
            Self.expandedPanelPadding * 2
        let maxX = windowFrame.maxX - Self.expandedPanelPadding - Self.bubbleWidth
        let minX = windowFrame.minX + Self.expandedPanelPadding
        let anchoredMidX = anchorFrame?.midX ?? windowFrame.midX
        let originX = min(max(anchoredMidX - (Self.bubbleWidth / 2), minX), maxX)
        let minimumMenuBarClearance = min(Self.expandedBubbleTopInset, 24)
        let topClearance: CGFloat
        if let anchorFrame {
            topClearance = windowFrame.maxY - anchorFrame.minY + bubbleAnchorGap
        } else {
            topClearance = max(bubbleAnchorGap, minimumMenuBarClearance)
        }
        let preferredBubbleMaxY = windowFrame.maxY - topClearance
        let minimumBubbleMaxY = windowFrame.minY + bubbleHeight + Self.expandedBubbleBottomInset
        let maximumBubbleMaxY = windowFrame.maxY - minimumMenuBarClearance
        let bubbleMaxY = min(max(preferredBubbleMaxY, minimumBubbleMaxY), maximumBubbleMaxY)
        let originY = bubbleMaxY - bubbleHeight

        return CGRect(x: originX, y: originY, width: Self.bubbleWidth, height: bubbleHeight)
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
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .scale(scale: 0.94)).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .scale(scale: 0.98)).combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: state.revealState)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: state.layout.shelfItems.map(\.id))
    }

    private var shelfBubble: some View {
        VStack(alignment: .leading, spacing: MenuBarOverlayController.bubbleSpacing) {
            ForEach(state.layout.shelfItems) { item in
                ShelfItemButton(
                    item: item,
                    onLeftClick: { state.onActivate?(item, .left) },
                    onRightClick: { state.onActivate?(item, .right) }
                )
            }
        }
        .padding(MenuBarOverlayController.expandedPanelPadding)
        .frame(width: state.bubbleFrame.width, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .position(
            x: state.bubbleFrame.midX - state.windowFrame.minX,
            y: state.bubbleFrame.midY - state.windowFrame.minY
        )
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
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(maskOpacity))
            if maskOpacity < 1.0 {
                shape.fill(.ultraThinMaterial.opacity(0.14))
            }
            shape.stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        }
    }
}

private struct ShelfItemRow: View {
    let item: ManagedMenuBarItem

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 24, height: 24)
                .padding(8)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(item.displayName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var iconView: some View {
        if let image = item.snapshot?.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Text("❌")
                .font(.system(size: 18))
        }
    }
}

private struct ShelfItemButton: View {
    let item: ManagedMenuBarItem
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    var body: some View {
        ShelfItemRow(item: item)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                MouseClickCapture(onLeftClick: onLeftClick, onRightClick: onRightClick)
            }
            .accessibilityLabel(item.displayName)
    }
}

private struct MouseClickCapture: NSViewRepresentable {
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> MouseClickCaptureView {
        let view = MouseClickCaptureView()
        view.onLeftClick = onLeftClick
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: MouseClickCaptureView, context: Context) {
        nsView.onLeftClick = onLeftClick
        nsView.onRightClick = onRightClick
    }
}

private final class MouseClickCaptureView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        onLeftClick?()
    }

    override func rightMouseUp(with event: NSEvent) {
        onRightClick?()
    }
}
