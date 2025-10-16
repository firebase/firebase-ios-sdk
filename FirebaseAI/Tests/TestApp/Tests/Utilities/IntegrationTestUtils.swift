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
internal func retry<T>(
  times: Int,
  delayInSeconds: TimeInterval = 0.1,
  _ test: () async throws -> T
) async throws -> T {
  if times <= 0 {
    fatalError("Times must be greater than 0.")
  }
  var delayNanos = UInt64(delayInSeconds * 1e+9)
  var lastError: Error?
  for attempt in 1...times {
    do { return try await test() }
    catch {
      lastError = error
      // only wait if we have more attempts
      if attempt < times {
        try? await Task.sleep(nanoseconds: delayNanos)
      }
    }
  }
  Issue.record("Flaky test failed after \(times) attempt(s): \(String(describing: lastError))")
  throw lastError!
}
