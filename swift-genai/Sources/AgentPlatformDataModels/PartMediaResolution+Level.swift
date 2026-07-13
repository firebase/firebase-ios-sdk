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

extension AgentPlatform.PartMediaResolution {
  /// The tokenization quality used for given media.
  package enum Level: Codable, Sendable, Equatable, Hashable {
    /// Media resolution set to low.
    case low
    
    /// Media resolution set to medium.
    case medium
    
    /// Media resolution set to high.
    case high
    
    /// Media resolution set to ultra high. This is for image only.
    case ultraHigh
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.PartMediaResolution.Level: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .low: "MEDIA_RESOLUTION_LOW"
    case .medium: "MEDIA_RESOLUTION_MEDIUM"
    case .high: "MEDIA_RESOLUTION_HIGH"
    case .ultraHigh: "MEDIA_RESOLUTION_ULTRA_HIGH"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "MEDIA_RESOLUTION_LOW": self = .low
    case "MEDIA_RESOLUTION_MEDIUM": self = .medium
    case "MEDIA_RESOLUTION_HIGH": self = .high
    case "MEDIA_RESOLUTION_ULTRA_HIGH": self = .ultraHigh
    default: self = .unrecognized(rawValue)
    }
  }
}