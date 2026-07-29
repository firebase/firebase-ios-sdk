// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
import XCTest

enum IntegrationTestUtils {
  /// Skips an XCTest unless the specified environment variable is set.
  ///
  /// - Parameters:
  ///   - environmentVariable: The environment variable that must be defined for the test to
  ///     continue (i.e., not get skipped).
  ///   - requiredValue: If specified, skips the test if `environmentVariable` is not set to the
  ///     this value; if `nil`, any value allows the test to continue.
  /// - Throws: `XCTSkip` if the test should be skipped.
  static func skipUnless(environmentVariable: String, requiredValue: String? = nil) throws {
    guard let variableValue = ProcessInfo.processInfo.environment[environmentVariable] else {
      throw XCTSkip("Skipped because environment variable '\(environmentVariable)' is not defined.")
    }

    if let requiredValue, variableValue != requiredValue {
      throw XCTSkip("""
      Skipped because environment variable '\(environmentVariable)' != '\(requiredValue)'; value \
      is '\(variableValue)'.
      """)
    }
  }
}

extension Numeric where Self: Strideable, Self.Stride.Magnitude: Comparable {
  func isEqual(to other: Self, accuracy: Self.Stride) -> Bool {
    return distance(to: other).magnitude <= accuracy.magnitude
  }
}

/// Retry a flakey test N times before failing.
///
/// - Parameters:
///   - times: The amount of attempts to retry before failing. Must be greater than 0.
///   - delayInSeconds: How long to wait before performing the next attempt.
@discardableResult
func retry<T>(times: Int,
              delayInSeconds: TimeInterval = 0.1,
              _ test: () async throws -> T) async throws -> T {
  if times <= 0 {
    precondition(times <= 0, "Times must be greater than 0.")
  }
  let delayNanos = UInt64(delayInSeconds * 1e+9)
  var lastError: Error?
  for attempt in 1 ... times {
    do { return try await test() }
    catch {
      lastError = error
      // only wait if we have more attempts
      if attempt < times {
        try? await Task.sleep(nanoseconds: delayNanos)
      }
    }
  }
  guard let lastError else {
    // should not happen unless we change the above code in some way
    fatalError("Internal error: retry loop finished without error")
  }
  Issue.record("Flaky test failed after \(times) attempt(s): \(String(describing: lastError))")
  throw lastError
}

enum TimeoutResult<T: Sendable>: Sendable {
  case completed(T)
  case timedOut
}

/// The amount of nano seconds in a second.
let nanosecondsPerSecond: Double = 1_000_000_000

/// Run a callback, returning nil if it takes longer than the specified amount of seconds.
///
/// - Warning: The callback passed to this function **must** be cancellation-aware, otherwise,
///   you won't get proper timeout support.
///
/// - Parameters:
///   - seconds: The amount of seconds to wait before cancelling the callback and considering it a
///     timeout. Must be **positive**, and at **max one hour**.
///   - operation: The callback to execute. **Must** be cancellation-aware.
func withTimeout<T: Sendable>(seconds: TimeInterval,
                              operation: @escaping @Sendable () async throws -> T) async throws
  -> T? {
  guard seconds > 0 else {
    fatalError("seconds must be a postive number, but we got \(seconds) instead")
  }
  // constrain to one hour, just in case someone accidentally passed too large of a value
  guard seconds <= 3600 else {
    fatalError("the maximum amount of seconds you can pass is 1 hour, but you passed \(seconds)")
  }

  let nanoseconds = UInt64(seconds * nanosecondsPerSecond)

  return try await withThrowingTaskGroup(of: TimeoutResult<T>.self) { group in
    group.addTask {
      let result = try await operation()
      return .completed(result)
    }

    group.addTask {
      try await Task.sleep(nanoseconds: nanoseconds)
      return .timedOut
    }

    defer { group.cancelAll() }

    while let result = try await group.next() {
      switch result {
      case let .completed(value):
        return value
      case .timedOut:
        return nil
      }
    }

    return nil
  }
}
