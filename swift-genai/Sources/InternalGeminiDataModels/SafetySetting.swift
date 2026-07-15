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
  /// An internal data model for `SafetySetting`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaSafetySetting`
  /// 
  /// Safety setting, affecting the safety-blocking behavior.
  /// 
  /// Passing a safety setting for a category changes the allowed probability that
  /// content is blocked.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1SafetySetting`
  /// 
  /// A safety setting that affects the safety-blocking behavior.
  /// 
  /// A SafetySetting consists of a
  /// harm category and a
  /// threshold for that
  /// category.
  package struct SafetySetting: Codable, Sendable, Equatable, Hashable {
    /// Required. The category for this setting.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The category for this setting.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The harm category to be blocked.
    package let category: HarmCategory
    
    /// Required. Controls the probability threshold at which harm is blocked.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. Controls the probability threshold at which harm is blocked.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The threshold for blocking content. If the harm probability
    /// exceeds this threshold, the content will be blocked.
    package let threshold: Threshold
    
    /// Optional. The method for blocking content. If not specified, the default
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The method for blocking content. If not specified, the default
    /// behavior is to use the probability score.
    package let method: Method?
    

    /// Creates a new `SafetySetting`.
    ///
    /// - Parameters:
    ///   - category: Required. The category for this setting. (behavior varies by backend). For more details, see ``category``.
    ///   - threshold: Required. Controls the probability threshold at which harm is blocked. (behavior varies by backend). For more details, see ``threshold``.
    ///   - method: Optional. The method for blocking content. If not specified, the default (Gemini Enterprise Agent Platform only). For more details, see ``method``.
    package init(
      category: HarmCategory,
      threshold: Threshold,
      method: Method? = nil
    ) {
      self.category = category
      self.threshold = threshold
      self.method = method
    }
    enum CodingKeys: String, CodingKey {
      case category = "category"
      case threshold = "threshold"
      case method = "method"
    }
  }
}