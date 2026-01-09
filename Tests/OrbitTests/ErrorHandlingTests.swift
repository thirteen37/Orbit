import XCTest
@testable import Orbit

final class ErrorHandlingTests: XCTestCase {

    func testRetryHandler_successOnFirstAttempt() throws {
        let handler = RetryHandler(maxAttempts: 3)
        var attempts = 0

        let result = try handler.execute {
            attempts += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 1)
    }

    func testRetryHandler_successOnSecondAttempt() throws {
        let handler = RetryHandler(maxAttempts: 3, delayBetweenAttempts: 0.01)
        var attempts = 0

        let result = try handler.execute {
            attempts += 1
            if attempts < 2 {
                throw NSError(domain: "test", code: 1)
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 2)
    }

    func testRetryHandler_failsAfterMaxAttempts() {
        let handler = RetryHandler(maxAttempts: 2, delayBetweenAttempts: 0.01)
        var attempts = 0

        XCTAssertThrowsError(try handler.execute {
            attempts += 1
            throw NSError(domain: "test", code: 1)
        })

        XCTAssertEqual(attempts, 2)
    }

    func testRetryHandler_respectsMaxAttempts() throws {
        let handler = RetryHandler(maxAttempts: 5, delayBetweenAttempts: 0.01)
        var attempts = 0

        let result = try handler.execute {
            attempts += 1
            if attempts < 4 {
                throw NSError(domain: "test", code: 1)
            }
            return "success after \(attempts) attempts"
        }

        XCTAssertEqual(result, "success after 4 attempts")
        XCTAssertEqual(attempts, 4)
    }

    func testRetryHandler_defaultValues() {
        let handler = RetryHandler()
        XCTAssertEqual(handler.maxAttempts, 2)
        XCTAssertEqual(handler.delayBetweenAttempts, 0.5)
    }

    func testRetryHandler_asyncSuccessOnFirstAttempt() async throws {
        let handler = RetryHandler(maxAttempts: 3)
        var attempts = 0

        let result = try await handler.executeAsync {
            attempts += 1
            return "async success"
        }

        XCTAssertEqual(result, "async success")
        XCTAssertEqual(attempts, 1)
    }

    func testRetryHandler_asyncSuccessOnSecondAttempt() async throws {
        let handler = RetryHandler(maxAttempts: 3, delayBetweenAttempts: 0.01)
        var attempts = 0

        let result = try await handler.executeAsync {
            attempts += 1
            if attempts < 2 {
                throw NSError(domain: "test", code: 1)
            }
            return "async success"
        }

        XCTAssertEqual(result, "async success")
        XCTAssertEqual(attempts, 2)
    }

    func testRetryHandler_asyncFailsAfterMaxAttempts() async {
        let handler = RetryHandler(maxAttempts: 2, delayBetweenAttempts: 0.01)
        var attempts = 0

        do {
            _ = try await handler.executeAsync {
                attempts += 1
                throw NSError(domain: "test", code: 1)
            } as Void
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(attempts, 2)
        }
    }

    func testLoggerCategory_hasCorrectLog() {
        // Just verify categories exist and don't crash
        Logger.debug("test debug", category: .general)
        Logger.info("test info", category: .movement)
        Logger.warning("test warning", category: .config)
        Logger.error("test error", category: .monitor)
    }

    func testLoggerCategory_defaultCategory() {
        // Test that default category works
        Logger.debug("test debug with default category")
        Logger.info("test info with default category")
        Logger.warning("test warning with default category")
        Logger.error("test error with default category")
    }
}
