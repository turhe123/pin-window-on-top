import AppKit
import ApplicationServices
import Combine

/// A window the user pinned, identified by its AX element and (when matchable) its CGWindowID.
final class PinnedWindow: Identifiable {
    let id = UUID()
    let element: AXUIElement
    let pid: pid_t
    let appName: String
    var windowID: CGWindowID
    var title: String
    var paused = false
    let overlay = BorderOverlay()

    init(element: AXUIElement, pid: pid_t, appName: String, windowID: CGWindowID, title: String) {
        self.element = element
        self.pid = pid
        self.appName = appName
        self.windowID = windowID
        self.title = title
    }

    /// Title for menus; identical titles are disambiguated by window ID.
    var displayTitle: String {
        let base = title.isEmpty ? "Untitled" : title
        return windowID == 0 ? base : "\(base) (#\(windowID))"
    }
}

/// Keeps pinned windows above others by re-raising them via AXRaise whenever focus or Spaces change.
final class PinManager: ObservableObject {
    static let shared = PinManager()

    @Published private(set) var pins: [PinnedWindow] = []
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var observers: [pid_t: AXObserver] = [:]
    private var timer: Timer?
    private var lastRaise = Date.distantPast
    private var raiseScheduled = false
    private let minRaiseInterval: TimeInterval = 0.15
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private init() {}

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRaise()
        }
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
            self?.scheduleRaise()
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.removePins { $0.pid == app.processIdentifier }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateOverlays()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
        if !isTrusted { requestAccessibility(openSettings: false) }
    }

    // MARK: - Permissions

    func requestAccessibility(openSettings: Bool = true) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted, openSettings,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Pinning

    func togglePinFrontWindow() {
        guard checkTrust() else { requestAccessibility(); return }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ownPID,
              let window = AX.focusedWindow(pid: app.processIdentifier) else { NSSound.beep(); return }
        if let existing = pins.first(where: { CFEqual($0.element, window) }) {
            unpin(existing)
            return
        }
        let title = AX.string(window, kAXTitleAttribute) ?? ""
        let taken = Set(pins.map(\.windowID).filter { $0 != 0 })
        let windowID = CGWindowInfo.match(pid: app.processIdentifier, frame: AX.frame(window), title: title, excluding: taken)
        let pin = PinnedWindow(element: window, pid: app.processIdentifier,
                               appName: app.localizedName ?? "App", windowID: windowID, title: title)
        pins.append(pin)
        observe(pin)
        updateOverlays()
    }

    func unpin(_ pin: PinnedWindow) { removePins { $0 === pin } }

    func unpinAll() { removePins { _ in true } }

    func focus(_ pin: PinnedWindow) {
        NSRunningApplication(processIdentifier: pin.pid)?.activate()
        AXUIElementSetAttributeValue(pin.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(pin.element, kAXRaiseAction as CFString)
    }

    private func removePins(where predicate: (PinnedWindow) -> Bool) {
        let removed = pins.filter(predicate)
        guard !removed.isEmpty else { return }
        pins.removeAll(where: predicate)
        for pin in removed {
            pin.overlay.close()
            if let observer = observers[pin.pid] {
                for name in Self.windowNotifications {
                    AXObserverRemoveNotification(observer, pin.element, name as CFString)
                }
            }
        }
        for pid in Set(removed.map(\.pid)) where !pins.contains(where: { $0.pid == pid }) {
            removeObserver(pid: pid)
        }
    }

    // MARK: - AX observers

    private static let windowNotifications = [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification,
                                              kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                                              kAXTitleChangedNotification]
    private static let appNotifications = [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification]

    private func observe(_ pin: PinnedWindow) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if observers[pin.pid] == nil {
            var created: AXObserver?
            guard AXObserverCreate(pin.pid, axCallback, &created) == .success, let observer = created else { return }
            let app = AXUIElementCreateApplication(pin.pid)
            for name in Self.appNotifications { AXObserverAddNotification(observer, app, name as CFString, refcon) }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            observers[pin.pid] = observer
        }
        if let observer = observers[pin.pid] {
            for name in Self.windowNotifications { AXObserverAddNotification(observer, pin.element, name as CFString, refcon) }
        }
    }

    private func removeObserver(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    fileprivate func handleAX(_ notification: String, element: AXUIElement) {
        switch notification {
        case kAXUIElementDestroyedNotification:
            removePins { CFEqual($0.element, element) || !AX.isAlive($0.element) }
        case kAXMovedNotification, kAXResizedNotification:
            updateOverlays()
        case kAXTitleChangedNotification:
            if let pin = pins.first(where: { CFEqual($0.element, element) }) {
                pin.title = AX.string(element, kAXTitleAttribute) ?? pin.title
                objectWillChange.send()
            }
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            if !UserDefaults.standard.bool(forKey: Preferences.gentleMode) { scheduleRaise() }
        default:
            refresh()
            scheduleRaise()
        }
    }

    // MARK: - Keep-on-top loop

    @discardableResult
    private func checkTrust() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        if !trusted && !observers.isEmpty {
            // Access was revoked: observers are useless now, drop them and the overlays.
            for pid in Array(observers.keys) { removeObserver(pid: pid) }
            pins.forEach { $0.overlay.close() }
        } else if trusted && !pins.isEmpty && observers.isEmpty {
            pins.forEach(observe)
        }
        return trusted
    }

    private func tick() {
        guard checkTrust(), !pins.isEmpty else { return }
        refresh()
        if !UserDefaults.standard.bool(forKey: Preferences.gentleMode), isAnyPinOccluded() { scheduleRaise() }
    }

    /// Drops closed windows, recomputes paused state, and repositions overlays.
    private func refresh() {
        removePins { !AX.isAlive($0.element) }
        let onScreen = Set(CGWindowInfo.onScreen().map(\.id))
        let fullScreenPause = isFullScreenPaused()
        var changed = false
        for pin in pins {
            let hidden = AX.bool(pin.element, kAXMinimizedAttribute)
                || (pin.windowID != 0 && !onScreen.contains(pin.windowID))
            let paused = hidden || fullScreenPause
            if paused != pin.paused { pin.paused = paused; changed = true }
            if pin.windowID == 0, !hidden {
                let taken = Set(pins.map(\.windowID).filter { $0 != 0 })
                pin.windowID = CGWindowInfo.match(pid: pin.pid, frame: AX.frame(pin.element), title: pin.title, excluding: taken)
            }
        }
        if changed { objectWillChange.send() }
        updateOverlays()
    }

    private func isFullScreenPaused() -> Bool {
        guard UserDefaults.standard.bool(forKey: Preferences.pauseInFullScreen) else { return false }
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              !pins.contains(where: { $0.pid == front }) else { return false }
        return AX.frontmostIsFullScreen()
    }

    private func updateOverlays() {
        for pin in pins { pin.overlay.update(axFrame: AX.frame(pin.element), visible: !pin.paused && isTrusted) }
    }

    /// True when some non-pinned normal window sits above a pinned window and overlaps it.
    private func isAnyPinOccluded() -> Bool {
        let windows = CGWindowInfo.onScreen().filter { $0.layer == 0 && $0.pid != ownPID }
        let pinnedIDs = Set(pins.map(\.windowID))
        for pin in pins where !pin.paused && pin.windowID != 0 {
            guard let index = windows.firstIndex(where: { $0.id == pin.windowID }) else { continue }
            let bounds = windows[index].bounds
            if windows[..<index].contains(where: { !pinnedIDs.contains($0.id) && $0.bounds.intersects(bounds) }) {
                return true
            }
        }
        return false
    }

    /// Raises at most once per `minRaiseInterval` to avoid feedback loops.
    private func scheduleRaise() {
        guard !pins.isEmpty, !raiseScheduled else { return }
        let wait = max(0, minRaiseInterval - Date().timeIntervalSince(lastRaise))
        raiseScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            self?.raiseScheduled = false
            self?.raisePinned()
        }
    }

    private func raisePinned() {
        guard checkTrust() else { return }
        let front = NSWorkspace.shared.frontmostApplication
        // Don't cover our own Settings window, and pause entirely over full-screen apps.
        guard front?.processIdentifier != ownPID else { return }
        refresh()
        let active = pins.filter { !$0.paused }
        guard !active.isEmpty else { return }
        lastRaise = Date()
        // Raise in pin order so the most recently pinned window stays on top and the order is stable.
        for pin in active { AXUIElementPerformAction(pin.element, kAXRaiseAction as CFString) }
        // AXRaise can steal focus in some apps; hand focus back to the app the user was using.
        if let front, !active.contains(where: { $0.pid == front.processIdentifier }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier != front.processIdentifier {
                    front.activate()
                }
            }
        }
        updateOverlays()
    }
}

/// C callback for AXObserver; forwards to the shared manager on the main run loop.
private func axCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let manager = Unmanaged<PinManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.handleAX(notification as String, element: element)
}
