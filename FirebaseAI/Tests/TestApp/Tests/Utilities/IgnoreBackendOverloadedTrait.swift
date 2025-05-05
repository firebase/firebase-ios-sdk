// Copyright 2025 Google LLC
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

import Testing

@testable import FirebaseAI

/// A trait that ignores HTTP 503 - Service Unavailable errors.
///
/// This occurs when the backend is overloaded and cannot handle requests.
struct IgnoreBackendOverloadedTrait: TestTrait, SuiteTrait, TestScoping {
  func provideScope(for test: Test, testCase: Test.Case?,
                    performing function: @Sendable () async throws -> Void) async throws {
    try await withKnownIssue(
      "Backend may fail with a 503 - Service Unavailable error when overloaded",
      isIntermittent: true
    ) {
      try await function()
    } matching: { issue in
      if case let .internalError(error as BackendError) = issue.error as? GenerateContentError,
         error.isServiceUnavailable {
        return true
      } else if let error = issue.error as? BackendError, error.isServiceUnavailable {
        return true
      }

      return false
    }
  }
}

extension Trait where Self == IgnoreBackendOverloadedTrait {
  static var ignoreBackendOverloaded: Self { Self() }
}

extension BackendError {
  /// Returns true when the error is HTTP 503 - Service Unavailable.
  var isServiceUnavailable: Bool {
    httpResponseCode == 503
  }
}
