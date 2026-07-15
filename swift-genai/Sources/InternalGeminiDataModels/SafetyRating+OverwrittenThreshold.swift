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

extension GeminiDataModels.SafetyRating {
  /// Output only. The overwritten threshold for the safety category of
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This property is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Output only. The overwritten threshold for the safety category of
  /// Gemini 2.0 image out. If minors are detected in the output image, the
  /// threshold of each safety category will be overwritten if user sets a lower
  /// threshold.
  package enum OverwrittenThreshold: Codable, Sendable, Equatable, Hashable {
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

extension GeminiDataModels.SafetyRating.OverwrittenThreshold: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .blockLowAndAbove: "BLOCK_LOW_AND_ABOVE"
    case .blockMediumAndAbove: "BLOCK_MEDIUM_AND_ABOVE"
    case .blockOnlyHigh: "BLOCK_ONLY_HIGH"
    case .blockNone: "BLOCK_NONE"
    case .off: "OFF"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
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