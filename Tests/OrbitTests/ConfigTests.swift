import Testing
import Foundation
@testable import Orbit

// MARK: - Rule Tests

@Suite("Rule Matching Tests")
struct RuleMatchingTests {

    @Test("Rule matches by app name case-insensitively")
    func matchesByAppName() {
        let rule = Rule(app: "Google Chrome", space: 1)

        #expect(rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Test"))
        #expect(rule.matches(appName: "google chrome", bundleID: "com.google.Chrome", windowTitle: "Test"))
        #expect(rule.matches(appName: "GOOGLE CHROME", bundleID: "com.google.Chrome", windowTitle: "Test"))
    }

    @Test("Rule matches by bundle ID case-insensitively")
    func matchesByBundleID() {
        let rule = Rule(app: "com.google.Chrome", space: 1)

        #expect(rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Test"))
        #expect(rule.matches(appName: "Google Chrome", bundleID: "COM.GOOGLE.CHROME", windowTitle: "Test"))
    }

    @Test("Rule does not match wrong app")
    func doesNotMatchWrongApp() {
        let rule = Rule(app: "Safari", space: 1)

        #expect(!rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Test"))
    }

    @Test("Rule matches with titleContains case-insensitively")
    func matchesTitleContains() {
        let rule = Rule(app: "Google Chrome", titleContains: "Work", space: 1)

        #expect(rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Work Project"))
        #expect(rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "My WORK stuff"))
        #expect(rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "working on it"))
    }

    @Test("Rule does not match wrong title with titleContains")
    func doesNotMatchWrongTitleContains() {
        let rule = Rule(app: "Google Chrome", titleContains: "Work", space: 1)

        #expect(!rule.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Personal Stuff"))
    }

    @Test("Rule matches with titlePattern regex")
    func matchesTitlePattern() {
        let rule = Rule(app: "Terminal", titlePattern: "^dev-.*", space: 3)

        #expect(rule.matches(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "dev-server"))
        #expect(rule.matches(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "dev-frontend"))
    }

    @Test("Rule does not match wrong title with titlePattern")
    func doesNotMatchWrongTitlePattern() {
        let rule = Rule(app: "Terminal", titlePattern: "^dev-.*", space: 3)

        #expect(!rule.matches(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "my-dev-server"))
        #expect(!rule.matches(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "production"))
    }

    @Test("Rule matches without title matcher - app only")
    func matchesAppOnly() {
        let rule = Rule(app: "Safari", space: 2)

        #expect(rule.matches(appName: "Safari", bundleID: "com.apple.Safari", windowTitle: "Any Title"))
        #expect(rule.matches(appName: "Safari", bundleID: "com.apple.Safari", windowTitle: ""))
    }

    @Test("Invalid regex pattern does not match")
    func invalidRegexDoesNotMatch() {
        let rule = Rule(app: "Terminal", titlePattern: "[invalid(regex", space: 3)

        // Invalid regex should not crash, just return false
        #expect(!rule.matches(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "anything"))
    }
}

// MARK: - Rule Validation Tests

@Suite("Rule Validation Tests")
struct RuleValidationTests {

    @Test("Valid rule passes validation")
    func validRulePasses() throws {
        let rule = Rule(app: "Safari", titleContains: "Work", space: 1)
        try rule.validate()
    }

    @Test("Empty app name throws emptyAppName")
    func emptyAppNameThrows() {
        let rule = Rule(app: "", space: 1)

        #expect(throws: RuleValidationError.emptyAppName) {
            try rule.validate()
        }
    }

    @Test("Whitespace-only app name throws emptyAppName")
    func whitespaceAppNameThrows() {
        let rule = Rule(app: "   ", space: 1)

        #expect(throws: RuleValidationError.emptyAppName) {
            try rule.validate()
        }
    }

    @Test("Invalid space number throws invalidSpaceNumber")
    func invalidSpaceNumberThrows() {
        let rule = Rule(app: "Safari", space: 0)

        #expect(throws: RuleValidationError.invalidSpaceNumber(0)) {
            try rule.validate()
        }
    }

    @Test("Negative space number throws invalidSpaceNumber")
    func negativeSpaceNumberThrows() {
        let rule = Rule(app: "Safari", space: -1)

        #expect(throws: RuleValidationError.invalidSpaceNumber(-1)) {
            try rule.validate()
        }
    }

    @Test("Both title matchers throws bothTitleMatchersSpecified")
    func bothTitleMatchersThrows() {
        let rule = Rule(app: "Safari", titleContains: "Work", titlePattern: "^dev-.*", space: 1)

        #expect(throws: RuleValidationError.bothTitleMatchersSpecified) {
            try rule.validate()
        }
    }

    @Test("Invalid regex pattern throws invalidRegexPattern")
    func invalidRegexThrows() {
        let rule = Rule(app: "Safari", titlePattern: "[invalid(regex", space: 1)

        #expect(throws: RuleValidationError.invalidRegexPattern("[invalid(regex")) {
            try rule.validate()
        }
    }
}

// MARK: - Shortcuts Tests

