import Foundation
import TOMLKit
import AppKit

/// Keyboard shortcuts for space switching
public struct Shortcuts: Codable, Equatable, Sendable {
    /// Maps space number (1-9) to shortcut string (e.g., "ctrl+1")
    public var directJumps: [Int: String]
    /// Shortcut for moving to space on the left
    public var spaceLeft: String?
    /// Shortcut for moving to space on the right
    public var spaceRight: String?

    private enum CodingKeys: String, CodingKey {
        case space_1, space_2, space_3, space_4, space_5
        case space_6, space_7, space_8, space_9
        case space_left, space_right
    }

    public init(directJumps: [Int: String] = [:], spaceLeft: String? = nil, spaceRight: String? = nil) {
        self.directJumps = directJumps
        self.spaceLeft = spaceLeft
        self.spaceRight = spaceRight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var jumps: [Int: String] = [:]
        if let s = try container.decodeIfPresent(String.self, forKey: .space_1) { jumps[1] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_2) { jumps[2] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_3) { jumps[3] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_4) { jumps[4] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_5) { jumps[5] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_6) { jumps[6] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_7) { jumps[7] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_8) { jumps[8] = s }
        if let s = try container.decodeIfPresent(String.self, forKey: .space_9) { jumps[9] = s }

        self.directJumps = jumps
        self.spaceLeft = try container.decodeIfPresent(String.self, forKey: .space_left)
        self.spaceRight = try container.decodeIfPresent(String.self, forKey: .space_right)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let s = directJumps[1] { try container.encode(s, forKey: .space_1) }
        if let s = directJumps[2] { try container.encode(s, forKey: .space_2) }
        if let s = directJumps[3] { try container.encode(s, forKey: .space_3) }
        if let s = directJumps[4] { try container.encode(s, forKey: .space_4) }
        if let s = directJumps[5] { try container.encode(s, forKey: .space_5) }
        if let s = directJumps[6] { try container.encode(s, forKey: .space_6) }
        if let s = directJumps[7] { try container.encode(s, forKey: .space_7) }
        if let s = directJumps[8] { try container.encode(s, forKey: .space_8) }
        if let s = directJumps[9] { try container.encode(s, forKey: .space_9) }

        try container.encodeIfPresent(spaceLeft, forKey: .space_left)
        try container.encodeIfPresent(spaceRight, forKey: .space_right)
    }

    /// Get the shortcut for a specific space number
    public func shortcut(forSpace space: Int) -> String? {
        return directJumps[space]
    }
}

/// Application settings
public struct Settings: Codable, Equatable, Sendable {
    /// Log level: error, warning, info, debug
    public var logLevel: String

    private enum CodingKeys: String, CodingKey {
        case logLevel = "log_level"
    }

    public init(logLevel: String = "info") {
        self.logLevel = logLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel) ?? "info"
    }
}

/// Complete Orbit configuration
public struct OrbitConfig: Codable, Equatable, Sendable {
    public var settings: Settings
    public var shortcuts: Shortcuts
    public var rules: [Rule]

    public init(settings: Settings = Settings(), shortcuts: Shortcuts = Shortcuts(), rules: [Rule] = []) {
        self.settings = settings
        self.shortcuts = shortcuts
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.settings = try container.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        self.shortcuts = try container.decodeIfPresent(Shortcuts.self, forKey: .shortcuts) ?? Shortcuts()
        self.rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case settings
        case shortcuts
        case rules
    }

    /// Validate all rules and return any validation errors
    public func validateRules() -> [(index: Int, error: RuleValidationError)] {
        var errors: [(index: Int, error: RuleValidationError)] = []
        for (index, rule) in rules.enumerated() {
            do {
                try rule.validate()
            } catch let error as RuleValidationError {
                errors.append((index: index, error: error))
            } catch {
                // Unexpected error type - shouldn't happen
            }
        }
        return errors
    }
}

/// Delegate protocol for config manager events
public protocol ConfigManagerDelegate: AnyObject {
    func configManagerDidReloadConfig(_ manager: ConfigManager, config: OrbitConfig)
    func configManager(_ manager: ConfigManager, didEncounterError error: ConfigError)
}

/// Errors that can occur during config operations
public enum ConfigError: Error, Equatable {
    case fileNotFound(path: String)
    case parseError(message: String)
    case validationError(message: String)
    case fileSystemError(message: String)
}

/// Manages loading, watching, and reloading of Orbit configuration
public final class ConfigManager: @unchecked Sendable {
    public weak var delegate: ConfigManagerDelegate?
    public private(set) var config: OrbitConfig?
    public let configPath: String
    public private(set) var isWatching: Bool = false

    private var lastValidConfig: OrbitConfig?
    private var eventStream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5

