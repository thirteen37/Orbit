import XCTest
@testable import Orbit

final class AccessibilityPermissionTests: XCTestCase {

    func testSharedInstance_isSingleton() {
        let instance1 = AccessibilityPermission.shared
        let instance2 = AccessibilityPermission.shared
        XCTAssertTrue(instance1 === instance2)
    }

    func testIsGranted_returnsBoolean() {
        let permission = AccessibilityPermission.shared
        // Just verify it returns without crashing
        let _ = permission.isGranted
    }

    func testStatus_returnsValidStatus() {
        let permission = AccessibilityPermission.shared
        let status = permission.status
        // Status should be either granted or denied
        XCTAssertTrue(status == .granted || status == .denied)
    }

    func testStatusEquality() {
        XCTAssertEqual(AccessibilityPermission.Status.granted, .granted)
        XCTAssertEqual(AccessibilityPermission.Status.denied, .denied)
        XCTAssertNotEqual(AccessibilityPermission.Status.granted, .denied)
    }

    func testStopPolling_isIdempotent() {
        let permission = AccessibilityPermission.shared
        permission.stopPolling()
        permission.stopPolling()
        // Should not crash
    }

    func testNotificationName_exists() {
        let name = AccessibilityPermission.statusDidChangeNotification
        XCTAssertEqual(name.rawValue, "AccessibilityPermissionStatusDidChange")
    }
}
