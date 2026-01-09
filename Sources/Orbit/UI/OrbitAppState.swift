// OrbitAppState - Central state management for Orbit
// Coordinates ConfigManager, WindowMonitor, WindowMatcher, SpaceTracker, and SpaceMover

import SwiftUI
import Combine

/// Represents a recent window move action for display in the menu
public struct RecentMove: Identifiable, Sendable {
    public let id = UUID()
    public let appName: String
    public let windowTitle: String
    public let targetSpace: Int
    public let timestamp: Date

    public init(appName: String, windowTitle: String, targetSpace: Int, timestamp: Date = Date()) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.targetSpace = targetSpace
        self.timestamp = timestamp
    }
}

/// Central state object for the Orbit application
///
/// Coordinates all the core components:
/// - ConfigManager: Loading and watching configuration
/// - WindowMonitor: Detecting new windows
/// - WindowMatcher: Matching windows to rules
/// - SpaceTracker: Tracking current space
/// - SpaceMover: Moving windows between spaces
@MainActor
public final class OrbitAppState: ObservableObject {

    // MARK: - Published State

    /// Whether window monitoring is paused
    @Published public var isPaused: Bool = false

    /// Number of active rules loaded from config
    @Published public var ruleCount: Int = 0

    /// Recent window moves (most recent first, max 5)
    @Published public var recentMoves: [RecentMove] = []

    /// Current configuration error, if any
    @Published public var configError: String? = nil

    /// Whether accessibility permission is granted
    @Published public var hasAccessibility: Bool = false

    /// Last error that occurred during operation (for UI display)
    @Published public var lastError: String? = nil

    // MARK: - Components

    private let configManager: ConfigManager
    private let windowMonitor: WindowMonitor
    private var windowMatcher: WindowMatcher?
    private let spaceTracker: SpaceTracker
    private let spaceMover: SpaceMover
    private var shortcuts: Shortcuts = Shortcuts()

    /// Retry handler for transient failures
    private let retryHandler = RetryHandler(maxAttempts: 2, delayBetweenAttempts: 0.3)

    // MARK: - Initialization

    public init() {
        self.configManager = ConfigManager()
        self.windowMonitor = WindowMonitor()
        self.spaceTracker = SpaceTracker()
        self.spaceMover = SpaceMover()

        setup()
    }

    /// Initialize with custom config path (for testing)
    public init(configPath: String) {
        self.configManager = ConfigManager(configPath: configPath)
        self.windowMonitor = WindowMonitor()
        self.spaceTracker = SpaceTracker()
        self.spaceMover = SpaceMover()

        setup()
    }

    // MARK: - Setup

    private func setup() {
        Logger.info("Orbit starting up", category: .general)

        // Check accessibility permission
        hasAccessibility = SpaceMover.isAccessibilityTrusted()
        if hasAccessibility {
            Logger.info("Accessibility permission granted", category: .general)
        } else {
            Logger.warning("Accessibility permission not granted", category: .general)
        }

        // Load configuration
        loadConfig()

        // Start monitoring if we have accessibility
        if hasAccessibility {
            startMonitoring()
        }
    }

    // MARK: - Public Actions

    /// Load or reload the configuration
    public func loadConfig() {
        Logger.info("Loading configuration", category: .config)

        do {
            // Create default config if needed
            let created = try configManager.createDefaultConfigIfNeeded()
            if created {
                Logger.info("Created default configuration file", category: .config)
            }

            // Load config
            let config = try configManager.loadConfig()
            windowMatcher = WindowMatcher(rules: config.rules)
            shortcuts = config.shortcuts
            ruleCount = config.rules.count
            configError = nil
            lastError = nil

            Logger.info("Configuration loaded successfully with \(config.rules.count) rules", category: .config)

            // Note: WindowMonitor can filter by bundle ID, but our rules use app names
            // which match against both name and bundleID in WindowMatcher.
            // For now we'll monitor all apps and let the matcher filter.
            windowMonitor.monitoredBundleIDs = nil

        } catch let error as ConfigError {
            let errorMessage = describeConfigError(error)
            configError = errorMessage
            Logger.error("Config error: \(errorMessage)", category: .config)
        } catch {
            configError = error.localizedDescription
            Logger.error("Config error: \(error.localizedDescription)", category: .config)
        }
    }

    /// Toggle pause/resume state
    public func togglePause() {
        isPaused.toggle()
        if isPaused {
            Logger.info("Window monitoring paused", category: .monitor)
            windowMonitor.stopMonitoring()
        } else if hasAccessibility {
            Logger.info("Window monitoring resumed", category: .monitor)
            startMonitoring()
        }
    }

    /// Reload configuration from disk
    public func reloadConfig() {
        loadConfig()
        // If monitoring, restart to pick up new rules
        if !isPaused && hasAccessibility {
            windowMonitor.stopMonitoring()
            startMonitoring()
        }
    }

