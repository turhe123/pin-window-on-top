import AppKit
import Carbon

/// Registers a single system-wide hotkey through the Carbon Event Manager.
final class HotkeyManager {
    static let shared = HotkeyManager()

    static let defaultKeyCode = kVK_ANSI_P
    static let defaultModifiers = controlKey | optionKey
    static let defaultLabel = "⌃⌥P"

    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers the shortcut stored in UserDefaults.
    func registerFromDefaults() {
        let defaults = UserDefaults.standard
        register(keyCode: defaults.integer(forKey: Preferences.hotkeyCode),
                 modifiers: defaults.integer(forKey: Preferences.hotkeyMods))
    }

    /// Persists a new shortcut and registers it.
    func save(keyCode: Int, modifiers: Int, label: String) {
        let defaults = UserDefaults.standard
        defaults.set(keyCode, forKey: Preferences.hotkeyCode)
        defaults.set(modifiers, forKey: Preferences.hotkeyMods)
        defaults.set(label, forKey: Preferences.hotkeyLabel)
        register(keyCode: keyCode, modifiers: modifiers)
    }

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x5057_4F54), id: 1) // 'PWOT'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("PinWindowOnTop: hotkey registration failed (\(status)); it may be in use by another app.")
            hotKeyRef = nil
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotkeyManager.shared.onTrigger?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        return mods
    }

    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }
}
