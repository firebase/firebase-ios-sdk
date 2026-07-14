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

extension GeminiDataModels.GenerationConfigModelConfig {
  /// Required. Feature selection preference.
  /// 
  /// > Important: `featureSelectionPreference` is only available in the Gemini Enterprise Agent Platform.
  package enum FeatureSelectionPreference: Codable, Sendable, Equatable, Hashable {
    /// Prefer higher quality over lower cost.
    case prioritizeQuality
    
    /// Balanced feature selection preference.
    case balanced
    
    /// Prefer lower cost over higher quality.
    case prioritizeCost
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.GenerationConfigModelConfig.FeatureSelectionPreference: RawRepresentable {
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