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

extension URLContextResult {
  /// The status of the URL retrieval.
  package enum Status: Codable, Sendable, Equatable, Hashable {

    /// Url retrieval is successful.
    case success

    /// Url retrieval is failed due to error.
    case error

    /// Url retrieval is failed because the content is behind paywall.
    case paywall

    /// Url retrieval is failed because the content is unsafe.
    case unsafe

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension URLContextResult.Status: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .success: "success"
    case .error: "error"
    case .paywall: "paywall"
    case .unsafe: "unsafe"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "success": self = .success
    case "error": self = .error
    case "paywall": self = .paywall
    case "unsafe": self = .unsafe
    default: self = .unrecognized(rawValue)
    }
  }
}
