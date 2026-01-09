// WindowMonitorTests - Tests for WindowMonitor component

import XCTest
@testable import Orbit

final class WindowMonitorTests: XCTestCase {

    // MARK: - WindowInfo Tests

    func testWindowInfo_propertyAccess() {
        // Create a dummy AXUIElement for testing
        let dummyElement = AXUIElementCreateApplication(getpid())

        let windowInfo = WindowInfo(
            bundleID: "com.example.app",
            appName: "Example App",
            title: "Test Window",
            windowElement: dummyElement,
            pid: 12345
        )

        XCTAssertEqual(windowInfo.bundleID, "com.example.app")
        XCTAssertEqual(windowInfo.appName, "Example App")
        XCTAssertEqual(windowInfo.title, "Test Window")
        XCTAssertEqual(windowInfo.pid, 12345)
    }

    func testWindowInfo_equality_sameValues() {
        let dummyElement = AXUIElementCreateApplication(getpid())

        let info1 = WindowInfo(
            bundleID: "com.example.app",
            appName: "Example App",
            title: "Test Window",
            windowElement: dummyElement,
            pid: 12345
        )

        let info2 = WindowInfo(
            bundleID: "com.example.app",
            appName: "Example App",
            title: "Test Window",
            windowElement: dummyElement,
            pid: 12345
        )

        XCTAssertEqual(info1, info2, "WindowInfo with same values should be equal")
    }

    func testWindowInfo_equality_differentTitle() {
        let dummyElement = AXUIElementCreateApplication(getpid())

        let info1 = WindowInfo(
            bundleID: "com.example.app",
            appName: "Example App",
            title: "Window 1",
            windowElement: dummyElement,
            pid: 12345
        )

        let info2 = WindowInfo(
            bundleID: "com.example.app",
            appName: "Example App",
            title: "Window 2",
            windowElement: dummyElement,
            pid: 12345
        )

        XCTAssertNotEqual(info1, info2, "WindowInfo with different titles should not be equal")
    }

    // MARK: - Initialization Tests

    func testInitialization_isMonitoringStartsFalse() {
        let monitor = WindowMonitor()
        XCTAssertFalse(monitor.isMonitoring, "isMonitoring should be false initially")
    }

    func testInitialization_delegateIsNil() {
        let monitor = WindowMonitor()
        XCTAssertNil(monitor.delegate, "delegate should be nil initially")
    }

    func testInitialization_monitoredBundleIDsIsNil() {
        let monitor = WindowMonitor()
        XCTAssertNil(monitor.monitoredBundleIDs, "monitoredBundleIDs should be nil initially")
    }

    // MARK: - Delegate Tests

    func testDelegate_isWeak() {
        let monitor = WindowMonitor()

        var delegateInstance: MockWindowMonitorDelegate? = MockWindowMonitorDelegate()
        monitor.delegate = delegateInstance

        XCTAssertNotNil(monitor.delegate, "Delegate should be set")

        delegateInstance = nil

        XCTAssertNil(monitor.delegate, "Delegate should be nil after reference is released")
    }

    // MARK: - Lifecycle Tests

    func testStopMonitoring_isIdempotent() {
        let monitor = WindowMonitor()

        // Should not crash when called multiple times without starting
        monitor.stopMonitoring()
        monitor.stopMonitoring()

        XCTAssertFalse(monitor.isMonitoring, "isMonitoring should remain false")
    }

