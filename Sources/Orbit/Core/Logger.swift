import Foundation
import os.log

/// Centralized logging for Orbit
public enum Logger {
    private static let subsystem = "com.orbit.Orbit"

    private static let general = OSLog(subsystem: subsystem, category: "general")
    private static let movement = OSLog(subsystem: subsystem, category: "movement")
    private static let config = OSLog(subsystem: subsystem, category: "config")
    private static let monitor = OSLog(subsystem: subsystem, category: "monitor")

    public enum Category {
        case general, movement, config, monitor

        var log: OSLog {
            switch self {
            case .general: return Logger.general
            case .movement: return Logger.movement
            case .config: return Logger.config
            case .monitor: return Logger.monitor
            }
        }
    }

    public static func debug(_ message: String, category: Category = .general) {
        os_log(.debug, log: category.log, "%{public}@", message)
    }

    public static func info(_ message: String, category: Category = .general) {
        os_log(.info, log: category.log, "%{public}@", message)
    }

    public static func warning(_ message: String, category: Category = .general) {
        os_log(.default, log: category.log, "WARNING: %{public}@", message)
    }

    public static func error(_ message: String, category: Category = .general) {
        os_log(.error, log: category.log, "ERROR: %{public}@", message)
    }
}
