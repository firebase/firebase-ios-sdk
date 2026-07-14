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

extension GoogleAI.TextResponseFormat {
  /// Optional. The MIME type of the text output.
  public enum MimeType: Codable, Sendable, Equatable, Hashable {
    /// JSON output format.
    case applicationJson
    
    /// Plain text output format.
    case textPlain
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.TextResponseFormat.MimeType: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .applicationJson: "APPLICATION_JSON"
    case .textPlain: "TEXT_PLAIN"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "APPLICATION_JSON": self = .applicationJson
    case "TEXT_PLAIN": self = .textPlain
    default: self = .unrecognized(rawValue)
    }
  }
}