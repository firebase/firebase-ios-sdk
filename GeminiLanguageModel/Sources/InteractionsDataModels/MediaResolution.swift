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

/// An internal data model for `MediaResolution`.
package enum MediaResolution: Codable, Sendable, Equatable, Hashable {

  /// Low resolution.
  case low

  /// Medium resolution.
  case medium

  /// High resolution.
  case high

  /// Ultra high resolution.
  case ultraHigh

  /// Unrecognized case.
  ///
  /// - Parameter value: The raw string value of the unrecognized enum case.
  case unrecognized(_ value: String)
}

// MARK: - RawRepresentable Conformance

extension MediaResolution: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .low: "low"
    case .medium: "medium"
    case .high: "high"
    case .ultraHigh: "ultra_high"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "low": self = .low
    case "medium": self = .medium
    case "high": self = .high
    case "ultra_high": self = .ultraHigh
    default: self = .unrecognized(rawValue)
    }
  }
}
