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

extension GoogleAI.SafetySetting {
  /// Required. Controls the probability threshold at which harm is blocked.
  public enum Threshold: Codable, Sendable, Equatable, Hashable {
    /// Content with NEGLIGIBLE will be allowed.
    case blockLowAndAbove
    
    /// Content with NEGLIGIBLE and LOW will be allowed.
    case blockMediumAndAbove
    
    /// Content with NEGLIGIBLE, LOW, and MEDIUM will be allowed.
    case blockOnlyHigh
    
    /// All content will be allowed.
    case blockNone
    
    /// Turn off the safety filter.
    case off
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.SafetySetting.Threshold: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .blockLowAndAbove: "BLOCK_LOW_AND_ABOVE"
    case .blockMediumAndAbove: "BLOCK_MEDIUM_AND_ABOVE"
    case .blockOnlyHigh: "BLOCK_ONLY_HIGH"
    case .blockNone: "BLOCK_NONE"
    case .off: "OFF"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "BLOCK_LOW_AND_ABOVE": self = .blockLowAndAbove
    case "BLOCK_MEDIUM_AND_ABOVE": self = .blockMediumAndAbove
    case "BLOCK_ONLY_HIGH": self = .blockOnlyHigh
    case "BLOCK_NONE": self = .blockNone
    case "OFF": self = .off
    default: self = .unrecognized(rawValue)
    }
  }
}