    /// Default config path: ~/.config/orbit/config.toml
    public static var defaultConfigPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/orbit/config.toml"
    }

    /// Sample configuration template
    public static let sampleConfig: String = """
        # Orbit Configuration
        # See https://github.com/user/orbit for documentation

        # Application settings
        [settings]
        # Log level: error, warning, info, debug
        log_level = "info"

        # Keyboard shortcuts for switching spaces
        # These should match your System Settings > Keyboard > Shortcuts > Mission Control
        [shortcuts]
        # Direct jump shortcuts (Ctrl+Number)
        space_1 = "ctrl+1"
        space_2 = "ctrl+2"
        space_3 = "ctrl+3"
        space_4 = "ctrl+4"
        space_5 = "ctrl+5"

        # Relative movement shortcuts (used as fallback)
        space_left = "ctrl+left"
        space_right = "ctrl+right"

        # Window-to-space rules
        # Each rule matches windows and assigns them to a space

        # Example: Move Chrome windows with "Work" in title to space 1
        # [[rules]]
        # app = "Google Chrome"
        # title_contains = "Work"
        # space = 1

        # Example: Move Chrome windows with "Personal" in title to space 2
        # [[rules]]
        # app = "Google Chrome"
        # title_contains = "Personal"
        # space = 2

        # Example: Move Terminal windows matching regex to space 3
        # [[rules]]
        # app = "Terminal"
        # title_pattern = "^dev-.*"
        # space = 3
        """

    public init(configPath: String) {
        self.configPath = configPath
    }

    public convenience init() {
        self.init(configPath: ConfigManager.defaultConfigPath)
    }

    deinit {
        stopWatching()
    }

    /// Load and parse the configuration file
    public func loadConfig() throws -> OrbitConfig {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: configPath) else {
            throw ConfigError.fileNotFound(path: configPath)
        }

        let contents: String
        do {
            contents = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            throw ConfigError.fileSystemError(message: "Failed to read file: \(error.localizedDescription)")
        }

        let config: OrbitConfig
        do {
            config = try TOMLDecoder().decode(OrbitConfig.self, from: contents)
        } catch {
            throw ConfigError.parseError(message: "Failed to parse TOML: \(error.localizedDescription)")
        }

        // Validate rules
        let validationErrors = config.validateRules()
        if !validationErrors.isEmpty {
            let messages = validationErrors.map { "Rule \($0.index): \($0.error)" }
            throw ConfigError.validationError(message: messages.joined(separator: "; "))
        }

        self.config = config
        self.lastValidConfig = config
        return config
    }

    /// Reload the configuration and notify delegate
    public func reloadConfig() {
        do {
            let newConfig = try loadConfig()
            delegate?.configManagerDidReloadConfig(self, config: newConfig)
        } catch let error as ConfigError {
            delegate?.configManager(self, didEncounterError: error)
            // Keep using last valid config
        } catch {
            delegate?.configManager(self, didEncounterError: .parseError(message: error.localizedDescription))
        }
    }

    /// Start watching the config file for changes
    public func startWatching() {
        guard !isWatching else { return }

        let configURL = URL(fileURLWithPath: configPath)
        let directoryPath = configURL.deletingLastPathComponent().path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let info = clientCallBackInfo else { return }
            let manager = Unmanaged<ConfigManager>.fromOpaque(info).takeUnretainedValue()
            manager.handleFileSystemEvent()
        }

        let pathsToWatch = [directoryPath] as CFArray

        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
            isWatching = true
        }
    }

    /// Stop watching the config file
    public func stopWatching() {
        guard isWatching else { return }

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }

        debounceTimer?.invalidate()
        debounceTimer = nil
        isWatching = false
    }

    /// Create a default config file if one doesn't exist
    /// Returns true if a new file was created
    @discardableResult
    public func createDefaultConfigIfNeeded() throws -> Bool {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: configPath) {
            return false
        }

        // Create directory if needed
        let configURL = URL(fileURLWithPath: configPath)
        let directoryURL = configURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.fileSystemError(message: "Failed to create config directory: \(error.localizedDescription)")
        }

        // Write sample config
        do {
            try ConfigManager.sampleConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileSystemError(message: "Failed to write config file: \(error.localizedDescription)")
        }

        return true
    }

    /// Open the config file in the default editor
    public func openConfigInEditor() {
        let url = URL(fileURLWithPath: configPath)
        NSWorkspace.shared.open(url)
    }

    /// Save configuration to disk
    /// Pauses file watcher during save to avoid triggering reload
    public func saveConfig(_ config: OrbitConfig) throws {
        let wasWatching = isWatching
        if wasWatching {
            stopWatching()
        }

        defer {
            if wasWatching {
                startWatching()
            }
        }

        // Validate rules before saving
        let validationErrors = config.validateRules()
        if !validationErrors.isEmpty {
            let messages = validationErrors.map { "Rule \($0.index + 1): \($0.error)" }
            throw ConfigError.validationError(message: messages.joined(separator: "; "))
        }

        // Encode to TOML
        let table: TOMLTable
        do {
            table = try TOMLEncoder().encode(config)
        } catch {
            throw ConfigError.parseError(message: "Failed to encode config: \(error.localizedDescription)")
        }

        // Add header comment
        let header = """
            # Orbit Configuration
            # Generated by Orbit Settings - manual edits are preserved on next save
            # See https://github.com/user/orbit for documentation

            """
        let tomlString = header + table.convert(to: .toml)

        // Ensure directory exists
        let configURL = URL(fileURLWithPath: configPath)
        let directoryURL = configURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.fileSystemError(message: "Failed to create config directory: \(error.localizedDescription)")
        }

        // Write file atomically
        do {
            try tomlString.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileSystemError(message: "Failed to write config: \(error.localizedDescription)")
        }

        // Update internal state
        self.config = config
        self.lastValidConfig = config

        Logger.info("Configuration saved successfully", category: .config)
    }

    // MARK: - Private

    private func handleFileSystemEvent() {
        // Debounce: wait 500ms after last change before reloading
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.reloadConfig()
        }
    }
}
