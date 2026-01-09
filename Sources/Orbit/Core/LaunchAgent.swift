import Foundation

/// Manages the LaunchAgent for auto-start at login
public final class LaunchAgent: Sendable {

    /// The bundle identifier for the plist
    public let bundleIdentifier: String

    /// The executable path
    public let executablePath: String

    /// LaunchAgents directory path
    private var launchAgentsDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents"
    }

    /// Plist file path
    public var plistPath: String {
        "\(launchAgentsDirectory)/\(bundleIdentifier).plist"
    }

    /// Initialize with bundle identifier and executable path
    public init(bundleIdentifier: String, executablePath: String) {
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
    }

    /// Initialize with current app's info
    public convenience init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.orbit.Orbit"
        let execPath = Bundle.main.executablePath ?? "/usr/local/bin/Orbit"
        self.init(bundleIdentifier: bundleID, executablePath: execPath)
    }

    /// Check if launch agent is installed
    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    /// Check if launch agent is enabled (loaded)
    public var isEnabled: Bool {
        // Check if the job is loaded via launchctl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", bundleIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Install the launch agent plist
    @discardableResult
    public func install() throws -> Bool {
        // Create LaunchAgents directory if needed
        try FileManager.default.createDirectory(
            atPath: launchAgentsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Generate plist content
        let plist = generatePlist()

        // Write plist file
        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)

        return true
    }

    /// Uninstall the launch agent plist
    @discardableResult
    public func uninstall() throws -> Bool {
        guard isInstalled else { return true }

        // Unload first if loaded
        if isEnabled {
            try disable()
        }

        // Remove plist file
        try FileManager.default.removeItem(atPath: plistPath)

        return true
    }

    /// Enable (load) the launch agent
    @discardableResult
    public func enable() throws -> Bool {
        if !isInstalled {
            try install()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath]

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    /// Disable (unload) the launch agent
    @discardableResult
    public func disable() throws -> Bool {
        guard isEnabled else { return true }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    /// Toggle the launch agent enabled state
    @discardableResult
    public func toggle() throws -> Bool {
        if isEnabled {
            try disable()
            return false
        } else {
            try enable()
            return true
        }
    }

    /// Generate the plist XML content
    private func generatePlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
    }
}
