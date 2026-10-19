import SwiftUI

/// App entry point: a menu-bar-only utility with a MenuBarExtra and a Settings window.
@main
struct PinWindowOnTopApp: App {
    @StateObject private var manager = PinManager.shared

    init() {
        Preferences.registerDefaults()
        PinManager.shared.start()
        HotkeyManager.shared.onTrigger = { PinManager.shared.togglePinFrontWindow() }
        HotkeyManager.shared.registerFromDefaults()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(manager)
        } label: {
            Image(systemName: manager.pins.isEmpty ? "pin" : "pin.fill")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(manager)
        }
    }
}

/// Central list of UserDefaults keys and their defaults, shared by `@AppStorage` and services.
enum Preferences {
    static let showBorder = "showBorder"
    static let borderColorHex = "borderColorHex"
    static let borderThickness = "borderThickness"
    static let borderOpacity = "borderOpacity"
    static let pauseInFullScreen = "pauseInFullScreen"
    static let gentleMode = "gentleMode"
    static let hotkeyCode = "hotkeyCode"
    static let hotkeyMods = "hotkeyMods"
    static let hotkeyLabel = "hotkeyLabel"

    static let donateURL = "https://ko-fi.com/leodavidai"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showBorder: true,
            borderColorHex: "FF7A59",
            borderThickness: 3.0,
            borderOpacity: 0.9,
            pauseInFullScreen: true,
            gentleMode: false,
            hotkeyCode: HotkeyManager.defaultKeyCode,
            hotkeyMods: HotkeyManager.defaultModifiers,
            hotkeyLabel: HotkeyManager.defaultLabel,
        ])
    }

    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
