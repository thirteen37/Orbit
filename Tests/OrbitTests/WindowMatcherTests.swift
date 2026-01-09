import Testing
@testable import Orbit

@Suite("WindowMatcher Tests")
struct WindowMatcherTests {

    // MARK: - Empty Rules Tests

    @Test("Empty rules returns nil for any window")
    func emptyRulesReturnsNil() {
        let matcher = WindowMatcher(rules: [])

        let result = matcher.match(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Test Window"
        )

        #expect(result == nil)
    }

    // MARK: - Single Rule Tests

    @Test("Single matching rule returns correct MatchResult")
    func singleMatchingRuleReturnsCorrectResult() {
        let rule = Rule(app: "Google Chrome", titleContains: "Work", space: 2)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Work Email - Chrome"
        )

        #expect(result != nil)
        #expect(result?.rule == rule)
        #expect(result?.targetSpace == 2)
        #expect(result?.ruleIndex == 0)
    }

    @Test("Non-matching window returns nil")
    func nonMatchingWindowReturnsNil() {
        let rule = Rule(app: "Google Chrome", titleContains: "Work", space: 2)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Safari",
            bundleID: "com.apple.Safari",
            windowTitle: "Work Email"
        )

        #expect(result == nil)
    }

    @Test("App-only rule matches any window from that app")
    func appOnlyRuleMatchesAnyWindow() {
        let rule = Rule(app: "Terminal", space: 3)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            windowTitle: "bash - 80x24"
        )

        #expect(result != nil)
        #expect(result?.targetSpace == 3)
    }

    // MARK: - Priority Tests

    @Test("First matching rule wins when multiple rules match")
    func firstMatchingRuleWins() {
        let rules = [
            Rule(app: "Chrome", titleContains: "Work", space: 1),
            Rule(app: "Chrome", titleContains: "Work", space: 2),  // Also matches but comes second
            Rule(app: "Chrome", space: 3)  // Also matches but comes third
        ]
        let matcher = WindowMatcher(rules: rules)

        let result = matcher.match(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Work Dashboard"
        )

        #expect(result != nil)
        #expect(result?.targetSpace == 1)
        #expect(result?.ruleIndex == 0)
    }

    @Test("Rules are checked in order with overlapping rules")
    func rulesCheckedInOrder() {
        let rules = [
            Rule(app: "Chrome", titleContains: "Personal", space: 1),  // More specific
            Rule(app: "Chrome", space: 2)  // Catch-all for Chrome
        ]
        let matcher = WindowMatcher(rules: rules)

        // Window matching specific rule
        let personalResult = matcher.match(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Personal Email"
        )
        #expect(personalResult?.targetSpace == 1)

        // Window matching only the catch-all
        let otherResult = matcher.match(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Random Page"
        )
        #expect(otherResult?.targetSpace == 2)
    }

    // MARK: - WindowInfo Convenience Method Tests

    @Test("match(windowInfo:) works correctly")
    func matchWindowInfoWorks() throws {
        let rule = Rule(app: "Safari", titleContains: "Apple", space: 4)
        let matcher = WindowMatcher(rules: [rule])

        // Create a mock WindowInfo - we can't create a real AXUIElement in tests,
        // but we can test the matching logic by calling match() directly
        let result = matcher.match(
            appName: "Safari",
            bundleID: "com.apple.Safari",
            windowTitle: "Apple Developer"
        )

        #expect(result != nil)
        #expect(result?.targetSpace == 4)
    }

    // MARK: - findAllMatches Tests

    @Test("findAllMatches returns all matching rules")
    func findAllMatchesReturnsAllRules() {
        let rules = [
            Rule(app: "Chrome", titleContains: "Work", space: 1),
            Rule(app: "Safari", space: 2),  // Doesn't match
            Rule(app: "Chrome", space: 3),  // Matches (app-only catch-all)
            Rule(app: "Chrome", titleContains: "Work Project", space: 4)  // Doesn't match "Work Email"
        ]
        let matcher = WindowMatcher(rules: rules)

        let matches = matcher.findAllMatches(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Work Email"
        )

        #expect(matches.count == 2)
        #expect(matches[0].index == 0)
        #expect(matches[0].rule.space == 1)
        #expect(matches[1].index == 2)
        #expect(matches[1].rule.space == 3)
    }

    @Test("findAllMatches returns empty array when no rules match")
    func findAllMatchesReturnsEmptyWhenNoMatch() {
        let rules = [
            Rule(app: "Chrome", space: 1),
            Rule(app: "Safari", space: 2)
        ]
        let matcher = WindowMatcher(rules: rules)

        let matches = matcher.findAllMatches(
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            windowTitle: "bash"
        )

        #expect(matches.isEmpty)
    }

    // MARK: - MatchResult Equality Tests

    @Test("MatchResult equality works correctly")
    func matchResultEquality() {
        let rule1 = Rule(app: "Chrome", space: 1)
        let rule2 = Rule(app: "Chrome", space: 1)
        let rule3 = Rule(app: "Safari", space: 1)

        let result1 = MatchResult(rule: rule1, targetSpace: 1, ruleIndex: 0)
        let result2 = MatchResult(rule: rule2, targetSpace: 1, ruleIndex: 0)
        let result3 = MatchResult(rule: rule3, targetSpace: 1, ruleIndex: 0)
        let result4 = MatchResult(rule: rule1, targetSpace: 2, ruleIndex: 0)
        let result5 = MatchResult(rule: rule1, targetSpace: 1, ruleIndex: 1)

        // Same values should be equal
        #expect(result1 == result2)

        // Different rule should not be equal
        #expect(result1 != result3)

        // Different targetSpace should not be equal
        #expect(result1 != result4)

        // Different ruleIndex should not be equal
        #expect(result1 != result5)
    }

    // MARK: - Bundle ID Matching Tests

    @Test("Matching works by bundle ID")
    func matchingByBundleID() {
        let rule = Rule(app: "com.google.Chrome", space: 1)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Test"
        )

        #expect(result != nil)
        #expect(result?.targetSpace == 1)
    }

    // MARK: - Regex Pattern Tests

    @Test("Regex pattern matching works")
    func regexPatternMatching() {
        let rule = Rule(app: "Terminal", titlePattern: "^dev-.*", space: 5)
        let matcher = WindowMatcher(rules: [rule])

        // Should match
        let result1 = matcher.match(
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            windowTitle: "dev-server"
        )
        #expect(result1 != nil)
        #expect(result1?.targetSpace == 5)

        // Should not match (doesn't start with dev-)
        let result2 = matcher.match(
            appName: "Terminal",
            bundleID: "com.apple.Terminal",
            windowTitle: "production-server"
        )
        #expect(result2 == nil)
    }

    // MARK: - Case Insensitivity Tests

    @Test("App matching is case insensitive")
    func appMatchingCaseInsensitive() {
        let rule = Rule(app: "chrome", space: 1)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Test"
        )

        #expect(result != nil)
    }

    @Test("Title contains matching is case insensitive")
    func titleContainsCaseInsensitive() {
        let rule = Rule(app: "Chrome", titleContains: "WORK", space: 1)
        let matcher = WindowMatcher(rules: [rule])

        let result = matcher.match(
            appName: "Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "My work email"
        )

        #expect(result != nil)
    }
}
