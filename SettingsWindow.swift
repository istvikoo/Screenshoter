// Вікно налаштувань: для кожної дії — поле, куди можна записати свою комбінацію клавіш.

import Cocoa
import Carbon.HIToolbox

// MARK: - Поле запису комбінації

/// Кнопка: клікнули → вона чекає натискання → запам'ятовує комбінацію.
/// Esc — скасувати, ⌫ — прибрати комбінацію.
final class ShortcutField: NSButton {
    var shortcut: Shortcut? { didSet { updateTitle() } }

    /// Повертає false, якщо комбінацію треба відхилити (наприклад, вона вже зайнята).
    var onChange: ((Shortcut?) -> Bool)?
    var onRecordingChanged: ((Bool) -> Void)?

    private var monitor: Any?
    private(set) var isRecording = false

    init(shortcut: Shortcut?) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 180).isActive = true
        updateTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        onRecordingChanged?(true)
        title = Text.pressShortcut.s

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        updateTitle()
        onRecordingChanged?(false)
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let mods = Shortcut.carbonModifiers(from: event.modifierFlags)

        if event.type == .flagsChanged {
            // Поки тримають модифікатори — показуємо їх наживо.
            title = mods == 0 ? Text.pressShortcut.s : Shortcut.modifierSymbols(mods) + "…"
            return nil
        }

        let code = Int(event.keyCode)
        if mods == 0 && code == kVK_Escape {
            stopRecording()
            return nil
        }
        if mods == 0 && (code == kVK_Delete || code == kVK_ForwardDelete) {
            if onChange?(nil) ?? true { shortcut = nil }
            stopRecording()
            return nil
        }

        let candidate = Shortcut(event: event)
        // Без модифікаторів дозволяємо тільки F1–F20, щоб не зламати звичайне друкування.
        guard candidate.modifiers != 0 || candidate.isFunctionKey else {
            NSSound.beep()
            return nil
        }
        if onChange?(candidate) ?? true { shortcut = candidate }
        stopRecording()
        return nil
    }

    func updateTitle() {
        title = shortcut?.displayString ?? Text.notAssigned.s
    }
}

