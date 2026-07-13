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

extension AgentPlatform.GenerationConfigThinkingConfig {
  /// Optional. The number of thoughts tokens that the model should generate.
  package enum ThinkingLevel: Codable, Sendable, Equatable, Hashable {
    /// Low thinking level.
    case low
    
    /// Medium thinking level.
    case medium
    
    /// High thinking level.
    case high
    
    /// MINIMAL thinking level.
    case minimal
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.GenerationConfigThinkingConfig.ThinkingLevel: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .low: "LOW"
    case .medium: "MEDIUM"
    case .high: "HIGH"
    case .minimal: "MINIMAL"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "LOW": self = .low
    case "MEDIUM": self = .medium
    case "HIGH": self = .high
    case "MINIMAL": self = .minimal
    default: self = .unrecognized(rawValue)
    }
  }
}