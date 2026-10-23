import AppKit
import Core
import Localization
import SwiftUI
import UniformTypeIdentifiers

struct ItemsSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var draggingItemID: String?
    @State private var shelfOrder: [ManagedMenuBarItem]

    init(model: AppModel) {
        self.model = model
        _shelfOrder = State(initialValue: model.managedItems.filter { $0.rule.kind == .hiddenInBar })
    }

    private var hiddenItems: [ManagedMenuBarItem] {
        model.managedItems.filter { $0.rule.kind == .hiddenInBar }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    TextField(
                        L10n.string("search.menu_items"),
                        text: $model.searchText,
                        prompt: Text(L10n.string("search.menu_items"))
                    )
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()

                    if model.isRescanning {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button(L10n.string("action.rescan")) {
                        model.rescan()
                    }
                    .disabled(model.isRescanning)
                }

                HStack(spacing: 16) {
                    MetricView(label: L10n.string("metric.detected"), value: model.managedItems.count)
                    MetricView(label: L10n.string("metric.shelved"), value: hiddenItems.count)
                    MetricView(
                        label: L10n.string("metric.ax_press"),
                        value: model.managedItems.filter { $0.descriptor.capabilities.canPerformPress }.count
                    )
                    MetricView(
                        label: L10n.string("metric.needs_real_click"),
                        value: model.managedItems.filter { $0.descriptor.capabilities.requiresRealHitTarget }.count
                    )
                }
            }

            SettingsSection(
                title: L10n.string("section.detected_items.title"),
                subtitle: L10n.string("section.detected_items.subtitle")
            ) {
                ForEach(model.filteredManagedItems) { item in
                    ManagedItemRow(model: model, item: item)
                }
            }

            SettingsSection(
                title: L10n.string("section.shelf_order.title"),
                subtitle: L10n.string("section.shelf_order.subtitle")
            ) {
                if hiddenItems.isEmpty {
                    Text(L10n.string("empty.shelf_order"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(shelfOrder.enumerated()), id: \.element.id) { index, item in
                        shelfRow(index: index, item: item)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: hiddenItems) { _, newValue in
            if draggingItemID == nil {
                shelfOrder = newValue
            }
        }
    }

    private func shelfRow(index: Int, item: ManagedMenuBarItem) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            MenuExtraPreview(item: item, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                Text(item.descriptor.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .opacity(draggingItemID == item.id ? 0 : 1)
        .onDrag {
            draggingItemID = item.id
            return NSItemProvider(object: item.id as NSString)
        }
        .onDrop(
            of: [.text],
            delegate: ShelfDropDelegate(
                item: item,
                shelfOrder: $shelfOrder,
                draggingItemID: $draggingItemID,
                model: model
            )
        )
    }
}

private struct ShelfDropDelegate: DropDelegate {
    let item: ManagedMenuBarItem
    @Binding var shelfOrder: [ManagedMenuBarItem]
    @Binding var draggingItemID: String?
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let draggingItemID,
              draggingItemID != item.id,
              let fromIndex = shelfOrder.firstIndex(where: { $0.id == draggingItemID }),
              let toIndex = shelfOrder.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex
        else {
            return
        }

        withAnimation {
            shelfOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingItemID = nil }
        let newOrder = shelfOrder.map(\.id)
        model.setShelfOrder(newOrder)
        return true
    }
}

private struct ManagedItemRow: View {
    @ObservedObject var model: AppModel
    let item: ManagedMenuBarItem

    private var canPress: Bool { item.descriptor.capabilities.canPerformPress }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MenuExtraPreview(item: item)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                    Text(item.descriptor.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(
                    title: canPress ? L10n.string("badge.ax_press") : L10n.string("badge.real_click"),
                    tint: canPress ? .mint : .orange
                )
                InfoTooltipButton(
                    tooltip: canPress ? L10n.string("badge.ax_press.tooltip") : L10n.string("badge.real_click.tooltip")
                )
            }

            HStack(alignment: .top, spacing: 12) {
                field(L10n.string("field.visibility")) {
                    Picker(L10n.string("field.visibility"), selection: Binding(
                        get: { item.rule.kind },
                        set: { model.updateRule(itemID: item.id, kind: $0) }
                    )) {
                        ForEach(VisibilityRuleKind.allCases) { kind in
                            Text(kind.localizedTitle).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                field(L10n.string("field.interaction")) {
                    Picker(L10n.string("field.interaction"), selection: Binding(
                        get: { item.rule.interactionMode },
                        set: { model.updateInteractionMode(itemID: item.id, mode: $0) }
                    )) {
                        ForEach(ProxyInteractionMode.allCases) { mode in
                            Text(mode.localizedTitle).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                field(L10n.string("field.custom_name")) {
                    TextField(
                        L10n.string("field.custom_name"),
                        text: Binding(
                            get: { item.rule.customName ?? "" },
                            set: { model.updateCustomName(itemID: item.id, customName: $0) }
                        ),
                        prompt: Text(L10n.string("field.custom_name.placeholder"))
                    )
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func field<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
