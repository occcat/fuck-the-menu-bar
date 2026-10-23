import Core
import Localization
import SwiftUI

/// `showLabels` / `itemSpacing` / `stripPadding` are intentionally not exposed: the vertical
/// shelf bubble does not consume them (S4 in docs/LIQUID_GLASS_REFACTOR.md). The fields stay in
/// `AppearanceSettings` so existing config files round-trip unchanged.
struct AppearanceSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            SettingsSection(
                title: L10n.string("section.strip_presentation.title"),
                subtitle: L10n.string("section.strip_presentation.subtitle")
            ) {
                sliderRow(
                    title: L10n.string("field.mask_opacity"),
                    detail: L10n.string("field.mask_opacity.detail"),
                    value: binding(\.collapsedMaskOpacity),
                    range: 0.5...1.0,
                    valueText: String(format: "%.2f", model.settings.appearance.collapsedMaskOpacity)
                )

                sliderRow(
                    title: L10n.string("field.animation"),
                    detail: L10n.string("field.animation.detail"),
                    value: binding(\.animationDuration),
                    range: 0.05...0.6,
                    valueText: String(format: "%.2fs", model.settings.appearance.animationDuration)
                )

                sliderRow(
                    title: L10n.string("field.bubble_offset"),
                    detail: L10n.string("field.bubble_offset.detail"),
                    value: binding(\.bubbleVerticalOffset),
                    range: 30...120,
                    valueText: String(format: "%.0f pt", model.settings.appearance.bubbleVerticalOffset)
                )
            }
        }
        .formStyle(.grouped)
    }

    private func sliderRow(
        title: String,
        detail: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        SettingsRow(title: title, detail: detail) {
            HStack(spacing: 10) {
                Slider(value: value, in: range)
                    .labelsHidden()
                    .frame(width: 180)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppearanceSettings, Double>) -> Binding<Double> {
        Binding(
            get: { model.settings.appearance[keyPath: keyPath] },
            set: { value in model.updateAppearance { $0[keyPath: keyPath] = value } }
        )
    }
}
