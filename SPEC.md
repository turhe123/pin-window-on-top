# PinWindowOnTop — specification

**Tagline:** Pin any window above all others with a hotkey, with an optional see-through fade and click-through mode.

**Category:** Window Management

**Inspired by (paid):** Floaty ($7 one-time)

**Frameworks:** SwiftUI, AppKit, ApplicationServices, CoreGraphics, Carbon, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

(1) What the paid app does. macOS has no always-on-top option for ordinary windows, and Floaty fills the gap as a small utility priced around 7 dollars one time with a limited free version. Roundups of always-on-top tools on blogs and in AlternativeTo lists, and the popularity of a free open-source competitor, show steady demand from people watching videos while coding, keeping notes or a calculator in view. Our clean-room version is PinWindowOnTop.

(2) Feature set. Press a global hotkey to pin the frontmost window so that it stays above normal windows of other apps. Press again to unpin. A small colored dot or border tint, optional, marks pinned windows. A menu lists every pinned window with its app and title, and clicking an entry focuses it or unpins it. Unpin All action. An opacity slider applies transparency to pinned windows of our own overlay thumbnails is not possible for foreign windows, so instead the fade feature dims only our marker border and the rest is skipped. Pins are kept per window while the window exists and cleared when the window closes. Auto-unpin when the owning app quits.

(3) UI spec. A MenuBarExtra with a pin icon that fills when something is pinned. Menu contents: Pin or Unpin Front Window with the hotkey shown, a section of pinned windows, Unpin All, Settings, Quit. Settings fields: hotkey recorder, toggle for showing a border tint on pinned windows, border color, border thickness, toggle for raising pinned windows only when the app is not full screen, and launch at login. Empty state in the menu reads Nothing pinned. Accessibility missing state shows a row that opens the privacy pane.

(4) Technical approach. Windows from other processes cannot have their level changed through public AppKit API, so the approach is a keep-on-top loop. Track pinned windows by AX element and CGWindowID matched through CGWindowListCopyWindowInfo by owner PID, bounds and title. Install an AXObserver per pinned app for focus changed and moved notifications, and also use NSWorkspace activation notifications. Whenever another app's window becomes active or a space changes, perform AXRaise on each pinned window without activating its app, preserving focus on the app the user is using. Keep the order of multiple pins stable. For the optional border marker, draw a click-through borderless NSPanel following the pinned window frame, updated on move and resize AX notifications. Register the hotkey via Carbon. Persist hotkey and appearance with AppStorage and launch at login via SMAppService. About 400 lines.

(5) Edge cases. Raising via AXRaise can steal focus in some apps, so re-activate the previously frontmost app right after, and add a toggle labeled Gentle mode that only raises on activation changes. Pinned windows that become minimized or move to another Space are paused and resume when visible. Closing detection: when the AX element becomes invalid, drop the pin. Windows with identical titles are disambiguated by ID. Full screen apps cover everything, so pins pause there. If Accessibility is revoked at runtime, clear observers and show the warning row. Avoid infinite raise loops by rate limiting raises to once every 150 milliseconds.
