// Комбінації клавіш: як їх зберігати, показувати і реєструвати в системі.

import Cocoa
import Carbon.HIToolbox

// MARK: - Дії програми

enum Action: UInt32, CaseIterable {
    case area = 1
    case fullScreen = 2

    var title: String {
        switch self {
        case .area:       return Text.actionArea.s
        case .fullScreen: return Text.actionFullScreen.s
        }
    }

    /// Аргументи для /usr/sbin/screencapture (-c = одразу в буфер обміну).
    var captureArgs: [String] {
        switch self {
        case .area:       return ["-c", "-i"]
        case .fullScreen: return ["-c"]
        }
    }

    var defaultShortcut: Shortcut {
        let mods = UInt32(optionKey | shiftKey)
        switch self {
        case .area:       return Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: mods)
        case .fullScreen: return Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: mods)
        }
    }
}

// MARK: - Комбінація

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon-маска: cmdKey, optionKey, shiftKey, controlKey

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        modifiers = Shortcut.carbonModifiers(from: event.modifierFlags)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    static func modifierSymbols(_ m: UInt32) -> String {
        var s = ""
        if m & UInt32(controlKey) != 0 { s += "⌃" }
        if m & UInt32(optionKey)  != 0 { s += "⌥" }
        if m & UInt32(shiftKey)   != 0 { s += "⇧" }
        if m & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    var isFunctionKey: Bool { Shortcut.functionKeys.contains(keyCode) }

    var displayString: String { Shortcut.modifierSymbols(modifiers) + Shortcut.keyName(keyCode) }

    // MARK: Назви клавіш

    private static let functionKeys: Set<UInt32> = Set([
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].map { UInt32($0) })

    private static let specialNames: [UInt32: String] = {
        var d: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
            kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        ]
        let fKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                     kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        for (i, k) in fKeys.enumerated() { d[k] = "F\(i + 1)" }
        return Dictionary(uniqueKeysWithValues: d.map { (UInt32($0.key), $0.value) })
    }()

    /// Назва клавіші латиницею, навіть якщо зараз увімкнена українська розкладка.
    static func keyName(_ keyCode: UInt32) -> String {
        if keyCode == UInt32(kVK_Space) { return Text.keySpace.s }
        if let name = specialNames[keyCode] { return name }

        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "#\(keyCode)" }

        let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "#\(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

// MARK: - Збереження

enum ShortcutStore {
    private static let disabledMarker = "none"

    /// Кеш, щоб не розбирати JSON з диска при кожному відкритті меню.
    /// Значення — Optional: nil усередині означає «комбінацію вимкнено».
    private static var cache: [Action: Shortcut?] = [:]

    /// nil — комбінацію вимкнено користувачем.
    static func shortcut(for action: Action) -> Shortcut? {
        if let cached = cache[action] { return cached }
        let loaded = load(action)
        cache[action] = .some(loaded)
        return loaded
    }

    private static func load(_ action: Action) -> Shortcut? {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Keys.shortcut(action)) == disabledMarker { return nil }
        if let data = defaults.data(forKey: Keys.shortcut(action)),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            return saved
        }
        return action.defaultShortcut
    }

    static func set(_ shortcut: Shortcut?, for action: Action) {
        let defaults = UserDefaults.standard
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: Keys.shortcut(action))
        } else {
            defaults.set(disabledMarker, forKey: Keys.shortcut(action))
        }
        cache[action] = .some(shortcut)
    }

    static func resetAll() {
        Action.allCases.forEach { UserDefaults.standard.removeObject(forKey: Keys.shortcut($0)) }
        cache = [:]
    }
}

// MARK: - Реєстрація гарячих клавіш у системі

final class HotKeyManager {
    var onPress: ((Action) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false

    /// Дії, чию комбінацію не вдалося зареєструвати (її вже зайняла інша програма).
    private(set) var failed: Set<Action> = []

    /// Перереєструвати всі комбінації з налаштувань.
    func reload() {
        installHandlerIfNeeded()
        unregisterAll()
        failed = []
        for action in Action.allCases {
            guard let sc = ShortcutStore.shortcut(for: action) else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x53435254), id: action.rawValue) // 'SCRT'
            let status = RegisterEventHotKey(sc.keyCode, sc.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                refs.append(ref)
            } else {
                failed.insert(action)
                NSLog("Не вдалося зареєструвати \(sc.displayString) для «\(action.title)» (код \(status))")
            }
        }
    }

    /// Тимчасово вимкнути всі комбінації (поки користувач записує нову).
    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
            if let action = Action(rawValue: hotKeyID.id) {
                DispatchQueue.main.async { manager.onPress?(action) }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}
