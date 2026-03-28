import AppKit
import Carbon
import Core
import Localization
import SharedUI
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        ZStack {
            GlassBackdrop()

            HStack(spacing: 22) {
                SettingsSidebar(model: model)
                    .frame(width: 248)

                settingsDetail
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(L10n.string("alert.error.title"), isPresented: .constant(model.lastErrorMessage != nil), actions: {
            Button(L10n.string("action.ok")) { model.lastErrorMessage = nil }
        }, message: {
            Text(model.lastErrorMessage ?? "")
        })
    }

    private var settingsDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.selectedTab.title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(detailSubtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Group {
                switch model.selectedTab {
                case .items:
                    ItemsSettingsView(model: model)
                case .appearance:
                    AppearanceSettingsView(model: model)
                case .shortcuts:
                    ShortcutSettingsView(model: model)
                case .general:
                    GeneralSettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .glassPanel(cornerRadius: 34)
    }

    private var detailSubtitle: String {
        switch model.selectedTab {
        case .items:
            L10n.string("settings.subtitle.items")
        case .appearance:
            L10n.string("settings.subtitle.appearance")
        case .shortcuts:
            L10n.string("settings.subtitle.shortcuts")
        case .general:
            L10n.string("settings.subtitle.general")
        }
    }
}

private struct SettingsSidebar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("app.name"))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .allowsTightening(true)
                    Text(L10n.string("sidebar.tagline"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        model.selectedTab = tab
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tab.symbolName)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Text(tab.caption)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(selectionBackground(for: tab))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("sidebar.snapshot"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                MetricChip(label: L10n.string("metric.detected"), value: "\(model.managedItems.count)", tint: .white.opacity(0.12))
                MetricChip(label: L10n.string("metric.shelved"), value: "\(model.managedItems.filter { $0.rule.kind == .hiddenInBar }.count)", tint: Color.cyan.opacity(0.16))
                MetricChip(label: L10n.string("metric.visible"), value: "\(model.managedItems.filter { $0.rule.kind == .alwaysVisible }.count)", tint: Color.blue.opacity(0.14))
            }
        }
        .padding(20)
        .glassPanel(cornerRadius: 30)
    }

    @ViewBuilder
    private func selectionBackground(for tab: SettingsTab) -> some View {
        if model.selectedTab == tab {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
        }
    }
}

private struct ItemsSettingsView: View {
    @ObservedObject var model: AppModel

    private var hiddenItems: [ManagedMenuBarItem] {
        model.managedItems.filter { $0.rule.kind == .hiddenInBar }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    searchField
                    Button(L10n.string("action.rescan")) {
                        model.rescan()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }

                HStack(spacing: 10) {
                    MetricChip(label: L10n.string("metric.detected"), value: "\(model.managedItems.count)", tint: .white.opacity(0.1))
                    MetricChip(label: L10n.string("metric.ax_press"), value: "\(model.managedItems.filter { $0.descriptor.capabilities.canPerformPress }.count)", tint: Color.mint.opacity(0.16))
                    MetricChip(label: L10n.string("metric.needs_real_click"), value: "\(model.managedItems.filter { $0.descriptor.capabilities.requiresRealHitTarget }.count)", tint: Color.orange.opacity(0.16))
                }

                GlassSectionCard(title: L10n.string("section.detected_items.title"), subtitle: L10n.string("section.detected_items.subtitle")) {
                    VStack(spacing: 12) {
                        ForEach(model.filteredManagedItems) { item in
                            ManagedItemCard(model: model, item: item)
                        }
                    }
                }

                GlassSectionCard(title: L10n.string("section.shelf_order.title"), subtitle: L10n.string("section.shelf_order.subtitle")) {
                    if hiddenItems.isEmpty {
                        EmptyStateRow(message: L10n.string("empty.shelf_order"))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(hiddenItems.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 14) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 26)

                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.displayName)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        Text(item.descriptor.bundleID)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    orderButton(systemName: "arrow.up", disabled: index == 0) {
                                        model.moveShelfItem(item.id, direction: .up)
                                    }
                                    orderButton(systemName: "arrow.down", disabled: index == hiddenItems.count - 1) {
                                        model.moveShelfItem(item.id, direction: .down)
                                    }
                                }
                                .padding(14)
                                .softRowBackground()
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.string("search.menu_items"), text: $model.searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .softRowBackground(cornerRadius: 22)
    }

    private func orderButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(.white.opacity(disabled ? 0.04 : 0.1))
        )
        .foregroundStyle(disabled ? Color.secondary.opacity(0.35) : Color.primary)
        .disabled(disabled)
    }
}

