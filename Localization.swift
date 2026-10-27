// Мови інтерфейсу. Щоб додати нову мову: новий case у Language і ще одна таблиця в Text.

import Foundation
import ServiceManagement

enum Language: String, CaseIterable {
    case uk
    case en

    /// Назва мови тією ж мовою — так її легше знайти у списку.
    var nativeName: String {
        switch self {
        case .uk: return "Українська"
        case .en: return "English"
        }
    }

    private static let defaultsKey = "language"

    /// Обрана мова. Якщо користувач ще не обирав — за мовою системи.
    static var current: Language {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey), let lang = Language(rawValue: raw) {
                return lang
            }
            let system = Locale.preferredLanguages.first ?? ""
            return system.hasPrefix("uk") ? .uk : .en
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("ScreenshoterLanguageChanged")
    static let statusIconVisibilityChanged = Notification.Name("ScreenshoterStatusIconVisibilityChanged")
}

/// Автозапуск при вході в систему (Системні параметри → Загальні → Об'єкти входу).
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Користувач має ще дозволити автозапуск у Системних параметрах.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Повертає текст помилки, якщо не вдалося.
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            NSLog("Автозапуск: \(error)")
            return error.localizedDescription
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// Інші налаштування програми.
enum Preferences {
    private static let showIconKey = "showStatusIcon"

    /// Чи показувати іконку в рядку меню (за замовчуванням — так).
    static var showStatusIcon: Bool {
        get { UserDefaults.standard.object(forKey: showIconKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: showIconKey)
            NotificationCenter.default.post(name: .statusIconVisibilityChanged, object: nil)
        }
    }
}

/// Усі тексти інтерфейсу. Виклик: Text.menuSettings.s або Text.duplicate.format(a, b)
enum Text {
    case appName, done
    case actionArea, actionFullScreen
    case menuSettings, menuQuit
    case settingsTitle, language, hint, resetDefaults
    case notAssigned, pressShortcut
    case duplicate        // %1$@ — комбінація, %2$@ — назва дії
    case registerFailed   // %@ — список дій
    case keySpace
    case showIcon, iconHiddenHint
    case launchAtLogin, launchNeedsApproval, openLoginItems, launchFailed
    case menuCheckUpdates, menuUpdateAvailable, menuDownloading
    case upToDate, updateCheckFailed, updateNoInstaller, updateBadSignature, updateDownloadFailed
    case updateAvailableTitle, updateAvailableBody, updateInstall, updateLater, updateSkip
    case autoCheckUpdates, versionLabel, checkNow
    case saveToFolder, chooseFolder, showInFinder, chooseFolderMessage, menuOpenFolder, saveFailed

    var s: String { Text.table[Language.current]?[self] ?? Text.table[.en]![self]! }

    func format(_ args: CVarArg...) -> String { String(format: s, arguments: args) }