    /// Open configuration file in default editor
    public func openConfig() {
        configManager.openConfigInEditor()
    }

    /// Open log in Console.app filtered for Orbit
    public func openLog() {
        // Use 'log' command to stream Orbit logs in Terminal for better UX
        // Console.app filtering via AppleScript is unreliable, so we use Terminal with log stream
        let logCommand = "log stream --predicate 'subsystem == \"com.orbit.Orbit\"' --level debug"

        let script = """
            tell application "Terminal"
                activate
                do script "\(logCommand)"
            end tell
            """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                Logger.warning("Failed to open log stream: \(error)", category: .general)
            }
        }
        Logger.info("Opened log stream in Terminal", category: .general)
    }

    /// Request accessibility permission from user
    public func requestAccessibility() {
        SpaceMover.requestAccessibility()
        // Check again after a short delay (user might have granted permission)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hasAccessibility = SpaceMover.isAccessibilityTrusted()
            if self?.hasAccessibility == true && self?.isPaused == false {
                self?.startMonitoring()
            }
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        Logger.info("Starting window monitoring", category: .monitor)
        windowMonitor.delegate = self
        do {
            try windowMonitor.startMonitoring()
            spaceTracker.startTracking()

            // Scan existing windows and process them
            let existingWindows = windowMonitor.scanExistingWindows()
            Logger.debug("Scanning \(existingWindows.count) existing windows", category: .monitor)
            for windowInfo in existingWindows {
                processWindow(windowInfo)
            }
        } catch {
            // Accessibility error - update state
            Logger.error("Failed to start monitoring: \(error.localizedDescription)", category: .monitor)
            hasAccessibility = false
            lastError = "Failed to start monitoring: \(error.localizedDescription)"
        }
    }

    private func processWindow(_ windowInfo: WindowInfo) {
        guard !isPaused else { return }
        guard let matcher = windowMatcher else { return }

        Logger.debug("New window: \(windowInfo.appName) - \(windowInfo.title)", category: .monitor)

        if let result = matcher.match(windowInfo: windowInfo) {
            let currentSpace = spaceTracker.currentSpaceIndex
            let targetSpace = result.targetSpace

            Logger.info(
                "Matched window '\(windowInfo.title)' from \(windowInfo.appName) to space \(targetSpace)",
                category: .movement
            )

            // Only move if not already on target space
            guard currentSpace != targetSpace else {
                Logger.debug("Window already on target space \(targetSpace)", category: .movement)
                return
            }

            // Get shortcut for target space
            guard let shortcutString = shortcuts.shortcut(forSpace: targetSpace),
                  let shortcut = KeyboardShortcut.parse(shortcutString) else {
                // No shortcut configured for target space - try relative movement
                // For now, skip if no direct shortcut (relative movement is more complex)
                Logger.warning(
                    "No shortcut configured for space \(targetSpace), skipping move",
                    category: .movement
                )
                return
            }

            // Perform the move with retry for transient failures
            do {
                try retryHandler.execute {
                    try spaceMover.moveWindow(
                        windowInfo.windowElement,
                        toSpace: targetSpace,
                        fromSpace: currentSpace,
                        using: shortcut
                    )
                }

                // Record successful move
                addRecentMove(
                    appName: windowInfo.appName,
                    title: windowInfo.title,
                    space: targetSpace
                )
                Logger.info(
                    "Successfully moved '\(windowInfo.title)' to space \(targetSpace)",
                    category: .movement
                )
            } catch {
                // Move failed after retries
                let errorMessage = "Failed to move '\(windowInfo.title)': \(error.localizedDescription)"
                Logger.error(errorMessage, category: .movement)
                lastError = errorMessage
            }
        }
    }

    private func addRecentMove(appName: String, title: String, space: Int) {
        let move = RecentMove(
            appName: appName,
            windowTitle: title,
            targetSpace: space
        )
        recentMoves.insert(move, at: 0)
        if recentMoves.count > 5 {
            recentMoves.removeLast()
        }
    }

    private func describeConfigError(_ error: ConfigError) -> String {
        switch error {
        case .fileNotFound(let path):
            return "Config not found: \(path)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .fileSystemError(let message):
            return "File error: \(message)"
        }
    }
}

// MARK: - WindowMonitorDelegate

extension OrbitAppState: WindowMonitorDelegate {
    nonisolated public func windowMonitor(_ monitor: WindowMonitor, didDetectNewWindow windowInfo: WindowInfo) {
        Task { @MainActor in
            processWindow(windowInfo)
        }
    }

    nonisolated public func windowMonitor(_ monitor: WindowMonitor, didDetectAppLaunch bundleID: String, appName: String) {
        Logger.debug("App launched: \(appName) (\(bundleID))", category: .monitor)
    }

    nonisolated public func windowMonitor(_ monitor: WindowMonitor, didDetectAppTermination bundleID: String) {
        Logger.debug("App terminated: \(bundleID)", category: .monitor)
    }
}
