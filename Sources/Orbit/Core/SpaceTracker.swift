// SpaceTracker - Track current space and space changes
// Uses private CGS API for space ID tracking and NSWorkspace notifications for change detection

import AppKit
import CoreGraphics
import Foundation

// MARK: - Private API Declarations

public typealias CGSConnectionID = UInt32
public typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ connection: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: CGSConnectionID) -> CFArray?

// MARK: - SpaceTrackerDelegate

/// Protocol for receiving space change notifications
public protocol SpaceTrackerDelegate: AnyObject {
    /// Called when the active space changes
    /// - Parameters:
    ///   - tracker: The SpaceTracker instance
    ///   - spaceIndex: The 1-indexed space number (1 = leftmost)
    ///   - spaceID: The internal CGS space identifier
    func spaceTracker(_ tracker: SpaceTracker, didChangeToSpace spaceIndex: Int, spaceID: CGSSpaceID)
}

// MARK: - SpaceTracker

/// Tracks the current macOS Space and notifies of changes
///
/// Uses private CGS APIs to:
/// - Get the current active space ID
/// - Enumerate all user spaces to build an index map
///
/// Space indices are 1-indexed (1 = leftmost space, 2 = next, etc.)
public final class SpaceTracker: @unchecked Sendable {

    // MARK: - Properties

    /// Delegate for receiving space change notifications
    public weak var delegate: SpaceTrackerDelegate?

    /// The current active space's internal ID
    public private(set) var currentSpaceID: CGSSpaceID = 0

    /// The current active space's 1-indexed position (1 = leftmost)
    public private(set) var currentSpaceIndex: Int = 1

    /// Whether the tracker is actively observing space changes
    public private(set) var isTracking: Bool = false

    /// Maps space IDs to their 1-indexed positions
    private var spaceIDToIndex: [CGSSpaceID: Int] = [:]

    /// The CGS connection ID for this process
    private let connectionID: CGSConnectionID

    /// Token for the notification observer
    private var notificationObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// Initialize the space tracker
    public init() {
        self.connectionID = CGSMainConnectionID()
        refreshSpaceList()
        updateCurrentSpace()
    }

    deinit {
        stopTracking()
    }

    // MARK: - Public Methods

    /// Start observing space changes
    ///
    /// Adds an observer for NSWorkspace.activeSpaceDidChangeNotification.
    /// Calling this multiple times is safe (idempotent).
    public func startTracking() {
        guard !isTracking else { return }

        notificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }

        isTracking = true
        Logger.info("SpaceTracker: Started tracking, currently on space \(currentSpaceIndex) of \(spaceCount)", category: .monitor)
    }

    /// Stop observing space changes
    public func stopTracking() {
        guard isTracking else { return }

        if let observer = notificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            notificationObserver = nil
        }

        isTracking = false
    }

    /// Refresh the list of spaces and rebuild the ID-to-index map
    ///
    /// Call this if spaces have been added, removed, or reordered in Mission Control.
    public func refreshSpaceList() {
        spaceIDToIndex.removeAll()

        // CGSCopySpaces(connection, 1) used to return the user spaces here. On
        // current macOS it returns an EMPTY array, which cast cleanly to
        // [CGSSpaceID] and left this map empty - so every lookup below fell
        // through to `?? 1` and the tracker reported space 1 forever.
        //
        // CGSCopyManagedDisplaySpaces returns one dictionary per display, each
        // with a "Spaces" array in left-to-right order. Note the ordering
        // matters and the old API got it wrong even when it returned data:
        // mask 7 yields [3, 1] for spaces that are actually ordered 1, 3.
        guard let displays = CGSCopyManagedDisplaySpaces(connectionID) as? [[String: Any]] else {
            Logger.warning(
                "SpaceTracker: CGSCopyManagedDisplaySpaces returned nothing usable; "
                    + "space indices will be wrong",
                category: .monitor
            )
            return
        }

        // 1-indexed, continuing across displays.
        var index = 1
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                // type 0 = normal user space; 4 = fullscreen, which has no
                // position in the user-facing left-to-right ordering.
                guard (space["type"] as? Int) == 0,
                      let spaceID = space["id64"] as? CGSSpaceID else { continue }
                spaceIDToIndex[spaceID] = index
                index += 1
            }
        }
    }

    /// Get the 1-indexed position for a space ID
    /// - Parameter spaceID: The internal space ID
    /// - Returns: The 1-indexed position, or nil if not found
    public func spaceIndex(for spaceID: CGSSpaceID) -> Int? {
        return spaceIDToIndex[spaceID]
    }

    /// The total number of user spaces
    public var spaceCount: Int {
        return spaceIDToIndex.count
    }

    // MARK: - Private Methods

    /// Handle a space change notification
    private func handleSpaceChange() {
        // Refresh space list in case spaces were added/removed
        refreshSpaceList()
        updateCurrentSpace()
    }

    /// Update the current space and notify delegate if changed
    private func updateCurrentSpace() {
        let newSpaceID = CGSGetActiveSpace(connectionID)
        let newIndex = spaceIDToIndex[newSpaceID] ?? 1

        let didChange = newSpaceID != currentSpaceID
        let oldIndex = currentSpaceIndex

        currentSpaceID = newSpaceID
        currentSpaceIndex = newIndex

        if didChange {
            Logger.debug("SpaceTracker: Space changed from \(oldIndex) to \(newIndex)", category: .monitor)
            delegate?.spaceTracker(self, didChangeToSpace: newIndex, spaceID: newSpaceID)
        }
    }
}

// MARK: - SpaceChangeObserver

/// A simple observer for space changes using only public APIs
///
/// Use this as a fallback when private CGS APIs are unavailable.
/// It notifies on space changes but cannot provide space IDs or indices.
public final class SpaceChangeObserver: @unchecked Sendable {

    /// Handler called when the active space changes
    private let onChange: () -> Void

    /// Whether currently observing
    private var isObserving: Bool = false

    /// Notification observer token
    private var notificationObserver: NSObjectProtocol?

    /// Create a space change observer
    /// - Parameter onChange: Handler called when the active space changes
    public init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stopObserving()
    }

    /// Start observing space changes
    public func startObserving() {
        guard !isObserving else { return }

        notificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            self?.onChange()
        }

        isObserving = true
    }

    /// Stop observing space changes
    public func stopObserving() {
        guard isObserving else { return }

        if let observer = notificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            notificationObserver = nil
        }

        isObserving = false
    }
}
