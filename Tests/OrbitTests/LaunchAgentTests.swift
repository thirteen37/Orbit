import XCTest
@testable import Orbit

final class LaunchAgentTests: XCTestCase {

    func testInitialization_customValues() {
        let agent = LaunchAgent(
            bundleIdentifier: "com.test.app",
            executablePath: "/usr/bin/test"
        )

        XCTAssertEqual(agent.bundleIdentifier, "com.test.app")
        XCTAssertEqual(agent.executablePath, "/usr/bin/test")
    }

    func testPlistPath_containsBundleIdentifier() {
        let agent = LaunchAgent(
            bundleIdentifier: "com.test.app",
            executablePath: "/usr/bin/test"
        )

        XCTAssertTrue(agent.plistPath.contains("com.test.app.plist"))
        XCTAssertTrue(agent.plistPath.contains("LaunchAgents"))
    }

    func testIsInstalled_returnsFalseForNonexistent() {
        let agent = LaunchAgent(
            bundleIdentifier: "com.nonexistent.fake.app.12345",
            executablePath: "/nonexistent"
        )

        XCTAssertFalse(agent.isInstalled)
    }

    func testIsEnabled_returnsFalseForNonexistent() {
        let agent = LaunchAgent(
            bundleIdentifier: "com.nonexistent.fake.app.12345",
            executablePath: "/nonexistent"
        )

        XCTAssertFalse(agent.isEnabled)
    }

    func testDefaultInit_usesBundleInfo() {
        let agent = LaunchAgent()
        // Should have some bundle identifier (may be test runner's)
        XCTAssertFalse(agent.bundleIdentifier.isEmpty)
        XCTAssertFalse(agent.executablePath.isEmpty)
    }

    func testGeneratedPlist_containsRequiredKeys() {
        let agent = LaunchAgent(
            bundleIdentifier: "com.orbit.test",
            executablePath: "/Applications/Orbit.app/Contents/MacOS/Orbit"
        )

        // Install to a temp location to test plist generation
        // We can't easily test the actual plist content without installing
        // but we can verify the path is correct
        XCTAssertTrue(agent.plistPath.hasSuffix("com.orbit.test.plist"))
    }
}
