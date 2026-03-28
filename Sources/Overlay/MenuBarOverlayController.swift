import AppKit
import Core
import LayoutEngine
import Localization
import SwiftUI

@MainActor
public final class MenuBarOverlayController {
    public final class State: ObservableObject {
        @Published var layout = MenuBarLayoutResult(visibleItems: [], maskedItems: [], shelfItems: [])
        @Published var appearance = AppearanceSettings()
        @Published var revealState: RevealState = .collapsed
        @Published var windowFrame: CGRect = .zero
        @Published var screenFrame: CGRect = .zero
        @Published var anchorFrame: CGRect?
        @Published var temporarilyRevealed: Set<String> = []

        var onActivate: ((ManagedMenuBarItem) -> Void)?
        var onOpenSettings: (() -> Void)?
        var onMove: ((IndexSet, Int) -> Void)?
    }

    private let state = State()
    private var window: NSPanel?

    public init() {}

    public func update(
        on screen: NSScreen?,
        revealState: RevealState,
        layout: MenuBarLayoutResult,
        appearance: AppearanceSettings,
        anchorFrame: CGRect?,
        onActivate: @escaping (ManagedMenuBarItem) -> Void,
        onOpenSettings: @escaping () -> Void,
        onMove: @escaping (IndexSet, Int) -> Void
    ) {
        guard let screen else {
            hide()
            return
        }

        let windowFrame = CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - 96,
            width: screen.frame.width,
            height: 96
        )

        state.layout = layout
        state.appearance = appearance
        state.revealState = revealState
        state.windowFrame = windowFrame
        state.screenFrame = screen.frame
        state.anchorFrame = anchorFrame
        state.onActivate = onActivate
        state.onOpenSettings = onOpenSettings
        state.onMove = onMove

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
        if layout.maskedItems.isEmpty && layout.shelfItems.isEmpty {
            window?.orderOut(nil)
        } else {
            window?.orderFrontRegardless()
        }
    }

    public func temporarilyReveal(itemID: String, duration: TimeInterval = 0.8) {
        state.temporarilyRevealed.insert(itemID)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak state] in
            state?.temporarilyRevealed.remove(itemID)
        }
    }

    public func hide() {
        window?.orderOut(nil)
    }
}

private struct OverlayRootView: View {
    @ObservedObject var state: MenuBarOverlayController.State
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(state.layout.maskedItems) { item in
                if !state.temporarilyRevealed.contains(item.id) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial.opacity(state.appearance.collapsedMaskOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
                        )
                        .frame(width: max(item.descriptor.bounds.width, 18), height: max(item.descriptor.bounds.height, 18))
                        .position(position(for: item.descriptor.bounds))
                }
            }

            if state.revealState == .expanded, !state.layout.shelfItems.isEmpty {
                shelfStrip
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }

    private var shelfStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: state.appearance.itemSpacing) {
                ForEach(Array(state.layout.shelfItems.enumerated()), id: \.element.id) { _, item in
                    ShelfItemView(item: item, showLabel: state.appearance.showLabels)
                        .onTapGesture {
                            state.onActivate?(item)
                        }
                        .draggable(item.id)
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedID = items.first,
                                  let fromIndex = state.layout.shelfItems.firstIndex(where: { $0.id == draggedID }),
                                  let toIndex = state.layout.shelfItems.firstIndex(where: { $0.id == item.id }) else {
                                return false
                            }
                            state.onMove?(IndexSet(integer: fromIndex), toIndex > fromIndex ? toIndex + 1 : toIndex)
                            return true
                        }
                }
            }
            .padding(.horizontal, state.appearance.stripPadding)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )

            Button(L10n.string("action.open_settings")) {
                state.onOpenSettings?()
            }
            .buttonStyle(.link)
            .font(.system(size: 11, weight: .medium))
            .padding(.top, 6)
        }
        .position(x: stripX, y: 48)
        .animation(.easeInOut(duration: state.appearance.animationDuration), value: state.layout.shelfItems.map(\.id))
    }

    private var stripX: CGFloat {
        let totalWidth = state.layout.shelfItems.reduce(CGFloat(20), { partial, item in
            partial + max(item.snapshot?.size.width ?? item.descriptor.bounds.width, 18) + state.appearance.itemSpacing
        })
        let defaultX = min(max(totalWidth / 2 + 20, 80), state.windowFrame.width - max(totalWidth / 2 + 20, 80))
        guard let anchorFrame = state.anchorFrame else { return defaultX }
        let anchored = anchorFrame.midX - state.windowFrame.minX
        let inset = max(totalWidth / 2 + 20, 80)
        return min(max(anchored, inset), state.windowFrame.width - inset)
    }

    private func position(for rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.midX - state.windowFrame.minX,
            y: rect.midY - state.windowFrame.minY
        )
    }
}

private struct ShelfItemView: View {
    let item: ManagedMenuBarItem
    let showLabel: Bool

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image = item.snapshot?.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "menubar.rectangle")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(width: max(item.snapshot?.size.width ?? item.descriptor.bounds.width, 18), height: 18)

            if showLabel {
                Text(item.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
