@preconcurrency import ApplicationServices
import AppKit
import Foundation

/// Manages accessibility permission checking and requesting
public final class AccessibilityPermission: @unchecked Sendable {

    /// Shared instance
    public static let shared = AccessibilityPermission()

    /// Notification posted when accessibility status changes
    public static let statusDidChangeNotification = Notification.Name("AccessibilityPermissionStatusDidChange")

    /// Current permission status
    public enum Status: Equatable, Sendable {
        case granted
        case denied
        case unknown
    }

    /// Check if accessibility permission is granted
    public var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Get current status
    public var status: Status {
        if AXIsProcessTrusted() {
            return .granted
        }
        // Can't distinguish denied from unknown without trying
        return .denied
    }

    private var pollTimer: Timer?
    private var lastPolledStatus: Bool = false

    private init() {}

    /// Request accessibility permission (shows system prompt)
    /// Returns immediately - user must grant in System Settings
    public func request() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to Accessibility pane
    public func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Start polling for permission changes
    /// Posts statusDidChangeNotification when status changes
    public func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()

        lastPolledStatus = isGranted

        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentStatus = self.isGranted
            if currentStatus != self.lastPolledStatus {
                self.lastPolledStatus = currentStatus
                NotificationCenter.default.post(
                    name: Self.statusDidChangeNotification,
                    object: self,
                    userInfo: ["isGranted": currentStatus]
                )
            }
        }
    }

    /// Stop polling for permission changes
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Check and request if needed, with callback
    /// - Parameters:
    ///   - showPrompt: Whether to show system prompt if not granted
    ///   - completion: Called with result (true if granted)
    public func checkAndRequest(showPrompt: Bool = true, completion: @escaping @Sendable (Bool) -> Void) {
        if isGranted {
            completion(true)
            return
        }

        if showPrompt {
            request()
        }

        // Start polling temporarily to detect when user grants permission
        let observer = PermissionObserver(permission: self, completion: completion)
        observer.startObserving()

        startPolling()
    }
}

/// Helper class to observe permission changes
private final class PermissionObserver: @unchecked Sendable {
    private weak var permission: AccessibilityPermission?
    private let completion: @Sendable (Bool) -> Void
    private var observerToken: NSObjectProtocol?

    init(permission: AccessibilityPermission, completion: @escaping @Sendable (Bool) -> Void) {
        self.permission = permission
        self.completion = completion
    }

    func startObserving() {
        observerToken = NotificationCenter.default.addObserver(
            forName: AccessibilityPermission.statusDidChangeNotification,
            object: permission,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let granted = notification.userInfo?["isGranted"] as? Bool, granted {
                self.stopObserving()
                self.permission?.stopPolling()
                self.completion(true)
            }
        }
    }

    func stopObserving() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
    }
}
