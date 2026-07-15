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
  /// An internal data model for `GenerationConfigRoutingConfigAutoRoutingMode`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerationConfigRoutingConfigAutoRoutingMode`
  /// 
  /// The configuration for automated routing.
  /// 
  /// When automated routing is specified, the routing will be determined by
  /// the pretrained routing model and customer provided model routing
  /// preference.
  package struct GenerationConfigRoutingConfigAutoRoutingMode: Codable, Sendable, Equatable, Hashable {
    /// The model routing preference.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The model routing preference.
    package let modelRoutingPreference: ModelRoutingPreference?
    

    /// Creates a new `GenerationConfigRoutingConfigAutoRoutingMode`.
    ///
    /// - Parameters:
    ///   - modelRoutingPreference: The model routing preference. (Gemini Enterprise Agent Platform only). For more details, see ``modelRoutingPreference``.
    package init(
      modelRoutingPreference: ModelRoutingPreference? = nil
    ) {
      self.modelRoutingPreference = modelRoutingPreference
    }
    enum CodingKeys: String, CodingKey {
      case modelRoutingPreference = "modelRoutingPreference"
    }
  }
}