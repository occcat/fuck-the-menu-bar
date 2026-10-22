import Core
import Localization
import SharedUI
import SwiftUI

struct OnboardingRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var localization = LocalizationController.shared

    private var allGranted: Bool {
        model.permissionsSnapshot.accessibilityGranted && model.permissionsSnapshot.screenRecordingGranted
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(L10n.string("onboarding.title"))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(L10n.string("onboarding.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 36)

            Form {
                Section {
                    PermissionRow(
                        title: L10n.string("permission.accessibility.title"),
                        detail: L10n.string("permission.accessibility.onboarding_detail"),
                        granted: model.permissionsSnapshot.accessibilityGranted,
                        actionTitle: L10n.string("action.grant_accessibility")
                    ) {
                        model.requestAccessibilityPermission()
                    }

                    PermissionRow(
                        title: L10n.string("permission.screen_recording.title"),
                        detail: L10n.string("permission.screen_recording.onboarding_detail"),
                        granted: model.permissionsSnapshot.screenRecordingGranted,
                        actionTitle: L10n.string("action.grant_screen_recording")
                    ) {
                        model.requestScreenRecordingPermission()
                    }
                } footer: {
                    Text(L10n.string("onboarding.refresh_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            // Floating control layer: the only glass surface in this window.
            LiquidGlassGroup {
                HStack(spacing: 12) {
                    Button(L10n.string("action.refresh_status")) {
                        model.refreshPermissions()
                    }

                    Spacer()

                    Button(allGranted ? L10n.string("action.continue") : L10n.string("action.continue_anyway")) {
                        model.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlass(in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 540, minHeight: 460)
    }
}
