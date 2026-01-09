// WindowMatcher - Match windows against configuration rules
// Determines target space for windows based on app name, bundle ID, and title

import Foundation

// MARK: - MatchResult

/// Result of matching a window against rules
public struct MatchResult: Equatable, Sendable {
    /// The rule that matched
    public let rule: Rule

    /// The target space number (from the rule)
    public let targetSpace: Int

    /// Index of the matching rule in the rules array
    public let ruleIndex: Int

    public init(rule: Rule, targetSpace: Int, ruleIndex: Int) {
        self.rule = rule
        self.targetSpace = targetSpace
        self.ruleIndex = ruleIndex
    }
}

// MARK: - WindowMatcher

/// Matches windows against configuration rules to determine target space
///
/// Rules are checked in order - the first matching rule wins.
/// This allows for priority-based matching where more specific rules
/// can be placed before general rules.
///
/// Usage:
/// ```swift
/// let rules = [
///     Rule(app: "Chrome", titleContains: "Work", space: 1),
///     Rule(app: "Chrome", titleContains: "Personal", space: 2),
///     Rule(app: "Chrome", space: 3)  // Default for unmatched Chrome windows
/// ]
/// let matcher = WindowMatcher(rules: rules)
///
/// if let result = matcher.match(appName: "Google Chrome", bundleID: "com.google.Chrome", windowTitle: "Work Email") {
///     print("Move to space \(result.targetSpace)")
/// }
/// ```
public final class WindowMatcher: Sendable {

    // MARK: - Properties

    /// The rules to match against (in priority order - first match wins)
    public let rules: [Rule]

    // MARK: - Initialization

    /// Create a new WindowMatcher with the given rules
    /// - Parameter rules: Array of rules in priority order (first match wins)
    public init(rules: [Rule]) {
        self.rules = rules
    }

    // MARK: - Public Methods

    /// Match a window against the rules
    /// - Parameters:
    ///   - appName: Application display name
    ///   - bundleID: Application bundle identifier
    ///   - windowTitle: Window title
    /// - Returns: MatchResult if a rule matches, nil otherwise
    public func match(appName: String, bundleID: String, windowTitle: String) -> MatchResult? {
        for (index, rule) in rules.enumerated() {
            if rule.matches(appName: appName, bundleID: bundleID, windowTitle: windowTitle) {
                return MatchResult(
                    rule: rule,
                    targetSpace: rule.space,
                    ruleIndex: index
                )
            }
        }
        return nil
    }

    /// Match a WindowInfo against the rules
    /// - Parameter windowInfo: The window information
    /// - Returns: MatchResult if a rule matches, nil otherwise
    public func match(windowInfo: WindowInfo) -> MatchResult? {
        return match(
            appName: windowInfo.appName,
            bundleID: windowInfo.bundleID,
            windowTitle: windowInfo.title
        )
    }

    /// Find all rules that would match a window (for debugging/UI)
    /// - Parameters:
    ///   - appName: Application display name
    ///   - bundleID: Application bundle identifier
    ///   - windowTitle: Window title
    /// - Returns: Array of (ruleIndex, rule) pairs that match
    public func findAllMatches(appName: String, bundleID: String, windowTitle: String) -> [(index: Int, rule: Rule)] {
        var matches: [(index: Int, rule: Rule)] = []

        for (index, rule) in rules.enumerated() {
            if rule.matches(appName: appName, bundleID: bundleID, windowTitle: windowTitle) {
                matches.append((index: index, rule: rule))
            }
        }

        return matches
    }
}
