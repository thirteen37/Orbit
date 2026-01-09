// WindowMonitor - Detect window creation events using AXObserver
// Monitors running applications and notifies when new windows are created

@preconcurrency import ApplicationServices
import AppKit
import Foundation

// MARK: - WindowInfo

/// Information about a window detected by WindowMonitor
public struct WindowInfo: Equatable, Sendable {
    /// The bundle identifier of the application owning the window
    public let bundleID: String

    /// The display name of the application
    public let appName: String

    /// The window title
    public let title: String

    /// The accessibility element for the window
    public let windowElement: AXUIElement

    /// The process ID of the application
    public let pid: pid_t

    public init(
        bundleID: String,
        appName: String,
        title: String,
        windowElement: AXUIElement,
        pid: pid_t
    ) {
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.windowElement = windowElement
        self.pid = pid
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.bundleID == rhs.bundleID
            && lhs.appName == rhs.appName
            && lhs.title == rhs.title
            && lhs.pid == rhs.pid
            && CFEqual(lhs.windowElement, rhs.windowElement)
    }
}

// MARK: - WindowMonitorDelegate

/// Protocol for receiving window creation notifications
public protocol WindowMonitorDelegate: AnyObject {
    /// Called when a new window is detected
    /// - Parameters:
    ///   - monitor: The WindowMonitor instance
    ///   - windowInfo: Information about the new window
    func windowMonitor(_ monitor: WindowMonitor, didDetectNewWindow windowInfo: WindowInfo)

    /// Called when an application launches
    /// - Parameters:
    ///   - monitor: The WindowMonitor instance
    ///   - bundleID: The bundle identifier of the launched app
    ///   - appName: The display name of the launched app
    func windowMonitor(_ monitor: WindowMonitor, didDetectAppLaunch bundleID: String, appName: String)

    /// Called when an application terminates
    /// - Parameters:
    ///   - monitor: The WindowMonitor instance
    ///   - bundleID: The bundle identifier of the terminated app
    func windowMonitor(_ monitor: WindowMonitor, didDetectAppTermination bundleID: String)
}

// Default implementations for optional delegate methods
public extension WindowMonitorDelegate {
    func windowMonitor(_ monitor: WindowMonitor, didDetectAppLaunch bundleID: String, appName: String) {}
    func windowMonitor(_ monitor: WindowMonitor, didDetectAppTermination bundleID: String) {}
}

// MARK: - WindowMonitorError

/// Errors that can occur during window monitoring
public enum WindowMonitorError: Error, Equatable {
    /// Accessibility is not trusted for this application
    case accessibilityNotTrusted

    /// Failed to create an AXObserver for the given process
    case observerCreationFailed(pid: pid_t)

    /// Cannot retrieve the window title
    case cannotGetWindowTitle
}

// MARK: - WindowMonitor

/// Monitors window creation events across applications
///
/// Uses AXObserver to watch for `kAXWindowCreatedNotification` on each
/// monitored application. Notifies the delegate when new windows are detected.
///
/// Usage:
/// ```swift
/// let monitor = WindowMonitor()
/// monitor.delegate = self
/// monitor.monitoredBundleIDs = ["com.apple.Safari", "com.google.Chrome"]
/// try monitor.startMonitoring()
/// ```
public final class WindowMonitor: @unchecked Sendable {

    // MARK: - Properties

    /// Delegate for receiving window creation notifications
    public weak var delegate: WindowMonitorDelegate?

    /// Whether the monitor is actively observing window creation
    public private(set) var isMonitoring: Bool = false

    /// Bundle IDs to monitor. If nil, monitors all regular (non-background) applications.
    public var monitoredBundleIDs: Set<String>?

    /// AXObserver instances keyed by process ID
    private var observers: [pid_t: AXObserver] = [:]

    /// App info (bundleID, appName) keyed by process ID
    private var appInfo: [pid_t: (bundleID: String, appName: String)] = [:]

    /// Notification observers for app launch/termination
    private var launchObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// Create a new WindowMonitor
    public init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Start monitoring for window creation events
    ///
    /// - Throws: `WindowMonitorError.accessibilityNotTrusted` if Accessibility is not enabled
    public func startMonitoring() throws {
        guard !isMonitoring else { return }

        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            Logger.warning("WindowMonitor: Accessibility not trusted", category: .monitor)
            throw WindowMonitorError.accessibilityNotTrusted
        }

        // Register for app launch/termination notifications
        setupWorkspaceObservers()

        // Register observers for currently running apps
        var registeredCount = 0
        for app in NSWorkspace.shared.runningApplications {
            if registerObserver(for: app) {
                registeredCount += 1
            }
        }

