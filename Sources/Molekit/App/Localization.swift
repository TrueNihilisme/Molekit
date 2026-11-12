import Foundation

/// In-app language switch (UA/EN in the sidebar), independent of the system language.
/// Strings live in Resources/<lang>.lproj/Localizable.strings.
enum AppLanguage: String, CaseIterable {
    case en, uk

    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("uk") == true ? .uk : .en
    }

    private static var bundles: [AppLanguage: Bundle] = [:]

    var bundle: Bundle {
        if let cached = Self.bundles[self] { return cached }
        let found = Bundle.module.path(forResource: rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? Bundle.module
        Self.bundles[self] = found
        return found
    }

    func string(_ key: String) -> String {
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        if value != key { return value }
        // Fall back to English, then to the key itself.
        return self == .en ? key : AppLanguage.en.string(key)
    }

    func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: Locale(identifier: self == .uk ? "uk_UA" : "en_US"), arguments: args)
    }
}
