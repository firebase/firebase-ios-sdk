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


extension GeminiDataModels {
  /// An internal data model for `GenerationConfigModelConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerationConfigModelConfig`
  /// 
  /// Config for model selection.
  package struct GenerationConfigModelConfig: Codable, Sendable, Equatable, Hashable {
    /// Required. Feature selection preference.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. Feature selection preference.
    package let featureSelectionPreference: FeatureSelectionPreference
    

    /// Creates a new `GenerationConfigModelConfig`.
    ///
    /// - Parameters:
    ///   - featureSelectionPreference: Required. Feature selection preference. (Gemini Enterprise Agent Platform only). For more details, see ``featureSelectionPreference``.
    package init(
      featureSelectionPreference: FeatureSelectionPreference
    ) {
      self.featureSelectionPreference = featureSelectionPreference
    }
    enum CodingKeys: String, CodingKey {
      case featureSelectionPreference = "featureSelectionPreference"
    }
  }
}