@Suite("Shortcuts Tests")
struct ShortcutsTests {

    @Test("shortcut(forSpace:) returns correct shortcut")
    func shortcutForSpace() {
        let shortcuts = Shortcuts(
            directJumps: [1: "ctrl+1", 2: "ctrl+2", 5: "ctrl+5"],
            spaceLeft: "ctrl+left",
            spaceRight: "ctrl+right"
        )

        #expect(shortcuts.shortcut(forSpace: 1) == "ctrl+1")
        #expect(shortcuts.shortcut(forSpace: 2) == "ctrl+2")
        #expect(shortcuts.shortcut(forSpace: 5) == "ctrl+5")
    }

    @Test("shortcut(forSpace:) returns nil for unconfigured space")
    func shortcutForUnconfiguredSpace() {
        let shortcuts = Shortcuts(directJumps: [1: "ctrl+1"])

        #expect(shortcuts.shortcut(forSpace: 3) == nil)
        #expect(shortcuts.shortcut(forSpace: 9) == nil)
    }

    @Test("Empty shortcuts have no direct jumps")
    func emptyShortcuts() {
        let shortcuts = Shortcuts()

        #expect(shortcuts.directJumps.isEmpty)
        #expect(shortcuts.spaceLeft == nil)
        #expect(shortcuts.spaceRight == nil)
    }
}

// MARK: - Settings Tests

@Suite("Settings Tests")
struct SettingsTests {

    @Test("Default logLevel is info")
    func defaultLogLevel() {
        let settings = Settings()
        #expect(settings.logLevel == "info")
    }

    @Test("Custom logLevel is preserved")
    func customLogLevel() {
        let settings = Settings(logLevel: "debug")
        #expect(settings.logLevel == "debug")
    }
}

// MARK: - OrbitConfig Tests

@Suite("OrbitConfig Tests")
struct OrbitConfigTests {

    @Test("validateRules returns empty for valid rules")
    func validateValidRules() {
        let config = OrbitConfig(
            rules: [
                Rule(app: "Safari", space: 1),
                Rule(app: "Chrome", titleContains: "Work", space: 2)
            ]
        )

        let errors = config.validateRules()
        #expect(errors.isEmpty)
    }

    @Test("validateRules returns errors for invalid rules")
    func validateInvalidRules() {
        let config = OrbitConfig(
            rules: [
                Rule(app: "Safari", space: 1),
                Rule(app: "", space: 2),  // Invalid: empty app
                Rule(app: "Chrome", space: 0)  // Invalid: space < 1
            ]
        )

        let errors = config.validateRules()
        #expect(errors.count == 2)
        #expect(errors[0].index == 1)
        #expect(errors[0].error == .emptyAppName)
        #expect(errors[1].index == 2)
        #expect(errors[1].error == .invalidSpaceNumber(0))
    }

    @Test("Empty config has no rules")
    func emptyConfig() {
        let config = OrbitConfig()

        #expect(config.rules.isEmpty)
        #expect(config.shortcuts.directJumps.isEmpty)
        #expect(config.settings.logLevel == "info")
    }
}

// MARK: - ConfigManager Tests

@Suite("ConfigManager Tests")
struct ConfigManagerTests {

    @Test("Default config path is ~/.config/orbit/config.toml")
    func defaultConfigPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedPath = "\(home)/.config/orbit/config.toml"

        let manager = ConfigManager()
        #expect(manager.configPath == expectedPath)
    }

    @Test("Custom config path is preserved")
    func customConfigPath() {
        let customPath = "/tmp/test-orbit-config.toml"
        let manager = ConfigManager(configPath: customPath)
        #expect(manager.configPath == customPath)
    }

    @Test("Initial config is nil")
    func initialConfigIsNil() {
        let manager = ConfigManager(configPath: "/nonexistent/path.toml")
        #expect(manager.config == nil)
    }

    @Test("Initial isWatching is false")
    func initialIsWatchingIsFalse() {
        let manager = ConfigManager(configPath: "/nonexistent/path.toml")
        #expect(manager.isWatching == false)
    }

    @Test("loadConfig throws fileNotFound for nonexistent file")
    func loadConfigThrowsFileNotFound() {
        let manager = ConfigManager(configPath: "/nonexistent/path/config.toml")

        #expect(throws: ConfigError.fileNotFound(path: "/nonexistent/path/config.toml")) {
            _ = try manager.loadConfig()
        }
    }

    @Test("Delegate is weak reference")
    func delegateIsWeak() {
        let manager = ConfigManager(configPath: "/tmp/test.toml")

        // Create a delegate in a scope that will deallocate it
        autoreleasepool {
            let delegate = MockConfigManagerDelegate()
            manager.delegate = delegate
            #expect(manager.delegate != nil)
        }

        // After autorelease pool drains, weak reference should be nil
        #expect(manager.delegate == nil)
    }

    @Test("stopWatching is idempotent")
    func stopWatchingIdempotent() {
        let manager = ConfigManager(configPath: "/tmp/test.toml")

        // Should not crash when called multiple times
        manager.stopWatching()
        manager.stopWatching()
        manager.stopWatching()

        #expect(manager.isWatching == false)
    }

    @Test("Sample config is valid TOML")
    func sampleConfigIsValidTOML() throws {
        // Write sample config to temp file and try to load it
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test-orbit-\(UUID().uuidString)/config.toml").path

        let manager = ConfigManager(configPath: configPath)
        let created = try manager.createDefaultConfigIfNeeded()
        #expect(created == true)

        // Should be able to load the sample config
        let config = try manager.loadConfig()
        #expect(config.settings.logLevel == "info")
        #expect(config.shortcuts.directJumps[1] == "ctrl+1")

        // Cleanup
        try? FileManager.default.removeItem(atPath: configPath)
    }
}

