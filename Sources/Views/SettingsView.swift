import AppKit
import ServiceManagement
import SwiftUI

/// Settings window: hotkey, border marker appearance, raise behaviour and launch at login.
struct SettingsView: View {
    @EnvironmentObject private var manager: PinManager
    @AppStorage(Preferences.showBorder) private var showBorder = true
    @AppStorage(Preferences.borderColorHex) private var borderColorHex = "FF7A59"
    @AppStorage(Preferences.borderThickness) private var borderThickness = 3.0
    @AppStorage(Preferences.borderOpacity) private var borderOpacity = 0.9
    @AppStorage(Preferences.pauseInFullScreen) private var pauseInFullScreen = true
    @AppStorage(Preferences.gentleMode) private var gentleMode = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            if !manager.isTrusted {
                Section {
                    Label("PinWindowOnTop needs Accessibility access to keep windows on top.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Open Privacy & Security…") { manager.requestAccessibility() }
                }
            }

            Section("Hotkey") {
                LabeledContent("Pin / unpin front window") { HotkeyRecorder() }
            }

            Section("Border marker") {
                Toggle("Show border tint on pinned windows", isOn: $showBorder)
                ColorPicker("Border color", selection: colorBinding, supportsOpacity: false)
                    .disabled(!showBorder)
                LabeledContent("Thickness") {
                    Slider(value: $borderThickness, in: 1...10, step: 1)
                    Text("\(Int(borderThickness)) pt").monospacedDigit().frame(width: 40)
                }
                .disabled(!showBorder)
                LabeledContent("Opacity (fade)") {
                    Slider(value: $borderOpacity, in: 0.1...1)
                    Text("\(Int(borderOpacity * 100))%").monospacedDigit().frame(width: 40)
                }
                .disabled(!showBorder)
            }

            Section("Behaviour") {
                Toggle("Raise pinned windows only when the front app is not full screen", isOn: $pauseInFullScreen)
                Toggle("Gentle mode (only raise when the active app changes)", isOn: $gentleMode)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Text("PinWindowOnTop is free and open source.")
                    Spacer()
                    Button("Support / Donate ❤️") { Preferences.openDonate() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: borderColorHex)) },
            set: { borderColorHex = NSColor($0).hexString }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// A button that records a new global shortcut by capturing the next key press with modifiers.
struct HotkeyRecorder: View {
    @AppStorage(Preferences.hotkeyLabel) private var label = HotkeyManager.defaultLabel
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? "Press shortcut…" : label) { recording ? stop() : start() }
                .frame(minWidth: 120)
            Button("Reset") {
                stop()
                HotkeyManager.shared.save(keyCode: HotkeyManager.defaultKeyCode,
                                          modifiers: HotkeyManager.defaultModifiers,
                                          label: HotkeyManager.defaultLabel)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        HotkeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil } // Escape cancels.
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty, flags != .shift else { NSSound.beep(); return nil }
            let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            HotkeyManager.shared.save(keyCode: Int(event.keyCode),
                                      modifiers: HotkeyManager.carbonModifiers(from: flags),
                                      label: HotkeyManager.symbols(for: flags) + key)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotkeyManager.shared.registerFromDefaults() }
        recording = false
    }
}

extension NSColor {
    /// Creates a colour from a 6-digit hex string, falling back to orange.
    convenience init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard clean.count == 6, let v = UInt32(clean, radix: 16) else {
            self.init(srgbRed: 1, green: 0.48, blue: 0.35, alpha: 1)
            return
        }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Hex representation in sRGB, e.g. "FF7A59".
    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "FF7A59" }
        return String(format: "%02X%02X%02X", Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
}
