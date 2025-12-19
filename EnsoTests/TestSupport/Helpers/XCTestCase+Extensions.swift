//
//  XCTestCase+Extensions.swift
//  EnsoTests
//

import Foundation
import XCTest
import SwiftData
@testable import Enso

// MARK: - SwiftData Helpers

extension XCTestCase {
    /// Create an in-memory SwiftData test container
    @MainActor
    func makeTestContainer() throws -> SwiftDataTestContainer {
        try SwiftDataTestContainer()
    }
}

// MARK: - Async Testing Helpers

extension XCTestCase {
    /// Execute an async test with proper error handling
    func runAsyncTest(
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test completion")

        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed with error: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Execute an async test on MainActor
    @MainActor
    func runMainActorTest(
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @MainActor @escaping () async throws -> Void
    ) async {
        do {
            try await block()
        } catch {
            XCTFail("MainActor test failed with error: \(error)", file: file, line: line)
        }
    }
}

// MARK: - Wait Helpers

extension XCTestCase {
    /// Wait for a condition to become true
    @MainActor
    func waitFor(
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line,
        condition: @escaping () -> Bool
    ) async {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Timeout waiting for condition", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    /// Wait for an async operation with timeout
    func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }

            guard let result = try await group.next() else {
                throw TestError.timeout
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - Assertion Helpers

extension XCTestCase {
    /// Assert that an async operation throws a specific error type
    func assertThrowsError<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected error of type \(E.self) but got \(type(of: error)): \(error)", file: file, line: line)
        }
    }

    /// Assert that an async operation throws any error
    func assertThrows<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but no error was thrown", file: file, line: line)
        } catch {
            // Expected error was thrown
        }
    }

    /// Assert that an async operation does not throw
    func assertNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
            return nil
        }
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
    case timeout
    case unexpectedResult
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .unexpectedResult:
            return "Unexpected result from operation"
        case .setupFailed(let reason):
            return "Test setup failed: \(reason)"
        }
    }
}

// MARK: - Mock UserDefaults

/// In-memory UserDefaults for testing
final class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    override func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    override func integer(forKey defaultName: String) -> Int {
        storage[defaultName] as? Int ?? 0
    }

    override func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    override func double(forKey defaultName: String) -> Double {
        storage[defaultName] as? Double ?? 0.0
    }

    override func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    override func array(forKey defaultName: String) -> [Any]? {
        storage[defaultName] as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        storage[defaultName] as? [String: Any]
    }

    /// Reset all stored values
    func reset() {
        storage.removeAll()
    }
}
