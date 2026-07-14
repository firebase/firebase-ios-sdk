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
  /// Safety rating for a piece of content. The safety rating contains the category of harm and the harm probability level in that category for a piece of content. Content is classified for safety across a number of harm categories and the probability of the harm classification is included here.
  /// 
  /// Variant:
  /// A safety rating for a piece of content. The safety rating contains the harm category and the harm probability level.
  package struct SafetyRating: Codable, Sendable, Equatable, Hashable {
    /// Required. The probability of harm for this content.
    /// 
    /// Variant:
    /// Output only. The probability of harm for this category.
    package let probability: Probability?
    
    /// Required. The category for this rating.
    /// 
    /// Variant:
    /// Output only. The harm category of this rating.
    package let category: Category?
    
    /// Output only. The severity score of harm for this category.
    /// 
    /// > Important: `severityScore` is only available in the Gemini Enterprise Agent Platform.
    package let severityScore: Double?
    
    /// Output only. The probability score of harm for this category.
    /// 
    /// > Important: `probabilityScore` is only available in the Gemini Enterprise Agent Platform.
    package let probabilityScore: Double?
    
    /// Was this content blocked because of this rating?
    /// 
    /// Variant:
    /// Output only. Indicates whether the content was blocked because of this rating.
    package let blocked: Bool?
    
    /// Output only. The severity of harm for this category.
    /// 
    /// > Important: `severity` is only available in the Gemini Enterprise Agent Platform.
    package let severity: Severity?
    
    /// Output only. The overwritten threshold for the safety category of Gemini 2.0 image out. If minors are detected in the output image, the threshold of each safety category will be overwritten if user sets a lower threshold.
    /// 
    /// > Important: `overwrittenThreshold` is only available in the Gemini Enterprise Agent Platform.
    package let overwrittenThreshold: OverwrittenThreshold?
    
    /// Creates a new `SafetyRating`.
    package init(
      probability: Probability? = nil,
      category: Category? = nil,
      severityScore: Double? = nil,
      probabilityScore: Double? = nil,
      blocked: Bool? = nil,
      severity: Severity? = nil,
      overwrittenThreshold: OverwrittenThreshold? = nil
    ) {
      self.probability = probability
      self.category = category
      self.severityScore = severityScore
      self.probabilityScore = probabilityScore
      self.blocked = blocked
      self.severity = severity
      self.overwrittenThreshold = overwrittenThreshold
    }
    enum CodingKeys: String, CodingKey {
      case probability = "probability"
      case category = "category"
      case severityScore = "severityScore"
      case probabilityScore = "probabilityScore"
      case blocked = "blocked"
      case severity = "severity"
      case overwrittenThreshold = "overwrittenThreshold"
    }
  }
}