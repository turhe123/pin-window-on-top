# PinWindowOnTop

Pin any window above all others with a hotkey, with an optional see-through fade and click-through mode.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![Release](https://img.shields.io/github/v/release/turhe123/pin-window-on-top)

## Why

macOS has no built-in "always on top" option for ordinary windows. PinWindowOnTop is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Window Management* category, inspired by Floaty ($7 one-time). It runs entirely on your Mac: no accounts, no servers, no network access.

## Features

- **Global hotkey** to pin or unpin the frontmost window (default `⌃⌥P`), re-recordable in Settings, with a Reset button.
- **Keep-on-top loop**: pinned windows are re-raised with the Accessibility API whenever another app is activated, focus changes, or you switch Spaces. Raises are rate-limited to once every 150 ms, and focus is handed back to the app you were using.
- **Multiple pins** with stable ordering. Windows with identical titles are told apart by window ID.
- **Menu bar app**: the pin icon fills when something is pinned. The menu shows each pinned window (app and title) with Focus / Unpin actions, plus Unpin All. The empty state reads "Nothing pinned".
- **Border marker**: an optional tinted, click-through border drawn around each pinned window. You can change its color, thickness (1–10 pt) and opacity (the "fade").
- **Gentle mode**: only raise pinned windows when the active app changes.
- **Full-screen pause**: pins pause while a non-pinned app is full screen (toggleable).
- **Automatic cleanup**: pins are dropped when the window closes or the app quits. Minimized windows or windows on other Spaces are paused and resume when visible.
- **Launch at login** via `SMAppService`.
- Missing Accessibility access shows a warning row that opens the Privacy & Security pane. If access is revoked at runtime, observers and borders are cleared.

### Limitations

macOS does not let one app change the window level of another app's windows. PinWindowOnTop works by re-raising pinned windows, so a pinned window can briefly sit behind another one until the next raise. The opacity/fade control applies only to the border marker, not to the pinned window itself. The border overlay is click-through, but the pinned windows are not.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `PinWindowOnTop-macOS.zip` from the [latest release](https://github.com/turhe123/pin-window-on-top/releases/latest).
2. Unzip it and move `PinWindowOnTop.app` to `/Applications`.
3. The app is open source and not notarized, so clear the quarantine flag:

   ```bash
   xattr -cr /Applications/PinWindowOnTop.app
   ```

4. Right-click the app → **Open** the first time you launch it.

## Build from source

Requires macOS 14+, Xcode with Swift 5.9+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project PinWindowOnTop.xcodeproj -scheme PinWindowOnTop -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/PinWindowOnTop.app`.

## Permissions

- **Accessibility** (required): lets the app find the focused window, raise pinned windows, and watch for move, resize, minimize and close events. Without it nothing can be pinned. Grant it under System Settings → Privacy & Security → Accessibility.
- **Launch at login** (optional): registers a login item through `SMAppService`; macOS may show it under Login Items.

The app does **not** request Screen Recording, Microphone, Camera, or network access. It does not read or capture window contents. It reads only window titles, positions and sizes.

## Support ❤️

PinWindowOnTop is free. If it's useful to you, you can support its development:

[Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

## License

MIT © Or Davidai Bachar
