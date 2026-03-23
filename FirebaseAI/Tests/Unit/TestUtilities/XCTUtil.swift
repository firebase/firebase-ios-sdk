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

import XCTest

/// Asserts that a string contains another string.
///
/// ```swift
/// XCTAssertContains("my name is", "name")
/// ```
///
/// - Parameters:
///   - string: The source string that should contain the other.
///   - contains: The string that should be contained in the source string.
func XCTAssertContains(_ string: String, _ contains: String) {
  if !string.contains(contains) {
    XCTFail("(\"\(string)\") does not contain (\"\(contains)\")")
  }
}

/// Asserts that an async expression throws an error.
///
/// ```swift
/// await XCTAssertThrowsError {
///   try await funcThatThrowsSomeError()
/// } errorHandler: { error in
///   XCTAssert(
///     error is SomeError,
///     "Expected SomeError, but got \(error) instead."
///   )
/// }
/// ```
///
/// - Parameters:
///   - expression: An async expression that can throw an error.
///   - message: An optional custom message to display if the assertion fails.
///   - file: The file where the failure occurs. The default is the filename of the test case.
///   - line: The line number where the failure occurs. The default is the line number in the test.
///   - errorHandler: An optional handler for errors that `expression` throws.
func XCTAssertThrowsError(
  _ expression: () async throws -> Void,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line,
  errorHandler: ((_ error: Error) -> Void)? = nil
) async {
  do {
    try await expression()
    let customMessage = message()
    let failureMessage = customMessage.isEmpty ? "Expected an error to be thrown." : customMessage
    XCTFail(failureMessage, file: file, line: line)
  } catch {
    errorHandler?(error)
  }
}
