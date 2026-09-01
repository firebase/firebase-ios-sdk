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

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Errors thrown by `GeminiAPIClient`.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package enum GeminiAPIError: Error, Sendable, Equatable {
  /// An API error returned by the Google Gemini service conforming to AIP-0193.
  case apiError(GoogleCloudAPIError)

  /// An HTTP failure status code with a raw response body.
  case httpError(statusCode: Int, body: String)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension GeminiAPIError {
  /// The retry delay advice for this error, if available from headers or payload details.
  package var retryAfter: Duration? {
    switch self {
    case .apiError(let error):
      error.retryDelay
    case .httpError:
      nil
    }
  }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension GeminiAPIError: LocalizedError {
  package static var errorDomain: String { "GeminiAPIClient.GeminiAPIError" }

  package var errorDescription: String? {
    switch self {
    case .apiError(let error):
      error.errorDescription
    case .httpError(let statusCode, let body):
      "HTTP \(statusCode): \(body)"
    }
  }

  package var failureReason: String? {
    switch self {
    case .apiError(let error):
      error.failureReason
    case .httpError(let statusCode, _):
      "HTTP status \(statusCode)"
    }
  }

  package var helpAnchor: String? {
    switch self {
    case .apiError(let error):
      error.helpAnchor
    case .httpError:
      nil
    }
  }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension GeminiAPIError: CustomNSError {
  package var errorCode: Int {
    switch self {
    case .apiError(let error):
      error.errorCode
    case .httpError(let statusCode, _):
      statusCode
    }
  }

  package var errorUserInfo: [String: Any] {
    switch self {
    case .apiError(let error):
      error.errorUserInfo
    case .httpError(let statusCode, let body):
      [
        "statusCode": statusCode,
        "body": body,
      ]
    }
  }
}
