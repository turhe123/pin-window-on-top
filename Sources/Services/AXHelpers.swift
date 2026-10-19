import AppKit
import ApplicationServices
import CoreGraphics

/// Thin, failure-tolerant wrappers around the Accessibility C API and the CoreGraphics window list.
enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> (value: CFTypeRef?, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (value, error)
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name).value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name).value as? String
    }

    static func bool(_ element: AXUIElement, _ name: String) -> Bool {
        (attribute(element, name).value as? Bool) ?? false
    }

    /// Returns false once the element's window has been closed.
    static func isAlive(_ element: AXUIElement) -> Bool {
        let error = attribute(element, kAXRoleAttribute).error
        return error != .invalidUIElement
    }

    /// Window frame in global top-left-origin coordinates (same space as CGWindow bounds).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let posRef = attribute(element, kAXPositionAttribute).value,
              let sizeRef = attribute(element, kAXSizeAttribute).value,
              CFGetTypeID(posRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(posRef, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sizeRef, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    /// The focused window of an app, if any.
    static func focusedWindow(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute)
    }

    /// Whether the frontmost app's focused window is in native full screen.
    static func frontmostIsFullScreen() -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let window = focusedWindow(pid: pid) else { return false }
        return bool(window, "AXFullScreen")
    }
}

/// One entry from `CGWindowListCopyWindowInfo`.
struct CGWindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
    let title: String
    let layer: Int

    /// On-screen windows, ordered front to back.
    static func onScreen() -> [CGWindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { dict in
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
            return CGWindowInfo(id: id, pid: pid, bounds: bounds,
                                title: dict[kCGWindowName as String] as? String ?? "",
                                layer: dict[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// Finds the CGWindowID for an AX window by owner PID, bounds and title, skipping IDs already taken.
    static func match(pid: pid_t, frame: CGRect?, title: String, excluding taken: Set<CGWindowID>) -> CGWindowID {
        let candidates = onScreen().filter { $0.pid == pid && $0.layer == 0 && !taken.contains($0.id) }
        func score(_ w: CGWindowInfo) -> Int {
            var s = 0
            if let frame, abs(w.bounds.minX - frame.minX) < 2, abs(w.bounds.minY - frame.minY) < 2,
               abs(w.bounds.width - frame.width) < 2, abs(w.bounds.height - frame.height) < 2 { s += 2 }
            if !title.isEmpty, w.title == title { s += 1 }
            return s
        }
        let best = candidates.max { score($0) < score($1) }
        guard let best, score(best) >= 2 || candidates.count == 1 else { return 0 }
        return best.id
    }
}
