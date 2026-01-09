// SpaceTrackerTests - Tests for SpaceTracker component

import XCTest
@testable import Orbit

final class SpaceTrackerTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_isTrackingStartsFalse() {
        let tracker = SpaceTracker()
        XCTAssertFalse(tracker.isTracking, "isTracking should be false initially")
    }

    func testInitialization_currentSpaceIndexIsAtLeastOne() {
        let tracker = SpaceTracker()
        XCTAssertGreaterThanOrEqual(tracker.currentSpaceIndex, 1, "currentSpaceIndex should be >= 1")
    }

    // MARK: - Tracking Lifecycle Tests

    func testStartTracking_setsIsTrackingTrue() {
        let tracker = SpaceTracker()
        tracker.startTracking()
        XCTAssertTrue(tracker.isTracking, "isTracking should be true after startTracking")
        tracker.stopTracking()
    }

    func testStopTracking_setsIsTrackingFalse() {
        let tracker = SpaceTracker()
        tracker.startTracking()
        tracker.stopTracking()
        XCTAssertFalse(tracker.isTracking, "isTracking should be false after stopTracking")
    }

    func testStartTracking_isIdempotent() {
        // Calling startTracking multiple times should not add duplicate observers
        let tracker = SpaceTracker()

        tracker.startTracking()
        XCTAssertTrue(tracker.isTracking)

        tracker.startTracking() // Second call
        XCTAssertTrue(tracker.isTracking)

        tracker.stopTracking() // Should only need one stop
        XCTAssertFalse(tracker.isTracking, "Single stopTracking should work after multiple starts")
    }

    func testStopTracking_isIdempotent() {
        let tracker = SpaceTracker()
        tracker.startTracking()
        tracker.stopTracking()
        tracker.stopTracking() // Should not crash
        XCTAssertFalse(tracker.isTracking)
    }

    // MARK: - Space Query Tests

    func testSpaceCount_isNonNegative() {
        // Note: spaceCount may be 0 in test environments where CGS APIs don't work
        // (e.g., headless CI, sandboxed test runners)
        // In a real GUI session, this would be >= 1
        let tracker = SpaceTracker()
        XCTAssertGreaterThanOrEqual(tracker.spaceCount, 0, "spaceCount should be >= 0")
    }

    func testRefreshSpaceList_doesNotCrash() {
        let tracker = SpaceTracker()
        // Should not crash
        tracker.refreshSpaceList()
        XCTAssertGreaterThanOrEqual(tracker.spaceCount, 0)
    }

    func testCurrentSpaceIndex_isWithinBounds() {
        let tracker = SpaceTracker()
        let maxBound = max(tracker.spaceCount, 1)
        XCTAssertGreaterThanOrEqual(tracker.currentSpaceIndex, 1, "currentSpaceIndex should be >= 1")
        XCTAssertLessThanOrEqual(tracker.currentSpaceIndex, maxBound, "currentSpaceIndex should be <= spaceCount")
    }

    func testSpaceIndexForCurrentSpaceID_returnsCurrentSpaceIndex() {
        let tracker = SpaceTracker()
        // In test environments, CGS APIs may not work (currentSpaceID = 0, empty space list)
        // Only verify the relationship if we have valid data
        if tracker.currentSpaceID != 0 && tracker.spaceCount > 0 {
            let index = tracker.spaceIndex(for: tracker.currentSpaceID)
            XCTAssertEqual(index, tracker.currentSpaceIndex,
                "spaceIndex(for: currentSpaceID) should return currentSpaceIndex")
        } else {
            // CGS APIs not available in this environment - skip verification
            // This is expected in headless test environments
        }
    }

    func testSpaceIndexForUnknownID_returnsNil() {
        let tracker = SpaceTracker()
        // Use an unlikely ID
        let unknownID: CGSSpaceID = UInt64.max - 12345
        XCTAssertNil(tracker.spaceIndex(for: unknownID), "Unknown space ID should return nil")
    }

    // MARK: - Delegate Tests

    func testDelegate_isWeak() {
        let tracker = SpaceTracker()

        var delegateInstance: MockSpaceTrackerDelegate? = MockSpaceTrackerDelegate()
        tracker.delegate = delegateInstance

        XCTAssertNotNil(tracker.delegate, "Delegate should be set")

        delegateInstance = nil

        XCTAssertNil(tracker.delegate, "Delegate should be nil after reference is released")
    }

    // MARK: - SpaceChangeObserver Tests

    func testSpaceChangeObserver_startStopWorks() {
        var changeCount = 0
        let observer = SpaceChangeObserver {
            changeCount += 1
        }

        // Should not crash
        observer.startObserving()
        observer.stopObserving()
    }

    func testSpaceChangeObserver_startIsIdempotent() {
        var changeCount = 0
        let observer = SpaceChangeObserver {
            changeCount += 1
        }

        observer.startObserving()
        observer.startObserving() // Second call should be safe
        observer.stopObserving()
    }

    func testSpaceChangeObserver_stopIsIdempotent() {
        var changeCount = 0
        let observer = SpaceChangeObserver {
            changeCount += 1
        }

        observer.startObserving()
        observer.stopObserving()
        observer.stopObserving() // Should not crash
    }
}

// MARK: - Mock Delegate

private final class MockSpaceTrackerDelegate: SpaceTrackerDelegate {
    var lastSpaceIndex: Int?
    var lastSpaceID: CGSSpaceID?
    var changeCount: Int = 0

    func spaceTracker(_ tracker: SpaceTracker, didChangeToSpace spaceIndex: Int, spaceID: CGSSpaceID) {
        lastSpaceIndex = spaceIndex
        lastSpaceID = spaceID
        changeCount += 1
    }
}
