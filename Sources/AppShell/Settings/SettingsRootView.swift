import Core
import Localization
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbolName)
                        .help(tab.caption)
                        .tag(tab)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedTab.title)
                        .font(.title2.weight(.semibold))
                    Text(model.selectedTab.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(model.selectedTab.title)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 520)
        .alert(L10n.string("alert.error.title"), isPresented: errorBinding) {
            Button(L10n.string("action.ok")) { model.lastErrorMessage = nil }
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var page: some View {
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

    private var selection: Binding<SettingsTab?> {
        Binding(
            get: { model.selectedTab },
            set: { tab in
                if let tab { model.selectedTab = tab }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastErrorMessage != nil },
            set: { isPresented in
                if !isPresented { model.lastErrorMessage = nil }
            }
        )
    }
}
