import SwiftUI

/// Contents of the menu bar menu: pin toggle, pinned window list, and app actions.
struct MenuContent: View {
    @EnvironmentObject private var manager: PinManager
    @AppStorage(Preferences.hotkeyLabel) private var hotkeyLabel = HotkeyManager.defaultLabel

    var body: some View {
        if !manager.isTrusted {
            Button("⚠️ Accessibility access needed — Open Settings…") {
                manager.requestAccessibility()
            }
            Divider()
        }

        Button("Pin / Unpin Front Window   \(hotkeyLabel)") {
            manager.togglePinFrontWindow()
        }
        .disabled(!manager.isTrusted)

        Divider()
        Section("Pinned Windows") {
            if manager.pins.isEmpty {
                Text("Nothing pinned")
            } else {
                ForEach(manager.pins) { pin in
                    Menu("\(pin.paused ? "⏸ " : "")\(pin.appName) — \(pin.displayTitle)") {
                        Button("Focus") { manager.focus(pin) }
                        Button("Unpin") { manager.unpin(pin) }
                    }
                }
            }
        }
        Button("Unpin All") { manager.unpinAll() }
            .disabled(manager.pins.isEmpty)

        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Support / Donate ❤️") { Preferences.openDonate() }
        Divider()
        Button("Quit PinWindowOnTop") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
