import Foundation

/// Errors that can occur during rule validation
public enum RuleValidationError: Error, Equatable {
    case invalidSpaceNumber(Int)
    case invalidRegexPattern(String)
    case emptyAppName
    case bothTitleMatchersSpecified
}

/// A rule that matches windows and assigns them to spaces
public struct Rule: Codable, Equatable, Sendable {
    public let app: String
    public let titleContains: String?
    public let titlePattern: String?
    public let space: Int

    private enum CodingKeys: String, CodingKey {
        case app
        case titleContains = "title_contains"
        case titlePattern = "title_pattern"
        case space
    }

    public init(app: String, titleContains: String? = nil, titlePattern: String? = nil, space: Int) {
        self.app = app
        self.titleContains = titleContains
        self.titlePattern = titlePattern
        self.space = space
    }

    /// Check if rule matches window. App match is case-insensitive (name OR bundleID).
    /// titleContains is case-insensitive substring match.
    /// titlePattern uses Swift Regex.
    public func matches(appName: String, bundleID: String, windowTitle: String) -> Bool {
        // App match is required - case-insensitive match against app name or bundle ID
        let appMatches = app.lowercased() == appName.lowercased() ||
                         app.lowercased() == bundleID.lowercased()

        guard appMatches else {
            return false
        }

        // If no title matchers specified, app match is sufficient
        if titleContains == nil && titlePattern == nil {
            return true
        }

        // Check titleContains (case-insensitive substring match)
        if let contains = titleContains {
            return windowTitle.lowercased().contains(contains.lowercased())
        }

        // Check titlePattern (Swift Regex)
        if let pattern = titlePattern {
            do {
                let regex = try Regex(pattern)
                return windowTitle.contains(regex)
            } catch {
                // Invalid regex pattern - treat as no match
                return false
            }
        }

        return false
    }

    /// Validate the rule configuration
    public func validate() throws {
        // Check for empty app name
        if app.trimmingCharacters(in: .whitespaces).isEmpty {
            throw RuleValidationError.emptyAppName
        }

        // Check for invalid space number
        if space < 1 {
            throw RuleValidationError.invalidSpaceNumber(space)
        }

        // Check that both title matchers aren't specified
        if titleContains != nil && titlePattern != nil {
            throw RuleValidationError.bothTitleMatchersSpecified
        }

        // Validate regex pattern if specified
        if let pattern = titlePattern {
            do {
                _ = try Regex(pattern)
            } catch {
                throw RuleValidationError.invalidRegexPattern(pattern)
            }
        }
    }
}