// MARK: - Вікно

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let hotKeys: HotKeyManager
    private let updater: Updater
    private let onShortcutsChanged: () -> Void

    private var fields: [Action: ShortcutField] = [:]
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    /// Помилка від останньої спроби запису — показується замість звичайного статусу.
    private var pendingError: String?
    private weak var iconHint: NSTextField?
    private weak var launchCheckbox: NSButton?
    private weak var approvalRow: NSView?

    init(hotKeys: HotKeyManager, updater: Updater, onShortcutsChanged: @escaping () -> Void) {
        self.hotKeys = hotKeys
        self.updater = updater
        self.onShortcutsChanged = onShortcutsChanged

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildUI()

        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged),
                                               name: .languageChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        refreshStatus()
        refreshLaunchAtLogin()   // користувач міг змінити це в Системних параметрах
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Будує вміст вікна заново — викликається і при зміні мови.
    private func buildUI() {
        guard let window, let content = window.contentView else { return }
        fields.values.forEach { $0.stopRecording() }
        content.subviews.forEach { $0.removeFromSuperview() }
        fields = [:]
        window.title = Text.settingsTitle.s

        // Мова
        let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for lang in Language.allCases {
            languagePopup.addItem(withTitle: lang.nativeName)
            languagePopup.lastItem?.representedObject = lang.rawValue
        }
        languagePopup.selectItem(at: Language.allCases.firstIndex(of: Language.current) ?? 0)
        languagePopup.target = self
        languagePopup.action = #selector(languageSelected(_:))

        var rows: [[NSView]] = [[NSTextField(labelWithString: Text.language.s), languagePopup]]

        // Комбінації клавіш
        for action in Action.allCases {
            let label = NSTextField(labelWithString: action.title + ":")
            let field = ShortcutField(shortcut: ShortcutStore.shortcut(for: action))
            field.onChange = { [weak self] new in self?.apply(new, to: action) ?? false }
            field.onRecordingChanged = { [weak self] recording in
                guard let self else { return }
                // Поки записуємо — вимикаємо гарячі клавіші, щоб не спрацював скріншот.
                recording ? self.hotKeys.unregisterAll() : self.hotKeys.reload()
                if !recording { self.refreshStatus() }
            }
            fields[action] = field
            rows.append([label, field])
        }

        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.row(at: 0).bottomPadding = 8   // відступ між мовою і клавішами

        let showIcon = NSButton(checkboxWithTitle: Text.showIcon.s, target: self, action: #selector(showIconToggled(_:)))
        showIcon.state = Preferences.showStatusIcon ? .on : .off

        let iconHint = NSTextField(wrappingLabelWithString: Text.iconHiddenHint.s)
        iconHint.textColor = .secondaryLabelColor
        iconHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        iconHint.isHidden = Preferences.showStatusIcon
        self.iconHint = iconHint

        let launch = NSButton(checkboxWithTitle: Text.launchAtLogin.s, target: self,
                              action: #selector(launchAtLoginToggled(_:)))
        launchCheckbox = launch

        let approvalText = NSTextField(wrappingLabelWithString: Text.launchNeedsApproval.s)
        approvalText.textColor = .systemOrange
        approvalText.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let openLoginItems = NSButton(title: Text.openLoginItems.s, target: self, action: #selector(openLoginItems))
        openLoginItems.controlSize = .small
        let approval = NSStackView(views: [approvalText, openLoginItems])
        approval.orientation = .vertical
        approval.alignment = .leading
        approval.spacing = 6
        approvalRow = approval

        // Оновлення
        let autoUpdate = NSButton(checkboxWithTitle: Text.autoCheckUpdates.s, target: self,
                                  action: #selector(autoUpdateToggled(_:)))
        autoUpdate.state = Updater.autoCheck ? .on : .off
        let version = NSTextField(labelWithString: Text.versionLabel.format(Updater.currentVersion))
        version.textColor = .secondaryLabelColor
        let checkNow = NSButton(title: Text.checkNow.s, target: self, action: #selector(checkUpdatesNow))
        checkNow.controlSize = .small
        let versionRow = NSStackView(views: [version, checkNow])
        versionRow.spacing = 8

        let hint = NSTextField(wrappingLabelWithString: Text.hint.s)
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let reset = NSButton(title: Text.resetDefaults.s, target: self, action: #selector(resetDefaults))
        // «Вийти» тут потрібна, бо коли іконку сховано, меню з цим пунктом недоступне.
        let quit = NSButton(title: Text.menuQuit.s, target: NSApp, action: #selector(NSApplication.terminate(_:)))
        let buttons = NSStackView(views: [reset, quit])
        buttons.spacing = 8

        let stack = NSStackView(views: [grid, hint, statusLabel, showIcon, iconHint, launch, approval, autoUpdate, versionRow, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            hint.widthAnchor.constraint(equalToConstant: 400),
            statusLabel.widthAnchor.constraint(equalToConstant: 400),
            iconHint.widthAnchor.constraint(equalToConstant: 400),
            approvalText.widthAnchor.constraint(equalToConstant: 400),
        ])
        refreshStatus()
        refreshLaunchAtLogin()
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        if let error = LaunchAtLogin.set(sender.state == .on) {
            showStatus(Text.launchFailed.format(error), isError: true)
        }
        refreshLaunchAtLogin()
    }

    @objc private func autoUpdateToggled(_ sender: NSButton) {
        Updater.autoCheck = sender.state == .on
    }

    @objc private func checkUpdatesNow() {
        if case .available(let release) = updater.state {
            updater.offer(release)
        } else {
            updater.check(userInitiated: true)
        }
    }

    @objc private func openLoginItems() { LaunchAtLogin.openSystemSettings() }

    private func refreshLaunchAtLogin() {
        // «Потребує підтвердження» теж показуємо як увімкнене — користувач його вже обрав.
        launchCheckbox?.state = (LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval) ? .on : .off
        approvalRow?.isHidden = !LaunchAtLogin.needsApproval
    }

    @objc private func languageSelected(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let lang = Language(rawValue: raw), lang != Language.current else { return }
        Language.current = lang   // розсилає .languageChanged
    }

    @objc private func showIconToggled(_ sender: NSButton) {
        Preferences.showStatusIcon = sender.state == .on
        iconHint?.isHidden = Preferences.showStatusIcon
    }

    @objc private func languageChanged() {
        buildUI()
    }

    /// Зберегти нову комбінацію. false — якщо її вже використовує інша дія.
    private func apply(_ shortcut: Shortcut?, to action: Action) -> Bool {
        if let shortcut,
           let other = Action.allCases.first(where: { $0 != action && ShortcutStore.shortcut(for: $0) == shortcut }) {
            NSSound.beep()
            pendingError = Text.duplicate.format(shortcut.displayString, other.title)
            return false
        }
        ShortcutStore.set(shortcut, for: action)
        onShortcutsChanged()
        return true
    }

    @objc private func resetDefaults() {
        ShortcutStore.resetAll()
        for (action, field) in fields { field.shortcut = ShortcutStore.shortcut(for: action) }
        hotKeys.reload()
        onShortcutsChanged()
        refreshStatus()
    }

    private func refreshStatus() {
        if let error = pendingError {
            pendingError = nil
            showStatus(error, isError: true)
        } else if hotKeys.failed.isEmpty {
            showStatus("", isError: false)
        } else {
            let names = hotKeys.failed.map { "«\($0.title)»" }.sorted().joined(separator: ", ")
            showStatus(Text.registerFailed.format(names), isError: true)
        }
    }

    private func showStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel.isHidden = text.isEmpty
    }

    func windowWillClose(_ notification: Notification) {
        fields.values.forEach { $0.stopRecording() }
    }
}
