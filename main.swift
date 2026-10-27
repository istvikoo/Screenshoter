// Скріншотер для macOS: глобальні гарячі клавіші -> скріншот одразу в буфер обміну.
//
// Стандартні комбінації (змінюються в «Налаштування…» в меню іконки):
//   ⌥⇧S  — виділити область мишкою (Esc — скасувати, Пробіл — вибрати вікно)
//   ⌥⇧A  — весь екран
//
// Гарячі клавіші реєструються через Carbon RegisterEventHotKey (див. Shortcuts.swift):
// це не потребує дозволу «Універсальний доступ». Сам знімок робить системна утиліта
// screencapture з ключем -c (копіювати в буфер, без файлу).

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeys = HotKeyManager()
    private var settingsWindow: SettingsWindowController?
    private var actionItems: [Action: NSMenuItem] = [:]
    private let updater = Updater()
    private var updateItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NotificationCenter.default.addObserver(self, selector: #selector(buildMenu),
                                               name: .languageChanged, object: nil)
        hotKeys.onPress = { [weak self] action in self?.capture(action) }
        hotKeys.reload()
        updateMenuTitles()
        updater.onStateChange = { [weak self] in self?.updateUpdateItem() }
        updater.start()
    }

    // Повторне відкриття Screenshoter.app (коли він уже працює) — показати налаштування.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // MARK: - Рядок меню

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder",
                                           accessibilityDescription: Text.appName.s)
        statusItem.isVisible = Preferences.showStatusIcon
        NotificationCenter.default.addObserver(forName: .statusIconVisibilityChanged, object: nil, queue: .main) {
            [weak self] _ in self?.statusItem.isVisible = Preferences.showStatusIcon
        }
        buildMenu()
    }

    /// Меню будується заново при зміні мови.
    @objc private func buildMenu() {
        statusItem.button?.image?.accessibilityDescription = Text.appName.s
        actionItems = [:]
        let menu = NSMenu()
        menu.delegate = self
        for action in Action.allCases {
            let item = NSMenuItem(title: action.title, action: #selector(menuCapture(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(action.rawValue)
            actionItems[action] = item
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let update = NSMenuItem(title: "", action: #selector(updateClicked), keyEquivalent: "")
        update.target = self
        updateItem = update
        menu.addItem(update)
        updateUpdateItem()
        let settings = NSMenuItem(title: Text.menuSettings.s, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: Text.menuQuit.s, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateMenuTitles()
    }

    func menuWillOpen(_ menu: NSMenu) { updateMenuTitles() }

    private func updateMenuTitles() {
        for (action, item) in actionItems {
            let sc = ShortcutStore.shortcut(for: action)?.displayString ?? "—"
            item.title = "\(action.title)    \(sc)"
        }
    }

    @objc private func menuCapture(_ sender: NSMenuItem) {
        guard let action = Action(rawValue: UInt32(sender.tag)) else { return }
        // Даємо меню закритися, щоб воно не потрапило на знімок.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.capture(action) }
    }

    // MARK: - Оновлення

    private func updateUpdateItem() {
        guard let item = updateItem else { return }
        switch updater.state {
        case .idle:               item.title = Text.menuCheckUpdates.s; item.isEnabled = true
        case .checking:           item.title = Text.menuCheckUpdates.s; item.isEnabled = false
        case .available(let r):   item.title = Text.menuUpdateAvailable.format(r.version); item.isEnabled = true
        case .downloading:        item.title = Text.menuDownloading.s; item.isEnabled = false
        }
    }

    @objc private func updateClicked() {
        if case .available(let release) = updater.state {
            updater.offer(release)
        } else {
            updater.check(userInitiated: true)
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(hotKeys: hotKeys, updater: updater) { [weak self] in
                self?.hotKeys.reload()
                self?.updateMenuTitles()
            }
        }
        settingsWindow?.show()
    }

    // MARK: - Знімок

    private var isCapturing = false

    func capture(_ action: Action) {
        guard !isCapturing else { return }
        isCapturing = true

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = action.captureArgs
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isCapturing = false
                self?.flashIcon()
            }
        }
        do {
            try task.run()
        } catch {
            isCapturing = false
            NSLog("Помилка запуску screencapture: \(error)")
        }
    }

    // Коротко міняємо іконку, щоб було видно, що знімок у буфері.
    private func flashIcon() {
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.png.rawValue,
                                                                          NSPasteboard.PasteboardType.tiff.rawValue])
        else { return }
        let original = statusItem.button?.image
        statusItem.button?.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: Text.done.s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.statusItem.button?.image = original
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // без іконки в Dock
app.run()
