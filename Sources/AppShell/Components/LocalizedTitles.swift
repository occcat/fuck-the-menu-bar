import Core
import Localization

extension SettingsTab {
    var symbolName: String {
        switch self {
        case .items: "menubar.rectangle"
        case .appearance: "paintpalette"
        case .shortcuts: "command"
        case .general: "gearshape"
        }
    }

    var caption: String {
        L10n.string("sidebar.caption.\(rawValue)")
    }

    var subtitle: String {
        L10n.string("settings.subtitle.\(rawValue)")
    }
}

extension VisibilityRuleKind {
    var localizedTitle: String {
        switch self {
        case .alwaysVisible: L10n.string("visibility.always_visible")
        case .hiddenInBar: L10n.string("visibility.hidden_in_shelf")
        case .alwaysHidden: L10n.string("visibility.always_hidden")
        }
    }
}

extension ProxyInteractionMode {
    var localizedTitle: String {
        switch self {
        case .proxyPreferred: L10n.string("interaction.proxy_first")
        case .revealBeforeAction: L10n.string("interaction.reveal_before_action")
        case .realClickOnly: L10n.string("interaction.real_click_only")
        }
    }
}

extension RevealState {
    var localizedTitle: String {
        switch self {
        case .collapsed: L10n.string("state.collapsed")
        case .expanded: L10n.string("state.expanded")
        }
    }
}

extension AppLanguage {
    /// Languages are listed by their native names so users can always find their own.
    var pickerTitle: String {
        switch self {
        case .system: L10n.string("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        }
    }
}
