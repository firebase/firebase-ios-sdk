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

extension SafetySetting {
  /// Required. The threshold for blocking content. If the harm probability
  /// exceeds this threshold, the content will be blocked.
  package enum Threshold: Codable, Sendable, Equatable, Hashable {

    /// Block content with a low harm probability or higher.
    case blockLowAndAbove

    /// Block content with a medium harm probability or higher.
    case blockMediumAndAbove

    /// Block content with a high harm probability.
    case blockOnlyHigh

    /// Do not block any content, regardless of its harm probability.
    case blockNone

    /// Turn off the safety filter entirely.
    case off

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension SafetySetting.Threshold: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .blockLowAndAbove: "block_low_and_above"
    case .blockMediumAndAbove: "block_medium_and_above"
    case .blockOnlyHigh: "block_only_high"
    case .blockNone: "block_none"
    case .off: "off"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "block_low_and_above": self = .blockLowAndAbove
    case "block_medium_and_above": self = .blockMediumAndAbove
    case "block_only_high": self = .blockOnlyHigh
    case "block_none": self = .blockNone
    case "off": self = .off
    default: self = .unrecognized(rawValue)
    }
  }
}
