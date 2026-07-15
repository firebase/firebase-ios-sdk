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
  /// An internal data model for `DynamicRetrievalConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaDynamicRetrievalConfig`
  /// 
  /// Describes the options to customize dynamic retrieval.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1DynamicRetrievalConfig`
  /// 
  /// Describes the options to customize dynamic retrieval.
  package struct DynamicRetrievalConfig: Codable, Sendable, Equatable, Hashable {
    /// The mode of the predictor to be used in dynamic retrieval.
    package let mode: Mode?
    
    /// The threshold to be used in dynamic retrieval.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The threshold to be used in dynamic retrieval.
    /// If not set, a system default value is used.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The threshold to be used in dynamic retrieval.
    /// If not set, a system default value is used.
    package let dynamicThreshold: Double?
    

    /// Creates a new `DynamicRetrievalConfig`.
    ///
    /// - Parameters:
    ///   - mode: The mode of the predictor to be used in dynamic retrieval.
    ///   - dynamicThreshold: The threshold to be used in dynamic retrieval. (behavior varies by backend). For more details, see ``dynamicThreshold``.
    package init(
      mode: Mode? = nil,
      dynamicThreshold: Double? = nil
    ) {
      self.mode = mode
      self.dynamicThreshold = dynamicThreshold
    }
    enum CodingKeys: String, CodingKey {
      case mode = "mode"
      case dynamicThreshold = "dynamicThreshold"
    }
  }
}