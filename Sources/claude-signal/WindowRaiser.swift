import AppKit
import ApplicationServices

// Maps an accessibility window element to its CGWindowID. Private but
// long-stable API, used by most window-management tools (AltTab, yabai);
// there is no public equivalent.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

/// Raises one specific window of another app via the Accessibility API.
/// Requires the user to grant Accessibility access; the first attempt
/// triggers the system prompt and reports failure so callers can fall back.
enum WindowRaiser {
    static func raise(windowID: CGWindowID, appPID: pid_t) -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else { return false }
        guard let window = axWindow(windowID: windowID, appPID: appPID) else { return false }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: appPID)?.activate()
        return true
    }

    /// The window's title — for terminals this is what Claude Code sets it
    /// to (the session topic), so it identifies the session far better than
    /// a working directory. Silent when Accessibility is not granted (no
    /// prompt from a menu render).
    static func title(windowID: CGWindowID, appPID: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let window = axWindow(windowID: windowID, appPID: appPID) else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
              let title = value as? String, !title.isEmpty
        else { return nil }
        return title
    }

    private static func axWindow(windowID: CGWindowID, appPID: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(appPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }

        for window in windows {
            var id: CGWindowID = 0
            if _AXUIElementGetWindow(window, &id) == .success, id == windowID {
                return window
            }
        }
        return nil
    }
}