        isMonitoring = true
        Logger.info("WindowMonitor: Started monitoring \(registeredCount) apps", category: .monitor)
    }

    /// Stop monitoring for window creation events
    ///
    /// Removes all AXObservers and workspace notification observers.
    /// Safe to call multiple times (idempotent).
    public func stopMonitoring() {
        guard isMonitoring else { return }

        // Remove workspace observers
        if let observer = launchObserver {
            NotificationCenter.default.removeObserver(observer)
            launchObserver = nil
        }
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
            terminationObserver = nil
        }

        // Remove all AXObservers
        for (pid, observer) in observers {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            // Remove notification from the app element
            let appElement = AXUIElementCreateApplication(pid)
            AXObserverRemoveNotification(
                observer,
                appElement,
                kAXWindowCreatedNotification as CFString
            )
        }
        observers.removeAll()
        appInfo.removeAll()

        isMonitoring = false
    }

    /// Scan all windows from monitored applications
    ///
    /// - Returns: Array of WindowInfo for all existing windows
    public func scanExistingWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        for app in NSWorkspace.shared.runningApplications {
            guard shouldMonitor(app: app) else { continue }
            guard let bundleID = app.bundleIdentifier else { continue }

            let appName = app.localizedName ?? bundleID
            let pid = app.processIdentifier

            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            guard result == .success,
                let windowList = windowsRef as? [AXUIElement]
            else {
                continue
            }

            for windowElement in windowList {
                if let title = getWindowTitle(windowElement) {
                    let windowInfo = WindowInfo(
                        bundleID: bundleID,
                        appName: appName,
                        title: title,
                        windowElement: windowElement,
                        pid: pid
                    )
                    windows.append(windowInfo)
                }
            }
        }

        return windows
    }

    // MARK: - Private Methods

    /// Setup NSWorkspace observers for app launch/termination
    private func setupWorkspaceObservers() {
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.handleAppLaunch(app)
        }

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.handleAppTermination(app)
        }
    }

    /// Handle an application launch event
    private func handleAppLaunch(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }

        registerObserver(for: app)

        let appName = app.localizedName ?? bundleID
        delegate?.windowMonitor(self, didDetectAppLaunch: bundleID, appName: appName)
    }

    /// Handle an application termination event
    private func handleAppTermination(_ app: NSRunningApplication) {
        let pid = app.processIdentifier

        // Remove the observer for this app
        if let observer = observers[pid] {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            observers.removeValue(forKey: pid)
        }

        if let info = appInfo.removeValue(forKey: pid) {
            delegate?.windowMonitor(self, didDetectAppTermination: info.bundleID)
        }
    }

    /// Register an AXObserver for an application
    /// - Returns: true if observer was registered successfully
    @discardableResult
    private func registerObserver(for app: NSRunningApplication) -> Bool {
        guard shouldMonitor(app: app) else { return false }
        guard let bundleID = app.bundleIdentifier else { return false }

        let pid = app.processIdentifier

        // Don't register duplicate observers
        guard observers[pid] == nil else { return false }

        // Store app info
        let appName = app.localizedName ?? bundleID
        appInfo[pid] = (bundleID: bundleID, appName: appName)

        // Create AXObserver
        var observer: AXObserver?
        let result = AXObserverCreate(
            pid,
            windowCreatedCallback,
            &observer
        )

        guard result == .success, let observer = observer else {
            Logger.debug("WindowMonitor: Failed to create observer for \(appName) (pid \(pid))", category: .monitor)
            return false
        }

        // Add notification for window creation
        let appElement = AXUIElementCreateApplication(pid)
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXWindowCreatedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )

        guard addResult == .success else {
            Logger.debug("WindowMonitor: Failed to add notification for \(appName) (pid \(pid))", category: .monitor)
            return false
        }

        // Add to run loop
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[pid] = observer
        Logger.debug("WindowMonitor: Registered observer for \(appName) (\(bundleID))", category: .monitor)
        return true
    }

    /// Check if an app should be monitored
    private func shouldMonitor(app: NSRunningApplication) -> Bool {
        // Only monitor regular apps (not background agents, menu extras, etc.)
        guard app.activationPolicy == .regular else { return false }
        guard let bundleID = app.bundleIdentifier else { return false }

        // If monitoredBundleIDs is set, only monitor those apps
        if let monitored = monitoredBundleIDs {
            return monitored.contains(bundleID)
        }

        // Otherwise monitor all regular apps
        return true
    }

    /// Handle a window creation notification
    fileprivate func handleWindowCreated(_ windowElement: AXUIElement, pid: pid_t) {
        guard let info = appInfo[pid] else {
            Logger.debug("WindowMonitor: Window created for unknown pid \(pid)", category: .monitor)
            return
        }

        Logger.debug("WindowMonitor: Window created callback for \(info.appName) (pid \(pid))", category: .monitor)

        // Delay briefly to allow window title to be set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            guard let title = self.getWindowTitle(windowElement) else {
                Logger.debug("WindowMonitor: Could not get title for window from \(info.appName)", category: .monitor)
                return
            }

            Logger.debug("WindowMonitor: Window title: '\(title)' from \(info.appName)", category: .monitor)

            let windowInfo = WindowInfo(
                bundleID: info.bundleID,
                appName: info.appName,
                title: title,
                windowElement: windowElement,
                pid: pid
            )

            self.delegate?.windowMonitor(self, didDetectNewWindow: windowInfo)
        }
    }

    /// Get the title of a window element
    private func getWindowTitle(_ window: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleRef
        )

        guard result == .success, let title = titleRef as? String else {
            return nil
        }

        return title
    }
}

// MARK: - AXObserver Callback

/// C callback function for AXObserver window creation events
private func windowCreatedCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }

    let monitor = Unmanaged<WindowMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // Get the pid from the element
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)

    monitor.handleWindowCreated(element, pid: pid)
}
