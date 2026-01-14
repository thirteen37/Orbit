// SettingsViewModel - View model for settings editing
// Manages working copy of config for editing with save/revert

import SwiftUI
import Combine

/// View model for editing Orbit settings
@MainActor
public final class SettingsViewModel: ObservableObject {

    // MARK: - Working Copy (Editable)

    /// Log level setting
    @Published public var logLevel: String

    /// Keyboard shortcuts for space switching
    @Published public var shortcuts: Shortcuts

    /// Window-to-space rules
    @Published public var rules: [Rule]

    // MARK: - State

    /// Whether there are unsaved changes
    @Published public var hasUnsavedChanges: Bool = false

    /// Validation errors (empty if valid)
    @Published public var validationErrors: [String] = []

    /// Whether a save is in progress
    @Published public var isSaving: Bool = false

    /// Error message from last save attempt
    @Published public var saveError: String?

    // MARK: - Private

    private let configManager: ConfigManager
    private var originalConfig: OrbitConfig
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(configManager: ConfigManager, config: OrbitConfig) {
        self.configManager = configManager
        self.originalConfig = config

        // Initialize working copy from config
        self.logLevel = config.settings.logLevel
        self.shortcuts = config.shortcuts
        self.rules = config.rules

        setupChangeTracking()
    }

    // MARK: - Change Tracking

    private func setupChangeTracking() {
        // Monitor changes to set hasUnsavedChanges flag
        $logLevel
            .dropFirst()
            .sink { [weak self] _ in self?.hasUnsavedChanges = true }
            .store(in: &cancellables)

        $shortcuts
            .dropFirst()
            .sink { [weak self] _ in self?.hasUnsavedChanges = true }
            .store(in: &cancellables)

        $rules
            .dropFirst()
            .sink { [weak self] _ in self?.hasUnsavedChanges = true }
            .store(in: &cancellables)
    }

    // MARK: - Validation

    /// Valid log levels
    public static let validLogLevels = ["error", "warning", "info", "debug"]

    /// Validate current settings
    /// Returns true if valid, false otherwise (with errors in validationErrors)
    public func validate() -> Bool {
        var errors: [String] = []

        // Validate log level
        if !Self.validLogLevels.contains(logLevel) {
            errors.append("Invalid log level: '\(logLevel)'")
        }

        // Validate rules
        for (index, rule) in rules.enumerated() {
            do {
                try rule.validate()
            } catch let error as RuleValidationError {
                errors.append("Rule \(index + 1): \(describeRuleError(error))")
            } catch {
                errors.append("Rule \(index + 1): Unknown error")
            }
        }

        validationErrors = errors
        return errors.isEmpty
    }

    private func describeRuleError(_ error: RuleValidationError) -> String {
        switch error {
        case .emptyAppName:
            return "Application name is required"
        case .invalidSpaceNumber(let n):
            return "Invalid space number: \(n)"
        case .invalidRegexPattern(let pattern):
            return "Invalid regex pattern: \(pattern)"
        case .bothTitleMatchersSpecified:
            return "Cannot specify both title_contains and title_pattern"
        }
    }

    // MARK: - Save & Revert

    /// Save current settings to config file
    public func save() async throws {
        guard validate() else {
            throw ConfigError.validationError(message: validationErrors.joined(separator: "; "))
        }

        isSaving = true
        defer { isSaving = false }

        let newConfig = OrbitConfig(
            settings: Settings(logLevel: logLevel),
            shortcuts: shortcuts,
            rules: rules
        )

        try configManager.saveConfig(newConfig)

        originalConfig = newConfig
        hasUnsavedChanges = false
        saveError = nil
    }

    /// Revert changes to original config
    public func revertChanges() {
        logLevel = originalConfig.settings.logLevel
        shortcuts = originalConfig.shortcuts
        rules = originalConfig.rules
        hasUnsavedChanges = false
        validationErrors = []
        saveError = nil
    }

    // MARK: - Rule CRUD

    /// Add a new rule
    public func addRule(_ rule: Rule) {
        rules.append(rule)
    }

    /// Update a rule at the given index
    public func updateRule(at index: Int, with rule: Rule) {
        guard rules.indices.contains(index) else { return }
        rules[index] = rule
    }

    /// Delete a rule at the given index
    public func deleteRule(at index: Int) {
        guard rules.indices.contains(index) else { return }
        rules.remove(at: index)
    }

    /// Move rules (for reordering)
    public func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
    }
}
