// Налаштування програми і автозапуск.

import Foundation
import ServiceManagement

/// Усі ключі UserDefaults в одному місці. Назви не міняти — інакше злетять налаштування
/// у тих, хто оновлюється зі старих версій.
enum Keys {
    static let language = "language"
    static let showStatusIcon = "showStatusIcon"
    static let autoCheckUpdates = "autoCheckUpdates"
    static let lastUpdateCheck = "lastUpdateCheck"
    static let skippedUpdateVersion = "skippedUpdateVersion"
    static let saveToFolder = "saveToFolder"
    static let saveFolderPath = "saveFolderPath"
    static let launchAtLoginDefaultApplied = "launchAtLoginDefaultApplied"
    static let updateAPIURL = "updateAPIURL"   // лише для тестів
    static func shortcut(_ action: Action) -> String { "shortcut.\(action.rawValue)" }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("ScreenshoterLanguageChanged")
    static let statusIconVisibilityChanged = Notification.Name("ScreenshoterStatusIconVisibilityChanged")
}

enum Preferences {
    private static var defaults: UserDefaults { .standard }

    /// Чи показувати іконку в рядку меню (за замовчуванням — так).
    static var showStatusIcon: Bool {
        get { defaults.object(forKey: Keys.showStatusIcon) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.showStatusIcon)
            NotificationCenter.default.post(name: .statusIconVisibilityChanged, object: nil)
        }
    }

    /// Автоматично перевіряти оновлення (за замовчуванням — так).
    static var autoCheckUpdates: Bool {
        get { defaults.object(forKey: Keys.autoCheckUpdates) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.autoCheckUpdates) }
    }

    /// Також зберігати знімки в папку (за замовчуванням — ні).
    static var saveToFolder: Bool {
        get { defaults.bool(forKey: Keys.saveToFolder) }
        set { defaults.set(newValue, forKey: Keys.saveToFolder) }
    }

    /// Папка для знімків. За замовчуванням — ~/Pictures/Screenshoter.
    static var saveFolder: URL {
        get {
            if let path = defaults.string(forKey: Keys.saveFolderPath) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Screenshoter", isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: Keys.saveFolderPath) }
    }
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

    // MARK: Увімкнено за замовчуванням

    /// Ключі, які записують попередні версії. Якщо хоч один є — програмою вже користувались,
    /// і ми не чіпаємо автозапуск: людина могла свідомо його вимкнути.
    private static let existingUserKeys = [
        Keys.language, Keys.showStatusIcon, Keys.autoCheckUpdates, Keys.lastUpdateCheck,
        Keys.skippedUpdateVersion, Keys.saveToFolder, Keys.saveFolderPath,
    ] + Action.allCases.map(Keys.shortcut)

    /// Чи вмикати автозапуск зараз. Позначає, що рішення ухвалено, щоб більше не повторювати.
    static func shouldEnableByDefault(bundlePath: String, defaults: UserDefaults) -> Bool {
        if defaults.bool(forKey: Keys.launchAtLoginDefaultApplied) { return false }
        // Тестові копії (робочий стіл, dist/) в автозапуск не реєструємо — і рішення не ухвалюємо,
        // щоб воно спрацювало, коли програму встановлять у «Програми».
        guard bundlePath.hasPrefix("/Applications/") else { return false }
        defaults.set(true, forKey: Keys.launchAtLoginDefaultApplied)
        return !existingUserKeys.contains { defaults.object(forKey: $0) != nil }
    }

    /// Викликається при запуску програми: при першому запуску вмикає автозапуск.
    static func applyDefaultOnFirstLaunch() {
        guard shouldEnableByDefault(bundlePath: Bundle.main.bundlePath, defaults: .standard),
              SMAppService.mainApp.status == .notRegistered
        else { return }
        set(true)
    }
}
