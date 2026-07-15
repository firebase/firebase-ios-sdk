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
  /// An internal data model for `GoogleMaps`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleMaps`
  /// 
  /// Tool to retrieve public maps data for grounding, powered by Google.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GoogleMaps`
  /// 
  /// Tool to retrieve public maps data for grounding, powered by Google.
  package struct GoogleMaps: Codable, Sendable, Equatable, Hashable {
    /// Optional. If true, include the widget context token in the response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. If true, include the widget context token in the response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Deprecated: The Google Maps contextual widget behavior in Grounding with
    /// Google Maps is being deprecated; this field is planned for removal and no
    /// longer has any effect once removed.
    /// 
    /// If true, include the widget context token in the response.
    package let enableWidget: Bool?
    

    /// Creates a new `GoogleMaps`.
    ///
    /// - Parameters:
    ///   - enableWidget: Optional. If true, include the widget context token in the response. (behavior varies by backend). For more details, see ``enableWidget``.
    package init(
      enableWidget: Bool? = nil
    ) {
      self.enableWidget = enableWidget
    }
    enum CodingKeys: String, CodingKey {
      case enableWidget = "enableWidget"
    }
  }
}