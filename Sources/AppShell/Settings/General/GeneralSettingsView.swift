import Core
import Localization
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            SettingsSection(
                title: L10n.string("section.permissions.title"),
                subtitle: L10n.string("section.permissions.subtitle")
            ) {
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

            SettingsSection(
                title: L10n.string("section.language.title"),
                subtitle: L10n.string("section.language.subtitle")
            ) {
                SettingsRow(title: L10n.string("field.language"), detail: L10n.string("field.language.detail")) {
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
                    .fixedSize()
                }
            }

            SettingsSection(
                title: L10n.string("section.startup.title"),
                subtitle: L10n.string("section.startup.subtitle")
            ) {
                SettingsRow(
                    title: L10n.string("field.launch_at_login"),
                    detail: L10n.string("field.launch_at_login.detail")
                ) {
                    Toggle("", isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            SettingsSection(
                title: L10n.string("section.diagnostics.title"),
                subtitle: L10n.string("section.diagnostics.subtitle")
            ) {
                valueRow(
                    title: L10n.string("diagnostic.detected_items"),
                    detail: L10n.string("diagnostic.detected_items.detail"),
                    value: "\(model.managedItems.count)"
                )
                valueRow(
                    title: L10n.string("diagnostic.hidden_in_shelf"),
                    detail: L10n.string("diagnostic.hidden_in_shelf.detail"),
                    value: "\(model.managedItems.filter { $0.rule.kind == .hiddenInBar }.count)"
                )
                valueRow(
                    title: L10n.string("diagnostic.current_state"),
                    detail: L10n.string("diagnostic.current_state.detail"),
                    value: model.revealState.localizedTitle
                )
            }
        }
        .formStyle(.grouped)
    }

    private func valueRow(title: String, detail: String, value: String) -> some View {
        SettingsRow(title: title, detail: detail) {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