private struct ManagedItemCard: View {
    @ObservedObject var model: AppModel
    let item: ManagedMenuBarItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                MenuExtraPreview(item: item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(item.descriptor.bundleID)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(
                    title: item.descriptor.capabilities.canPerformPress ? L10n.string("badge.ax_press") : L10n.string("badge.real_click"),
                    tint: item.descriptor.capabilities.canPerformPress ? .mint : .orange
                )
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.visibility"))
                        .fieldLabelStyle()
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

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.interaction"))
                        .fieldLabelStyle()
                    Picker(L10n.string("field.interaction"), selection: Binding(
                                    get: { item.rule.interactionMode },
                                    set: { model.updateInteractionMode(itemID: item.id, mode: $0) }
                                )) {
                        Text(ProxyInteractionMode.proxyPreferred.localizedTitle).tag(ProxyInteractionMode.proxyPreferred)
                        Text(ProxyInteractionMode.revealBeforeAction.localizedTitle).tag(ProxyInteractionMode.revealBeforeAction)
                        Text(ProxyInteractionMode.realClickOnly.localizedTitle).tag(ProxyInteractionMode.realClickOnly)
                                }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("field.custom_name"))
                        .fieldLabelStyle()
                    TextField(
                        L10n.string("field.custom_name.placeholder"),
                        text: Binding(
                            get: { item.rule.customName ?? "" },
                            set: { model.updateCustomName(itemID: item.id, customName: $0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .softRowBackground(cornerRadius: 14)
                }
            }
        }
        .padding(16)
        .softRowBackground(cornerRadius: 24)
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSectionCard(title: L10n.string("section.strip_presentation.title"), subtitle: L10n.string("section.strip_presentation.subtitle")) {
                    VStack(spacing: 14) {
                        GlassToggleRow(
                            title: L10n.string("field.show_labels"),
                            detail: L10n.string("field.show_labels.detail")
                        ) {
                            Toggle("", isOn: Binding(
                                get: { model.settings.appearance.showLabels },
                                set: { value in model.updateAppearance { $0.showLabels = value } }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }

                        GlassSliderRow(
                            title: L10n.string("field.item_spacing"),
                            detail: L10n.string("field.item_spacing.detail"),
                            valueText: String(format: "%.0f pt", model.settings.appearance.itemSpacing)
                        ) {
                            Slider(
                                value: Binding(
                                    get: { model.settings.appearance.itemSpacing },
                                    set: { value in model.updateAppearance { $0.itemSpacing = value } }
                                ),
                                in: 4...20
                            )
                        }

                        GlassSliderRow(
                            title: L10n.string("field.mask_opacity"),
                            detail: L10n.string("field.mask_opacity.detail"),
                            valueText: String(format: "%.2f", model.settings.appearance.collapsedMaskOpacity)
                        ) {
                            Slider(
                                value: Binding(
                                    get: { model.settings.appearance.collapsedMaskOpacity },
                                    set: { value in model.updateAppearance { $0.collapsedMaskOpacity = value } }
                                ),
                                in: 0.2...1.0
                            )
                        }

                        GlassSliderRow(
                            title: L10n.string("field.animation"),
                            detail: L10n.string("field.animation.detail"),
                            valueText: String(format: "%.2fs", model.settings.appearance.animationDuration)
                        ) {
                            Slider(
                                value: Binding(
                                    get: { model.settings.appearance.animationDuration },
                                    set: { value in model.updateAppearance { $0.animationDuration = value } }
                                ),
                                in: 0.05...0.6
                            )
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ShortcutSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSectionCard(title: L10n.string("section.global_shortcut.title"), subtitle: L10n.string("section.global_shortcut.subtitle")) {
                    VStack(spacing: 14) {
                        GlassToggleRow(
                            title: L10n.string("field.enable_global_shortcut"),
                            detail: L10n.string("field.enable_global_shortcut.detail")
                        ) {
                            Toggle("", isOn: Binding(
                                get: { model.settings.hotkey.isEnabled },
                                set: { enabled in
                                    var config = model.settings.hotkey
                                    config.isEnabled = enabled
                                    model.updateHotkey(config)
                                }
                            ))
                            .labelsHidden()
                        }

                        GlassValueRow(
                            title: L10n.string("field.current_shortcut"),
                            detail: L10n.string("field.current_shortcut.detail"),
                            value: HotkeyFormatter.string(for: model.settings.hotkey)
                        )

                        GlassPickerRow(title: L10n.string("field.preset"), detail: L10n.string("field.preset.detail")) {
                            Picker(L10n.string("field.preset"), selection: Binding(
                                get: { model.settings.hotkey.keyCode },
                                set: { keyCode in
                                    var config = model.settings.hotkey
                                    config.keyCode = keyCode
                                    model.updateHotkey(config)
                                }
                            )) {
                                Text("⌘⌥M").tag(UInt32(46))
                                Text("⌘⌥B").tag(UInt32(11))
                                Text("⌘⌥F").tag(UInt32(3))
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        GlassPickerRow(title: L10n.string("field.modifiers"), detail: L10n.string("field.modifiers.detail")) {
                            Picker(L10n.string("field.modifiers"), selection: Binding(
                                get: { model.settings.hotkey.modifiers },
                                set: { modifiers in
                                    var config = model.settings.hotkey
                                    config.modifiers = modifiers
                                    model.updateHotkey(config)
                                }
                            )) {
                                Text("⌘⌥").tag(UInt32(cmdKey | optionKey))
                                Text("⌘⌃").tag(UInt32(cmdKey | controlKey))
                                Text("⌘⇧").tag(UInt32(cmdKey | shiftKey))
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GlassSectionCard(title: L10n.string("section.permissions.title"), subtitle: L10n.string("section.permissions.subtitle")) {
                    VStack(spacing: 12) {
                        PermissionRow(
                            title: L10n.string("permission.accessibility.title"),
                            detail: L10n.string("permission.accessibility.detail"),
                            granted: model.permissionsSnapshot.accessibilityGranted,
                            actionTitle: L10n.string("action.grant_access")
                        ) {
                            model.requestAccessibilityPermission()
                        }

                        PermissionRow(
                            title: L10n.string("permission.screen_recording.title"),
                            detail: L10n.string("permission.screen_recording.detail"),
                            granted: model.permissionsSnapshot.screenRecordingGranted,
                            actionTitle: L10n.string("action.grant_access")
                        ) {
                            model.requestScreenRecordingPermission()
                        }
                    }
                }

                GlassSectionCard(title: L10n.string("section.language.title"), subtitle: L10n.string("section.language.subtitle")) {
                    GlassPickerRow(title: L10n.string("field.language"), detail: L10n.string("field.language.detail")) {
                        Picker(L10n.string("field.language"), selection: Binding(
                            get: { model.preferredLanguage },
                            set: { model.updatePreferredLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.pickerTitle).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                GlassSectionCard(title: L10n.string("section.startup.title"), subtitle: L10n.string("section.startup.subtitle")) {
                    GlassToggleRow(
                        title: L10n.string("field.launch_at_login"),
                        detail: L10n.string("field.launch_at_login.detail")
                    ) {
                        Toggle("", isOn: Binding(
                            get: { model.settings.launchAtLogin },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                    }
                }

                GlassSectionCard(title: L10n.string("section.diagnostics.title"), subtitle: L10n.string("section.diagnostics.subtitle")) {
                    VStack(spacing: 12) {
                        GlassValueRow(title: L10n.string("diagnostic.detected_items"), detail: L10n.string("diagnostic.detected_items.detail"), value: "\(model.managedItems.count)")
                        GlassValueRow(title: L10n.string("diagnostic.hidden_in_shelf"), detail: L10n.string("diagnostic.hidden_in_shelf.detail"), value: "\(model.managedItems.filter { $0.rule.kind == .hiddenInBar }.count)")
                        GlassValueRow(title: L10n.string("diagnostic.current_state"), detail: L10n.string("diagnostic.current_state.detail"), value: model.revealState.localizedTitle)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(granted ? Color.mint.opacity(0.16) : Color.orange.opacity(0.14))
                Image(systemName: granted ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                StatusBadge(title: granted ? L10n.string("state.granted") : L10n.string("state.required"), tint: granted ? .mint : .orange)
                if !granted {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(16)
        .softRowBackground(cornerRadius: 22)
    }
}

struct OnboardingRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("onboarding.title"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(L10n.string("onboarding.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    PermissionCard(
                        icon: "figure.wave.circle.fill",
                        title: L10n.string("permission.accessibility.title"),
                        detail: L10n.string("permission.accessibility.onboarding_detail"),
                        granted: model.permissionsSnapshot.accessibilityGranted,
                        buttonTitle: L10n.string("action.grant_accessibility")
                    ) {
                        model.requestAccessibilityPermission()
                    }

                    PermissionCard(
                        icon: "rectangle.on.rectangle.circle.fill",
                        title: L10n.string("permission.screen_recording.title"),
                        detail: L10n.string("permission.screen_recording.onboarding_detail"),
                        granted: model.permissionsSnapshot.screenRecordingGranted,
                        buttonTitle: L10n.string("action.grant_screen_recording")
                    ) {
                        model.requestScreenRecordingPermission()
                    }
                }

                if !allPermissionsGranted {
                    Text(L10n.string("onboarding.refresh_hint"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .softRowBackground(cornerRadius: 18)
                }

                HStack {
                    Button(L10n.string("action.refresh_status")) {
                        model.refreshPermissions()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                    Spacer()

                    Button(allPermissionsGranted ? L10n.string("action.continue") : L10n.string("action.continue_anyway")) {
                        model.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
            }
            .padding(28)
            .glassPanel(cornerRadius: 34)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var allPermissionsGranted: Bool {
        model.permissionsSnapshot.accessibilityGranted && model.permissionsSnapshot.screenRecordingGranted
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Spacer()
                    StatusBadge(title: granted ? L10n.string("state.granted") : L10n.string("state.required"), tint: granted ? .mint : .orange)
                }

                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if !granted {
                    Button(buttonTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(18)
        .softRowBackground(cornerRadius: 26)
    }
}

private struct MenuExtraPreview: View {
    let item: ManagedMenuBarItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.12))

            if let image = item.snapshot?.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: 52, height: 42)
    }
}

private struct GlassSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(18)
        .glassPanel(cornerRadius: 28, tint: .white.opacity(0.08))
    }
}

private struct GlassToggleRow<Accessory: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            accessory
        }
        .padding(16)
        .softRowBackground(cornerRadius: 22)
    }
}

private struct GlassSliderRow<Accessory: View>: View {
    let title: String
    let detail: String
    let valueText: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .softRowBackground(cornerRadius: 12)
            }
            accessory
        }
        .padding(16)
        .softRowBackground(cornerRadius: 22)
    }
}

private struct GlassPickerRow<Accessory: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            accessory
        }
        .padding(16)
        .softRowBackground(cornerRadius: 22)
    }
}

private struct GlassValueRow: View {
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .softRowBackground(cornerRadius: 14)
        }
        .padding(16)
        .softRowBackground(cornerRadius: 22)
    }
}

private struct MetricChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(tint)
        )
    }
}

private struct StatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
    }
}

private struct EmptyStateRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .softRowBackground(cornerRadius: 22)
    }
}

private struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                    Color(red: 0.74, green: 0.84, blue: 0.96).opacity(0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.35))
                .blur(radius: 80)
                .frame(width: 260, height: 260)
                .offset(x: -180, y: -160)

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .blur(radius: 100)
                .frame(width: 320, height: 320)
                .offset(x: 230, y: 180)

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.4))
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat, tint: Color = .white.opacity(0.1)) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 18)
            )
    }

    func softRowBackground(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
                    )
            )
    }

    func fieldLabelStyle() -> some View {
        self
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

private extension SettingsTab {
    var symbolName: String {
        switch self {
        case .items: "rectangle.3.group.bubble"
        case .appearance: "swatchpalette"
        case .shortcuts: "command"
        case .general: "gearshape"
        }
    }

    var caption: String {
        switch self {
        case .items: L10n.string("sidebar.caption.items")
        case .appearance: L10n.string("sidebar.caption.appearance")
        case .shortcuts: L10n.string("sidebar.caption.shortcuts")
        case .general: L10n.string("sidebar.caption.general")
        }
    }
}

private extension VisibilityRuleKind {
    var localizedTitle: String {
        switch self {
        case .alwaysVisible: L10n.string("visibility.always_visible")
        case .hiddenInBar: L10n.string("visibility.hidden_in_shelf")
        case .alwaysHidden: L10n.string("visibility.always_hidden")
        }
    }
}

private extension ProxyInteractionMode {
    var localizedTitle: String {
        switch self {
        case .proxyPreferred: L10n.string("interaction.proxy_first")
        case .revealBeforeAction: L10n.string("interaction.reveal_before_action")
        case .realClickOnly: L10n.string("interaction.real_click_only")
        }
    }
}

private extension RevealState {
    var localizedTitle: String {
        switch self {
        case .collapsed: L10n.string("state.collapsed")
        case .expanded: L10n.string("state.expanded")
        }
    }
}

private extension AppLanguage {
    var localizedTitle: String {
        switch self {
        case .system: L10n.string("language.system")
        case .english: L10n.string("language.en")
        case .simplifiedChinese: L10n.string("language.zh-Hans")
        case .traditionalChinese: L10n.string("language.zh-Hant")
        case .japanese: L10n.string("language.ja")
        }
    }

    var pickerTitle: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        }
    }
}
