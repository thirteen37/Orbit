import Foundation

/// Handles retry logic for operations that may fail transiently
public struct RetryHandler {
    public let maxAttempts: Int
    public let delayBetweenAttempts: TimeInterval

    public init(maxAttempts: Int = 2, delayBetweenAttempts: TimeInterval = 0.5) {
        self.maxAttempts = maxAttempts
        self.delayBetweenAttempts = delayBetweenAttempts
    }

    /// Execute an operation with retry
    @discardableResult
    public func execute<T>(_ operation: () throws -> T) throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try operation()
            } catch {
                lastError = error
                Logger.warning(
                    "Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)",
                    category: .general
                )

                if attempt < maxAttempts {
                    Thread.sleep(forTimeInterval: delayBetweenAttempts)
                }
            }
        }

        throw lastError!
    }

    /// Execute an async operation with retry
    @discardableResult
    public func executeAsync<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                Logger.warning(
                    "Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)",
                    category: .general
                )

                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delayBetweenAttempts * 1_000_000_000))
                }
            }
        }

        throw lastError!
    }
}
