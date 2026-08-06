import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case esMX = "es-MX"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch resolved() {
        case .english: "en"
        case .system, .esMX: "es-MX"
        }
    }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        guard let preferred = preferredLanguages.first?.lowercased() else { return .esMX }
        return preferred.hasPrefix("en") ? .english : .esMX
    }
}

enum RecvelLanguageStore {
    static let preferenceKey = "recvel.appLanguage"
    private static let lock = NSLock()
    private static var activeLanguage: AppLanguage?

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: RecvelSharedSnapshotStore.appGroupIdentifier) ?? .standard
    }

    static func load(defaults: UserDefaults? = nil) -> AppLanguage {
        if defaults == nil {
            lock.lock()
            let active = activeLanguage
            lock.unlock()
            if let active { return active }
        }

        let explicitStore = defaults
        let rawValue = explicitStore?.string(forKey: preferenceKey)
            ?? UserDefaults.standard.string(forKey: preferenceKey)
            ?? sharedDefaults.string(forKey: preferenceKey)
        let language = rawValue.flatMap(AppLanguage.init(rawValue:)) ?? .system
        if defaults == nil { setActive(language) }
        return language
    }

    static func save(_ language: AppLanguage, defaults: UserDefaults? = nil) {
        let store = defaults ?? sharedDefaults
        store.set(language.rawValue, forKey: preferenceKey)
        UserDefaults.standard.set(language.rawValue, forKey: preferenceKey)
        if defaults == nil { setActive(language) }
    }

    private static func setActive(_ language: AppLanguage) {
        lock.lock()
        activeLanguage = language
        lock.unlock()
    }
}

enum RecvelL10n {
    /// Locale del idioma elegido en la app.
    ///
    /// `Date.formatted(_:)` **no** lee el `\.locale` del entorno de SwiftUI: usa
    /// `Locale.autoupdatingCurrent`, el del sistema. Sin pasar esto a mano, una
    /// app en ingles seguia pintando meses, dias y horas en español (o al reves).
    /// Toda fecha visible debe formatearse con `.locale(RecvelL10n.locale)`.
    static var locale: Locale {
        Locale(identifier: RecvelLanguageStore.load().localeIdentifier)
    }

    /// Iniciales de los dias de la semana empezando en lunes, en el idioma de la
    /// app. Sustituye a los ["L","M","X",…] escritos a mano.
    static var mondayFirstWeekdayInitials: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        // `veryShortStandaloneWeekdaySymbols` empieza en domingo.
        return Array(symbols[1...6]) + [symbols[0]]
    }

    static func text(
        _ key: String,
        language: AppLanguage = RecvelLanguageStore.load(),
        values: [String: String] = [:],
        bundle: Bundle = .main
    ) -> String {
        let languageCode = language.resolved() == .english ? "en" : "es-MX"
        let localizedBundle = bundle.path(forResource: languageCode, ofType: "lproj")
            .flatMap(Bundle.init(path:))
        var result = (localizedBundle ?? bundle).localizedString(
            forKey: key,
            value: key,
            table: "Localizable"
        )
        for (name, value) in values {
            result = result.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return result
    }
}

struct CopyMessage: Codable, Hashable {
    let key: String
    var values: [String: String] = [:]

    func localized(language: AppLanguage = RecvelLanguageStore.load()) -> String {
        RecvelL10n.text(key, language: language, values: values)
    }
}
