@preconcurrency import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

/// Errors that can occur during window movement operations.
public enum SpaceMoverError: Error, Equatable {
    case accessibilityNotTrusted
    case windowNotFound
    case cannotGetWindowPosition
    case eventCreationFailed
    case moveFailed(reason: String)
}

/// Represents a keyboard shortcut with a key code and modifier flags.
public struct KeyboardShortcut: Equatable {
    public let keyCode: CGKeyCode
    public let modifierFlags: CGEventFlags

    public init(keyCode: CGKeyCode, modifierFlags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    /// Parses a string shortcut like "ctrl+1" or "ctrl+left" into a KeyboardShortcut.
    /// Returns nil if the shortcut string is invalid.
    public static func parse(_ string: String) -> KeyboardShortcut? {
        let parts = string.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count >= 2 else { return nil }

        var modifierFlags: CGEventFlags = []
        var keyCode: CGKeyCode?

        for (index, part) in parts.enumerated() {
            if index == parts.count - 1 {
                // Last part is the key
                keyCode = parseKeyCode(part)
            } else {
                // Modifier
                if let modifier = parseModifier(part) {
                    modifierFlags.insert(modifier)
                } else {
                    return nil  // Invalid modifier
                }
            }
        }

        guard let code = keyCode else { return nil }
        return KeyboardShortcut(keyCode: code, modifierFlags: modifierFlags)
    }

    /// Parses a modifier string to CGEventFlags.
    private static func parseModifier(_ modifier: String) -> CGEventFlags? {
        switch modifier {
        case "ctrl", "control":
            return .maskControl
        case "shift":
            return .maskShift
        case "alt", "option", "opt":
            return .maskAlternate
        case "cmd", "command":
            return .maskCommand
        default:
            return nil
        }
    }

    /// Parses a key string to CGKeyCode.
    private static func parseKeyCode(_ key: String) -> CGKeyCode? {
        switch key {
        // Number keys (using Carbon key codes)
        case "1": return CGKeyCode(kVK_ANSI_1)
        case "2": return CGKeyCode(kVK_ANSI_2)
        case "3": return CGKeyCode(kVK_ANSI_3)
        case "4": return CGKeyCode(kVK_ANSI_4)
        case "5": return CGKeyCode(kVK_ANSI_5)
        case "6": return CGKeyCode(kVK_ANSI_6)
        case "7": return CGKeyCode(kVK_ANSI_7)
        case "8": return CGKeyCode(kVK_ANSI_8)
        case "9": return CGKeyCode(kVK_ANSI_9)
        case "0": return CGKeyCode(kVK_ANSI_0)
        // Arrow keys
        case "left": return CGKeyCode(kVK_LeftArrow)
        case "right": return CGKeyCode(kVK_RightArrow)
        case "up": return CGKeyCode(kVK_UpArrow)
        case "down": return CGKeyCode(kVK_DownArrow)
        default: return nil
        }
    }
}

/// Handles moving windows between Spaces using the grab-and-switch technique.
///
/// This technique works by:
/// 1. Simulating a mouse grab on the window's title bar
/// 2. Sending a keyboard shortcut to switch spaces
/// 3. The window follows the "grabbed" mouse to the new space
/// 4. Releasing the mouse
public final class SpaceMover {

    public init() {}

    /// Checks if the current process is trusted for accessibility access.
    public static func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompts the user to grant accessibility permissions.
    /// Opens System Settings if not already trusted.
    public static func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Moves a window to a different space using the grab-and-switch technique.
    ///
    /// - Parameters:
    ///   - window: The AXUIElement representing the window to move.
    ///   - targetSpace: The target space number (1-indexed).
    ///   - fromSpace: The current space number (1-indexed).
    ///   - shortcut: The keyboard shortcut to use for space switching.
    /// - Throws: SpaceMoverError if the move operation fails.
    public func moveWindow(
        _ window: AXUIElement,
        toSpace targetSpace: Int,
        fromSpace currentSpace: Int,
        using shortcut: KeyboardShortcut
    ) throws {
        // Check accessibility permission
        guard SpaceMover.isAccessibilityTrusted() else {
            throw SpaceMoverError.accessibilityNotTrusted
        }

        // Get window position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        guard positionResult == .success, let positionRef = positionValue else {
            throw SpaceMoverError.cannotGetWindowPosition
        }

        var windowOrigin = CGPoint.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &windowOrigin) else {
            throw SpaceMoverError.cannotGetWindowPosition
        }

        // Calculate grab point (title bar area)
        // 70 pixels from left edge, 12 pixels from top
        let grabPoint = CGPoint(x: windowOrigin.x + 70, y: windowOrigin.y + 12)

        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw SpaceMoverError.eventCreationFailed
        }

        // Post mouse move event to grab point
        guard let mouseMoveEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .mouseMoved,
            mouseCursorPosition: grabPoint,
            mouseButton: .left
        ) else {
            throw SpaceMoverError.eventCreationFailed
        }
        mouseMoveEvent.post(tap: .cghidEventTap)

        // Small delay to ensure cursor is in position
        usleep(50_000)  // 50ms

        // Post mouse down event
        guard let mouseDownEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: grabPoint,
            mouseButton: .left
        ) else {
            throw SpaceMoverError.eventCreationFailed
        }
        mouseDownEvent.post(tap: .cghidEventTap)

        // Small delay to ensure grab is registered
        usleep(100_000)  // 100ms

        // Post keyboard shortcut for space switch
        // Key down
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: shortcut.keyCode, keyDown: true) else {
            throw SpaceMoverError.eventCreationFailed
        }
        keyDownEvent.flags = shortcut.modifierFlags
        keyDownEvent.post(tap: .cghidEventTap)

        // Key up
        guard let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: shortcut.keyCode, keyDown: false) else {
            throw SpaceMoverError.eventCreationFailed
        }
        keyUpEvent.flags = shortcut.modifierFlags
        keyUpEvent.post(tap: .cghidEventTap)

        // Wait for space switching animation
        usleep(300_000)  // 300ms

        // Post mouse up event
        guard let mouseUpEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: grabPoint,
            mouseButton: .left
        ) else {
            throw SpaceMoverError.eventCreationFailed
        }
        mouseUpEvent.post(tap: .cghidEventTap)
    }
}
