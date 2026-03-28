import Carbon
import Core
import Foundation
import Localization

public enum HotkeyFormatter {
    public static func string(for configuration: HotkeyConfiguration) -> String {
        guard configuration.isEnabled else { return L10n.string("state.disabled") }

        var parts: [String] = []
        let modifiers = configuration.modifiers
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }

        parts.append(keyName(for: configuration.keyCode))
        return parts.joined()
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 46: "M"
        case 11: "B"
        case 3: "F"
        default: L10n.format("hotkey.key", keyCode)
        }
    }
}