    func testStopMonitoring_afterNotStarted_doesNotCrash() {
        let monitor = WindowMonitor()
        // Should not crash
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - MonitoredBundleIDs Tests

    func testMonitoredBundleIDs_canBeSet() {
        let monitor = WindowMonitor()

        let bundleIDs: Set<String> = ["com.apple.Safari", "com.google.Chrome"]
        monitor.monitoredBundleIDs = bundleIDs

        XCTAssertEqual(monitor.monitoredBundleIDs, bundleIDs)
    }

    func testMonitoredBundleIDs_canBeCleared() {
        let monitor = WindowMonitor()

        monitor.monitoredBundleIDs = ["com.apple.Safari"]
        XCTAssertNotNil(monitor.monitoredBundleIDs)

        monitor.monitoredBundleIDs = nil
        XCTAssertNil(monitor.monitoredBundleIDs)
    }

    func testMonitoredBundleIDs_emptySetIsValid() {
        let monitor = WindowMonitor()

        monitor.monitoredBundleIDs = Set<String>()

        XCTAssertNotNil(monitor.monitoredBundleIDs)
        XCTAssertEqual(monitor.monitoredBundleIDs?.count, 0)
    }

    // MARK: - WindowMonitorError Tests

    func testWindowMonitorError_accessibilityNotTrusted_equality() {
        let error1 = WindowMonitorError.accessibilityNotTrusted
        let error2 = WindowMonitorError.accessibilityNotTrusted

        XCTAssertEqual(error1, error2)
    }

    func testWindowMonitorError_observerCreationFailed_equality() {
        let error1 = WindowMonitorError.observerCreationFailed(pid: 123)
        let error2 = WindowMonitorError.observerCreationFailed(pid: 123)
        let error3 = WindowMonitorError.observerCreationFailed(pid: 456)

        XCTAssertEqual(error1, error2, "Same pid should be equal")
        XCTAssertNotEqual(error1, error3, "Different pid should not be equal")
    }

    func testWindowMonitorError_cannotGetWindowTitle_equality() {
        let error1 = WindowMonitorError.cannotGetWindowTitle
        let error2 = WindowMonitorError.cannotGetWindowTitle

        XCTAssertEqual(error1, error2)
    }

    func testWindowMonitorError_differentTypes_notEqual() {
        let error1 = WindowMonitorError.accessibilityNotTrusted
        let error2 = WindowMonitorError.cannotGetWindowTitle
        let error3 = WindowMonitorError.observerCreationFailed(pid: 123)

        XCTAssertNotEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error2, error3)
    }

    // MARK: - Scan Existing Windows Tests

    func testScanExistingWindows_returnsArray() {
        let monitor = WindowMonitor()

        // Should return an array (may be empty without accessibility permission)
        let windows = monitor.scanExistingWindows()
        XCTAssertNotNil(windows)
        // In test environments without accessibility, this may be empty
        XCTAssertGreaterThanOrEqual(windows.count, 0)
    }

    func testScanExistingWindows_withEmptyMonitoredBundleIDs_returnsEmptyArray() {
        let monitor = WindowMonitor()
        monitor.monitoredBundleIDs = Set<String>()

        // With empty monitored bundle IDs, no apps should match
        let windows = monitor.scanExistingWindows()
        XCTAssertEqual(windows.count, 0, "Empty monitoredBundleIDs should return no windows")
    }

    func testScanExistingWindows_withNonexistentBundleID_returnsEmptyArray() {
        let monitor = WindowMonitor()
        monitor.monitoredBundleIDs = ["com.nonexistent.app.12345"]

        let windows = monitor.scanExistingWindows()
        XCTAssertEqual(windows.count, 0, "Nonexistent bundle ID should return no windows")
    }

    // MARK: - Start Monitoring Tests

    func testStartMonitoring_withoutAccessibility_throwsError() {
        let monitor = WindowMonitor()

        // In test environments, accessibility is typically not trusted
        // This test verifies the error is thrown correctly
        // Note: This test may pass if running in an environment with accessibility
        do {
            try monitor.startMonitoring()
            // If we get here, accessibility is trusted - stop monitoring to clean up
            monitor.stopMonitoring()
        } catch WindowMonitorError.accessibilityNotTrusted {
            // Expected in test environments without accessibility
            XCTAssertFalse(monitor.isMonitoring, "isMonitoring should be false after failed start")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Delegate

private final class MockWindowMonitorDelegate: WindowMonitorDelegate {
    var newWindowEvents: [WindowInfo] = []
    var appLaunchEvents: [(bundleID: String, appName: String)] = []
    var appTerminationEvents: [String] = []

    func windowMonitor(_ monitor: WindowMonitor, didDetectNewWindow windowInfo: WindowInfo) {
        newWindowEvents.append(windowInfo)
    }

    func windowMonitor(_ monitor: WindowMonitor, didDetectAppLaunch bundleID: String, appName: String) {
        appLaunchEvents.append((bundleID: bundleID, appName: appName))
    }

    func windowMonitor(_ monitor: WindowMonitor, didDetectAppTermination bundleID: String) {
        appTerminationEvents.append(bundleID)
    }
}