// MARK: - ConfigError Tests

@Suite("ConfigError Tests")
struct ConfigErrorTests {

    @Test("ConfigError equality")
    func configErrorEquality() {
        let error1 = ConfigError.fileNotFound(path: "/path/a")
        let error2 = ConfigError.fileNotFound(path: "/path/a")
        let error3 = ConfigError.fileNotFound(path: "/path/b")

        #expect(error1 == error2)
        #expect(error1 != error3)

        let parseError1 = ConfigError.parseError(message: "test")
        let parseError2 = ConfigError.parseError(message: "test")
        #expect(parseError1 == parseError2)

        let validationError = ConfigError.validationError(message: "test")
        #expect(parseError1 != validationError)

        let fsError = ConfigError.fileSystemError(message: "test")
        #expect(parseError1 != fsError)
    }
}

// MARK: - TOML Parsing Tests

@Suite("TOML Parsing Tests")
struct TOMLParsingTests {

    @Test("Parse valid config TOML")
    func parseValidConfig() throws {
        let toml = """
        [settings]
        log_level = "debug"

        [shortcuts]
        space_1 = "ctrl+1"
        space_2 = "ctrl+2"
        space_left = "ctrl+left"
        space_right = "ctrl+right"

        [[rules]]
        app = "Google Chrome"
        title_contains = "Work"
        space = 1

        [[rules]]
        app = "Terminal"
        title_pattern = "^dev-.*"
        space = 3
        """

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).toml").path

        try toml.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager(configPath: tempPath)
        let config = try manager.loadConfig()

        #expect(config.settings.logLevel == "debug")
        #expect(config.shortcuts.directJumps[1] == "ctrl+1")
        #expect(config.shortcuts.directJumps[2] == "ctrl+2")
        #expect(config.shortcuts.spaceLeft == "ctrl+left")
        #expect(config.shortcuts.spaceRight == "ctrl+right")
        #expect(config.rules.count == 2)
        #expect(config.rules[0].app == "Google Chrome")
        #expect(config.rules[0].titleContains == "Work")
        #expect(config.rules[0].space == 1)
        #expect(config.rules[1].app == "Terminal")
        #expect(config.rules[1].titlePattern == "^dev-.*")
        #expect(config.rules[1].space == 3)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    @Test("Parse minimal config TOML")
    func parseMinimalConfig() throws {
        // Config with only required fields
        let toml = """
        [settings]

        [shortcuts]

        [[rules]]
        app = "Safari"
        space = 1
        """

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).toml").path

        try toml.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager(configPath: tempPath)
        let config = try manager.loadConfig()

        #expect(config.rules.count == 1)
        #expect(config.rules[0].app == "Safari")
        #expect(config.rules[0].titleContains == nil)
        #expect(config.rules[0].titlePattern == nil)
        #expect(config.rules[0].space == 1)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    @Test("Parse config with validation errors returns validationError")
    func parseConfigWithValidationErrors() throws {
        let toml = """
        [settings]

        [shortcuts]

        [[rules]]
        app = ""
        space = 1
        """

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).toml").path

        try toml.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager(configPath: tempPath)

        do {
            _ = try manager.loadConfig()
            Issue.record("Expected validationError to be thrown")
        } catch let error as ConfigError {
            if case .validationError(let message) = error {
                #expect(message.contains("emptyAppName"))
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    @Test("Invalid TOML throws parseError")
    func invalidTOMLThrowsParseError() throws {
        let toml = """
        this is not valid toml [[[
        """

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).toml").path

        try toml.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let manager = ConfigManager(configPath: tempPath)

        do {
            _ = try manager.loadConfig()
            Issue.record("Expected parseError to be thrown")
        } catch let error as ConfigError {
            if case .parseError = error {
                // Expected
            } else {
                Issue.record("Expected parseError, got \(error)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempPath)
    }
}

// MARK: - Test Helpers

private final class MockConfigManagerDelegate: ConfigManagerDelegate {
    var lastConfig: OrbitConfig?
    var lastError: ConfigError?

    func configManagerDidReloadConfig(_ manager: ConfigManager, config: OrbitConfig) {
        lastConfig = config
    }

    func configManager(_ manager: ConfigManager, didEncounterError error: ConfigError) {
        lastError = error
    }
}
