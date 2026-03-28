import Foundation
import Core

public final class LocalizationController: ObservableObject {
    public nonisolated(unsafe) static let shared = LocalizationController()

    @Published public private(set) var language: AppLanguage = .system

    private init() {}

    public func apply(language: AppLanguage) {
        self.language = language
    }

    public func string(_ key: String) -> String {
        activeBundle.localizedString(forKey: key, value: key, table: nil)
    }

    public func format(_ key: String, locale: Locale = .current, arguments: [CVarArg]) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    private var activeBundle: Bundle {
        guard language != .system else {
            return Bundle.module
        }

        let candidates = [language.rawValue, language.rawValue.lowercased()]
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return Bundle.module
    }
}

public enum L10n {
    public static func string(_ key: String) -> String {
        LocalizationController.shared.string(key)
    }

    public static func format(_ key: String, locale: Locale = .current, _ arguments: CVarArg...) -> String {
        LocalizationController.shared.format(key, locale: locale, arguments: arguments)
    }
}
