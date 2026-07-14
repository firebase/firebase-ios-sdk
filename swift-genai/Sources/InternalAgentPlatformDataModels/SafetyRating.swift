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


extension AgentPlatform {
  /// A safety rating for a piece of content. The safety rating contains the harm category and the harm probability level.
  public struct SafetyRating: Codable, Sendable, Equatable, Hashable {
    /// Output only. Indicates whether the content was blocked because of this rating.
    public var blocked: Bool?
    
    /// Output only. The harm category of this rating.
    public var category: Category?
    
    /// Output only. The overwritten threshold for the safety category of Gemini 2.0 image out. If minors are detected in the output image, the threshold of each safety category will be overwritten if user sets a lower threshold.
    public var overwrittenThreshold: OverwrittenThreshold?
    
    /// Output only. The probability of harm for this category.
    public var probability: Probability?
    
    /// Output only. The probability score of harm for this category.
    public var probabilityScore: Double?
    
    /// Output only. The severity of harm for this category.
    public var severity: Severity?
    
    /// Output only. The severity score of harm for this category.
    public var severityScore: Double?
    
    /// Creates a new `SafetyRating`.
    public init(
      blocked: Bool? = nil,
      category: Category? = nil,
      overwrittenThreshold: OverwrittenThreshold? = nil,
      probability: Probability? = nil,
      probabilityScore: Double? = nil,
      severity: Severity? = nil,
      severityScore: Double? = nil
    ) {
      self.blocked = blocked
      self.category = category
      self.overwrittenThreshold = overwrittenThreshold
      self.probability = probability
      self.probabilityScore = probabilityScore
      self.severity = severity
      self.severityScore = severityScore
    }
    enum CodingKeys: String, CodingKey {
      case blocked = "blocked"
      case category = "category"
      case overwrittenThreshold = "overwrittenThreshold"
      case probability = "probability"
      case probabilityScore = "probabilityScore"
      case severity = "severity"
      case severityScore = "severityScore"
    }
  }
}