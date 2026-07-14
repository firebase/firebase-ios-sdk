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

extension GoogleAI.UrlMetadata {
  /// Status of the url retrieval.
  public enum UrlRetrievalStatus: Codable, Sendable, Equatable, Hashable {
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

extension GoogleAI.UrlMetadata.UrlRetrievalStatus: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .success: "URL_RETRIEVAL_STATUS_SUCCESS"
    case .error: "URL_RETRIEVAL_STATUS_ERROR"
    case .paywall: "URL_RETRIEVAL_STATUS_PAYWALL"
    case .unsafe: "URL_RETRIEVAL_STATUS_UNSAFE"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "URL_RETRIEVAL_STATUS_SUCCESS": self = .success
    case "URL_RETRIEVAL_STATUS_ERROR": self = .error
    case "URL_RETRIEVAL_STATUS_PAYWALL": self = .paywall
    case "URL_RETRIEVAL_STATUS_UNSAFE": self = .unsafe
    default: self = .unrecognized(rawValue)
    }
  }
}