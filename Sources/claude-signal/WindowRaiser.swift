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

        let application = AXUIElementCreateApplication(appPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return false }

        for window in windows {
            var id: CGWindowID = 0
            guard _AXUIElementGetWindow(window, &id) == .success, id == windowID else { continue }
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            NSRunningApplication(processIdentifier: appPID)?.activate()
            return true
        }
        return false
    }
}
