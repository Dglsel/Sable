import Foundation

enum L10n {

    /// Current language override. Set by AppState when the user changes language in Settings.
    /// When nil, falls back to the system language (default behavior).
    @MainActor static var currentLanguage: InterfaceLanguage = .followSystem

    static func string(_ key: String, default defaultValue: String) -> String {
        let bundle = resolveBundle()
        return NSLocalizedString(key, bundle: bundle, value: defaultValue, comment: "")
    }

    /// Resolves the correct .lproj bundle for the selected language.
    private static func resolveBundle() -> Bundle {
        let language = MainActor.assumeIsolated { currentLanguage }

        // Follow system → use main bundle as-is
        if language == .followSystem {
            return .main
        }

        let langCode: String
        switch language {
        case .simplifiedChinese:
            langCode = "zh-Hans"
        case .english:
            langCode = "en"
        case .followSystem:
            return .main
        }

        // Find the .lproj bundle for this language
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return .main
    }
}
