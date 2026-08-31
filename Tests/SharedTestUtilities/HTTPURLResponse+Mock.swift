// Copyright 2026 Google LLC
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

package import Foundation
import Testing

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) extension HTTPURLResponse
{
  /// Creates a mock `HTTPURLResponse` for testing.
  ///
  /// - Parameters:
  ///   - url: The target response URL.
  ///   - statusCode: The HTTP status code. Defaults to `200`.
  ///   - headerFields: The optional HTTP header dictionary.
  /// - Returns: A non-nil `HTTPURLResponse`.
  /// - Throws: An error if response construction fails.
  package static func mock(
    url: URL,
    statusCode: Int = 200,
    headerFields: [String: String]? = nil
  ) throws -> HTTPURLResponse {
    try #require(
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headerFields
      )
    )
  }
}
