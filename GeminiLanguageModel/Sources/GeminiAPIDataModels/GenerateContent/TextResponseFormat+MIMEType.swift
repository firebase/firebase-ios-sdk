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

extension TextResponseFormat {
  /// The IANA standard MIME type of the response.
  package enum MIMEType: Codable, Sendable, Equatable, Hashable {
    /// JSON output format.
    case applicationJSON

    /// Plain text output format.
    case textPlain

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension TextResponseFormat.MIMEType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .applicationJSON: "APPLICATION_JSON"
    case .textPlain: "TEXT_PLAIN"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "APPLICATION_JSON": self = .applicationJSON
    case "TEXT_PLAIN": self = .textPlain
    default: self = .unrecognized(rawValue)
    }
  }
}
