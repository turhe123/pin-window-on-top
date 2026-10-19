import AppKit

/// A click-through, borderless panel that draws a tinted frame around a pinned window.
final class BorderOverlay {
    private let panel: NSPanel
    private let view = BorderView()

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = view
    }

    /// Positions the border around `axFrame` (top-left-origin screen coordinates) or hides it.
    func update(axFrame: CGRect?, visible: Bool) {
        let defaults = UserDefaults.standard
        guard visible, defaults.bool(forKey: Preferences.showBorder), let axFrame,
              let primary = NSScreen.screens.first else {
            panel.orderOut(nil)
            return
        }
        let thickness = CGFloat(max(1, defaults.double(forKey: Preferences.borderThickness)))
        let cocoa = CGRect(x: axFrame.minX, y: primary.frame.maxY - axFrame.maxY,
                           width: axFrame.width, height: axFrame.height)
        view.color = NSColor(hex: defaults.string(forKey: Preferences.borderColorHex) ?? "")
            .withAlphaComponent(CGFloat(defaults.double(forKey: Preferences.borderOpacity)))
        view.thickness = thickness
        view.needsDisplay = true
        panel.setFrame(cocoa.insetBy(dx: -thickness, dy: -thickness), display: true)
        panel.orderFrontRegardless()
    }

    func close() { panel.orderOut(nil) }
}

/// Draws a rounded stroke matching macOS window corners.
private final class BorderView: NSView {
    var color: NSColor = .systemOrange
    var thickness: CGFloat = 3

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: thickness / 2, dy: thickness / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10 + thickness / 2, yRadius: 10 + thickness / 2)
        path.lineWidth = thickness
        color.setStroke()
        path.stroke()
    }
}
