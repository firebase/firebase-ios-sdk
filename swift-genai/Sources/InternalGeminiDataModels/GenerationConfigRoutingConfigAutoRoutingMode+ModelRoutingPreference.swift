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

extension GeminiDataModels.GenerationConfigRoutingConfigAutoRoutingMode {
  /// The model routing preference.
  /// 
  /// > Important: `modelRoutingPreference` is only available in the Gemini Enterprise Agent Platform.
  package enum ModelRoutingPreference: Codable, Sendable, Equatable, Hashable {
    /// The model will be selected to prioritize the quality of the response.
    case prioritizeQuality
    
    /// The model will be selected to balance quality and cost.
    case balanced
    
    /// The model will be selected to prioritize the cost of the request.
    case prioritizeCost
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.GenerationConfigRoutingConfigAutoRoutingMode.ModelRoutingPreference: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .prioritizeQuality: "PRIORITIZE_QUALITY"
    case .balanced: "BALANCED"
    case .prioritizeCost: "PRIORITIZE_COST"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "PRIORITIZE_QUALITY": self = .prioritizeQuality
    case "BALANCED": self = .balanced
    case "PRIORITIZE_COST": self = .prioritizeCost
    default: self = .unrecognized(rawValue)
    }
  }
}