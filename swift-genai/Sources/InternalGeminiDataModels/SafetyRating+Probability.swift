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
  /// Required. The probability of harm for this content.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Required. The probability of harm for this content.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Output only. The probability of harm for this category.
  package enum Probability: Codable, Sendable, Equatable, Hashable {
    /// Content has a negligible chance of being unsafe.
    case negligible
    
    /// Content has a low chance of being unsafe.
    case low
    
    /// Content has a medium chance of being unsafe.
    case medium
    
    /// Content has a high chance of being unsafe.
    case high
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.SafetyRating.Probability: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .negligible: "NEGLIGIBLE"
    case .low: "LOW"
    case .medium: "MEDIUM"
    case .high: "HIGH"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "NEGLIGIBLE": self = .negligible
    case "LOW": self = .low
    case "MEDIUM": self = .medium
    case "HIGH": self = .high
    default: self = .unrecognized(rawValue)
    }
  }
}