import Carbon
import Core
import Localization
import SharedUI
import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            SettingsSection(
                title: L10n.string("section.global_shortcut.title"),
                subtitle: L10n.string("section.global_shortcut.subtitle")
            ) {
                SettingsRow(
                    title: L10n.string("field.enable_global_shortcut"),
                    detail: L10n.string("field.enable_global_shortcut.detail")
                ) {
                    Toggle("", isOn: Binding(
                        get: { model.settings.hotkey.isEnabled },
                        set: { enabled in updateHotkey { $0.isEnabled = enabled } }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                SettingsRow(
                    title: L10n.string("field.current_shortcut"),
                    detail: L10n.string("field.current_shortcut.detail")
                ) {
                    Text(HotkeyFormatter.string(for: model.settings.hotkey))
                        .monospaced()
                        .foregroundStyle(.secondary)
                }

                SettingsRow(title: L10n.string("field.preset"), detail: L10n.string("field.preset.detail")) {
                    Picker(L10n.string("field.preset"), selection: Binding(
                        get: { model.settings.hotkey.keyCode },
                        set: { keyCode in updateHotkey { $0.keyCode = keyCode } }
                    )) {
                        Text("⌘⌥M").tag(UInt32(46))
                        Text("⌘⌥B").tag(UInt32(11))
                        Text("⌘⌥F").tag(UInt32(3))
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                SettingsRow(title: L10n.string("field.modifiers"), detail: L10n.string("field.modifiers.detail")) {
                    Picker(L10n.string("field.modifiers"), selection: Binding(
                        get: { model.settings.hotkey.modifiers },
                        set: { modifiers in updateHotkey { $0.modifiers = modifiers } }
                    )) {
                        Text("⌘⌥").tag(UInt32(cmdKey | optionKey))
                        Text("⌘⌃").tag(UInt32(cmdKey | controlKey))
                        Text("⌘⇧").tag(UInt32(cmdKey | shiftKey))
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func updateHotkey(_ change: (inout HotkeyConfiguration) -> Void) {
        var config = model.settings.hotkey
        change(&config)
        model.updateHotkey(config)
    }
}