    private static let table: [Language: [Text: String]] = [
        .uk: [
            .appName: "Скріншотер",
            .done: "Готово",
            .actionArea: "Область в буфер",
            .actionFullScreen: "Весь екран в буфер",
            .menuSettings: "Налаштування…",
            .menuQuit: "Вийти",
            .settingsTitle: "Налаштування Screenshoter",
            .language: "Мова:",
            .hint: "Клікніть на поле й натисніть нову комбінацію. Esc — скасувати, ⌫ — прибрати.",
            .resetDefaults: "Скинути до стандартних",
            .notAssigned: "Не призначено",
            .pressShortcut: "Натисніть комбінацію…",
            .duplicate: "%1$@ вже призначено для «%2$@».",
            .registerFailed: "Не вдалося увімкнути комбінацію для %@: її вже зайняла інша програма. Оберіть іншу.",
            .keySpace: "Пробіл",
            .showIcon: "Показувати іконку в рядку меню",
            .iconHiddenHint: "Коли іконку сховано, гарячі клавіші працюють як і раніше. Щоб відкрити налаштування, ще раз запустіть Screenshoter.app.",
            .launchAtLogin: "Запускати при вході в систему",
            .launchNeedsApproval: "macOS просить підтвердити автозапуск: увімкніть Screenshoter в «Об'єктах входу».",
            .openLoginItems: "Відкрити «Об'єкти входу»",
            .launchFailed: "Не вдалося змінити автозапуск: %@",
            .menuCheckUpdates: "Перевірити оновлення…",
            .menuUpdateAvailable: "Оновити до версії %@…",
            .menuDownloading: "Завантаження оновлення…",
            .upToDate: "У вас найновіша версія (%@).",
            .updateCheckFailed: "Не вдалося перевірити оновлення: %@",
            .updateNoInstaller: "Нова версія є, але в релізі немає підписаного установщика. Спробуйте пізніше.",
            .updateBadSignature: "Оновлення не пройшло перевірку підпису, тож його не буде встановлено. Можливо, файл пошкоджено або підмінено.",
            .updateDownloadFailed: "Не вдалося завантажити оновлення: %@",
            .updateAvailableTitle: "Доступна нова версія Screenshoter %@",
            .updateAvailableBody: "У вас версія %@. Оновлення буде завантажено й перевірено, після чого відкриється установщик.",
            .updateInstall: "Оновити",
            .updateLater: "Пізніше",
            .updateSkip: "Пропустити цю версію",
            .autoCheckUpdates: "Автоматично перевіряти оновлення",
            .versionLabel: "Версія %@",
            .checkNow: "Перевірити зараз",
            .saveToFolder: "Також зберігати знімки в папку",
            .chooseFolder: "Обрати…",
            .showInFinder: "Показати",
            .chooseFolderMessage: "Куди зберігати знімки?",
            .menuOpenFolder: "Відкрити папку зі знімками",
            .saveFailed: "Знімок у буфері, але зберегти його в %@ не вдалося: %@",
        ],
        .en: [
            .appName: "Screenshoter",
            .done: "Done",
            .actionArea: "Capture area to clipboard",
            .actionFullScreen: "Capture screen to clipboard",
            .menuSettings: "Settings…",
            .menuQuit: "Quit",
            .settingsTitle: "Screenshoter Settings",
            .language: "Language:",
            .hint: "Click a field and press a new shortcut. Esc to cancel, ⌫ to clear.",
            .resetDefaults: "Reset to Defaults",
            .notAssigned: "Not set",
            .pressShortcut: "Press shortcut…",
            .duplicate: "%1$@ is already used for “%2$@”.",
            .registerFailed: "Couldn't enable the shortcut for %@: another app is already using it. Choose a different one.",
            .keySpace: "Space",
            .showIcon: "Show icon in menu bar",
            .iconHiddenHint: "While the icon is hidden, shortcuts still work. To open Settings, launch Screenshoter.app again.",
            .launchAtLogin: "Launch at login",
            .launchNeedsApproval: "macOS needs your approval: turn on Screenshoter in Login Items.",
            .openLoginItems: "Open Login Items",
            .launchFailed: "Couldn't change launch at login: %@",
            .menuCheckUpdates: "Check for Updates…",
            .menuUpdateAvailable: "Update to Version %@…",
            .menuDownloading: "Downloading Update…",
            .upToDate: "You're up to date (%@).",
            .updateCheckFailed: "Couldn't check for updates: %@",
            .updateNoInstaller: "A new version exists, but its release has no signed installer yet. Try again later.",
            .updateBadSignature: "The update failed signature verification and won't be installed. The file may be damaged or tampered with.",
            .updateDownloadFailed: "Couldn't download the update: %@",
            .updateAvailableTitle: "Screenshoter %@ is available",
            .updateAvailableBody: "You have version %@. The update will be downloaded and verified, then the installer will open.",
            .updateInstall: "Update",
            .updateLater: "Later",
            .updateSkip: "Skip This Version",
            .autoCheckUpdates: "Automatically check for updates",
            .versionLabel: "Version %@",
            .checkNow: "Check Now",
            .saveToFolder: "Also save screenshots to a folder",
            .chooseFolder: "Choose…",
            .showInFinder: "Show",
            .chooseFolderMessage: "Where should screenshots be saved?",
            .menuOpenFolder: "Open Screenshots Folder",
            .saveFailed: "The screenshot is in the clipboard, but saving it to %@ failed: %@",
        ],
    ]
}
