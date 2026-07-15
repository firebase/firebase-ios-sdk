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
  /// An internal data model for `SafetyRating`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaSafetyRating`
  /// 
  /// Safety rating for a piece of content.
  /// 
  /// The safety rating contains the category of harm and the
  /// harm probability level in that category for a piece of content.
  /// Content is classified for safety across a number of
  /// harm categories and the probability of the harm classification is included
  /// here.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1SafetyRating`
  /// 
  /// A safety rating for a piece of content.
  /// 
  /// The safety rating contains the harm category and the harm probability level.
  package struct SafetyRating: Codable, Sendable, Equatable, Hashable {
    /// Required. The category for this rating.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The category for this rating.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The harm category of this rating.
    package let category: HarmCategory?
    
    /// Required. The probability of harm for this content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The probability of harm for this content.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The probability of harm for this category.
    package let probability: Probability?
    
    /// Was this content blocked because of this rating?
    /// 
    /// ### Gemini Developer API
    /// 
    /// Was this content blocked because of this rating?
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Indicates whether the content was blocked because of this
    /// rating.
    package let blocked: Bool?
    
    /// Output only. The probability score of harm for this category.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The probability score of harm for this category.
    package let probabilityScore: Double?
    
    /// Output only. The severity of harm for this category.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The severity of harm for this category.
    package let severity: Severity?
    
    /// Output only. The severity score of harm for this category.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The severity score of harm for this category.
    package let severityScore: Double?
    
    /// Output only. The overwritten threshold for the safety category of
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The overwritten threshold for the safety category of
    /// Gemini 2.0 image out. If minors are detected in the output image, the
    /// threshold of each safety category will be overwritten if user sets a lower
    /// threshold.
    package let overwrittenThreshold: OverwrittenThreshold?
    

    /// Creates a new `SafetyRating`.
    ///
    /// - Parameters:
    ///   - category: Required. The category for this rating. (behavior varies by backend). For more details, see ``category``.
    ///   - probability: Required. The probability of harm for this content. (behavior varies by backend). For more details, see ``probability``.
    ///   - blocked: Was this content blocked because of this rating? (behavior varies by backend). For more details, see ``blocked``.
    ///   - probabilityScore: Output only. The probability score of harm for this category. (Gemini Enterprise Agent Platform only). For more details, see ``probabilityScore``.
    ///   - severity: Output only. The severity of harm for this category. (Gemini Enterprise Agent Platform only). For more details, see ``severity``.
    ///   - severityScore: Output only. The severity score of harm for this category. (Gemini Enterprise Agent Platform only). For more details, see ``severityScore``.
    ///   - overwrittenThreshold: Output only. The overwritten threshold for the safety category of (Gemini Enterprise Agent Platform only). For more details, see ``overwrittenThreshold``.
    package init(
      category: HarmCategory? = nil,
      probability: Probability? = nil,
      blocked: Bool? = nil,
      probabilityScore: Double? = nil,
      severity: Severity? = nil,
      severityScore: Double? = nil,
      overwrittenThreshold: OverwrittenThreshold? = nil
    ) {
      self.category = category
      self.probability = probability
      self.blocked = blocked
      self.probabilityScore = probabilityScore
      self.severity = severity
      self.severityScore = severityScore
      self.overwrittenThreshold = overwrittenThreshold
    }
    enum CodingKeys: String, CodingKey {
      case category = "category"
      case probability = "probability"
      case blocked = "blocked"
      case probabilityScore = "probabilityScore"
      case severity = "severity"
      case severityScore = "severityScore"
      case overwrittenThreshold = "overwrittenThreshold"
    }
  }
}