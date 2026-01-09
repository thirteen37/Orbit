import Carbon
import XCTest
@testable import Orbit

final class SpaceMoverTests: XCTestCase {

    // MARK: - KeyboardShortcut.parse Tests

    func testParseCtrl1() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+1")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_1))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCtrl2() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+2")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_2))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCtrlLeft() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+left")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_LeftArrow))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCtrlRight() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+right")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_RightArrow))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCtrlShift1() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+shift+1")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_1))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskShift) ?? false)
    }

    func testParseCtrlAlt3() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+alt+3")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_3))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskAlternate) ?? false)
    }

    func testParseCmdShift5() throws {
        let shortcut = KeyboardShortcut.parse("cmd+shift+5")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_5))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskCommand) ?? false)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskShift) ?? false)
    }

    func testParseAllNumberKeys() throws {
        for i in 0...9 {
            let shortcut = KeyboardShortcut.parse("ctrl+\(i)")
            XCTAssertNotNil(shortcut, "Failed to parse ctrl+\(i)")
        }
    }

    func testParseArrowKeys() throws {
        let directions = ["left", "right", "up", "down"]
        let expectedKeyCodes: [CGKeyCode] = [
            CGKeyCode(kVK_LeftArrow),
            CGKeyCode(kVK_RightArrow),
            CGKeyCode(kVK_UpArrow),
            CGKeyCode(kVK_DownArrow)
        ]

        for (direction, expectedKeyCode) in zip(directions, expectedKeyCodes) {
            let shortcut = KeyboardShortcut.parse("ctrl+\(direction)")
            XCTAssertNotNil(shortcut, "Failed to parse ctrl+\(direction)")
            XCTAssertEqual(shortcut?.keyCode, expectedKeyCode)
        }
    }

    // MARK: - Invalid Shortcut Tests

    func testParseInvalidKeyReturnsNil() throws {
        let shortcut = KeyboardShortcut.parse("ctrl+invalid")
        XCTAssertNil(shortcut)
    }

    func testParseInvalidModifierReturnsNil() throws {
        let shortcut = KeyboardShortcut.parse("invalidmod+1")
        XCTAssertNil(shortcut)
    }

    func testParseNoModifierReturnsNil() throws {
        let shortcut = KeyboardShortcut.parse("1")
        XCTAssertNil(shortcut)
    }

    func testParseEmptyStringReturnsNil() throws {
        let shortcut = KeyboardShortcut.parse("")
        XCTAssertNil(shortcut)
    }

    func testParseOnlyPlusReturnsNil() throws {
        let shortcut = KeyboardShortcut.parse("+")
        XCTAssertNil(shortcut)
    }

    // MARK: - Case Insensitivity Tests

    func testParseCaseInsensitiveUppercase() throws {
        let shortcut = KeyboardShortcut.parse("CTRL+1")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_ANSI_1))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCaseInsensitiveMixedCase() throws {
        let shortcut = KeyboardShortcut.parse("Ctrl+LEFT")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_LeftArrow))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseCaseInsensitiveAllCaps() throws {
        let shortcut = KeyboardShortcut.parse("CTRL+SHIFT+RIGHT")
        XCTAssertNotNil(shortcut)
        XCTAssertEqual(shortcut?.keyCode, CGKeyCode(kVK_RightArrow))
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskShift) ?? false)
    }

    // MARK: - Alternative Modifier Names

    func testParseControlAlternative() throws {
        let shortcut = KeyboardShortcut.parse("control+1")
        XCTAssertNotNil(shortcut)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskControl) ?? false)
    }

    func testParseOptionAlternative() throws {
        let shortcut = KeyboardShortcut.parse("option+1")
        XCTAssertNotNil(shortcut)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskAlternate) ?? false)
    }

    func testParseOptAlternative() throws {
        let shortcut = KeyboardShortcut.parse("opt+1")
        XCTAssertNotNil(shortcut)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskAlternate) ?? false)
    }

    func testParseCommandAlternative() throws {
        let shortcut = KeyboardShortcut.parse("command+1")
        XCTAssertNotNil(shortcut)
        XCTAssertTrue(shortcut?.modifierFlags.contains(.maskCommand) ?? false)
    }

    // MARK: - SpaceMover Tests

    func testIsAccessibilityTrustedIsCallable() throws {
        // This test just verifies the method is callable
        // The actual return value depends on system permissions
        let _ = SpaceMover.isAccessibilityTrusted()
        // If we get here without crashing, the test passes
    }

    func testSpaceMoverInitialization() throws {
        let mover = SpaceMover()
        XCTAssertNotNil(mover)
    }

    // MARK: - SpaceMoverError Tests

    func testSpaceMoverErrorEquality() throws {
        XCTAssertEqual(SpaceMoverError.accessibilityNotTrusted, SpaceMoverError.accessibilityNotTrusted)
        XCTAssertEqual(SpaceMoverError.windowNotFound, SpaceMoverError.windowNotFound)
        XCTAssertEqual(SpaceMoverError.cannotGetWindowPosition, SpaceMoverError.cannotGetWindowPosition)
        XCTAssertEqual(SpaceMoverError.eventCreationFailed, SpaceMoverError.eventCreationFailed)
        XCTAssertEqual(SpaceMoverError.moveFailed(reason: "test"), SpaceMoverError.moveFailed(reason: "test"))
        XCTAssertNotEqual(SpaceMoverError.moveFailed(reason: "a"), SpaceMoverError.moveFailed(reason: "b"))
    }

    // MARK: - KeyboardShortcut Equality Tests

    func testKeyboardShortcutEquality() throws {
        let shortcut1 = KeyboardShortcut.parse("ctrl+1")
        let shortcut2 = KeyboardShortcut.parse("ctrl+1")
        XCTAssertEqual(shortcut1, shortcut2)
    }

    func testKeyboardShortcutInequality() throws {
        let shortcut1 = KeyboardShortcut.parse("ctrl+1")
        let shortcut2 = KeyboardShortcut.parse("ctrl+2")
        XCTAssertNotEqual(shortcut1, shortcut2)
    }
}
