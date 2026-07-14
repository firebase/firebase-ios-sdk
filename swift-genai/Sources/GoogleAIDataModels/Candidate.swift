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


extension GoogleAI {
  /// A response candidate generated from the model.
  public struct Candidate: Codable, Sendable, Equatable, Hashable {
    /// Output only. Average log probability score of the candidate.
    public var avgLogprobs: Double?
    
    /// Output only. Citation information for model-generated candidate. This field may be populated with recitation information for any text included in the `content`. These are passages that are "recited" from copyrighted material in the foundational LLM's training data.
    public var citationMetadata: CitationMetadata?
    
    /// Output only. Generated content returned from the model.
    public var content: Content?
    
    /// Optional. Output only. Details the reason why the model stopped generating tokens. This is populated only when `finish_reason` is set.
    public var finishMessage: String?
    
    /// Optional. Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating tokens.
    public var finishReason: FinishReason?
    
    /// Output only. Attribution information for sources that contributed to a grounded answer. This field is populated for `GenerateAnswer` calls.
    public var groundingAttributions: [GroundingAttribution]?
    
    /// Output only. Grounding metadata for the candidate. This field is populated for `GenerateContent` calls.
    public var groundingMetadata: GroundingMetadata?
    
    /// Output only. Index of the candidate in the list of response candidates.
    public var index: Int?
    
    /// Output only. Log-likelihood scores for the response tokens and top tokens
    public var logprobsResult: LogprobsResult?
    
    /// List of ratings for the safety of a response candidate. There is at most one rating per category.
    public var safetyRatings: [SafetyRating]?
    
    /// Output only. Token count for this candidate.
    public var tokenCount: Int?
    
    /// Output only. Metadata related to url context retrieval tool.
    public var urlContextMetadata: UrlContextMetadata?
    
    /// Creates a new `Candidate`.
    public init(
      avgLogprobs: Double? = nil,
      citationMetadata: CitationMetadata? = nil,
      content: Content? = nil,
      finishMessage: String? = nil,
      finishReason: FinishReason? = nil,
      groundingAttributions: [GroundingAttribution]? = nil,
      groundingMetadata: GroundingMetadata? = nil,
      index: Int? = nil,
      logprobsResult: LogprobsResult? = nil,
      safetyRatings: [SafetyRating]? = nil,
      tokenCount: Int? = nil,
      urlContextMetadata: UrlContextMetadata? = nil
    ) {
      self.avgLogprobs = avgLogprobs
      self.citationMetadata = citationMetadata
      self.content = content
      self.finishMessage = finishMessage
      self.finishReason = finishReason
      self.groundingAttributions = groundingAttributions
      self.groundingMetadata = groundingMetadata
      self.index = index
      self.logprobsResult = logprobsResult
      self.safetyRatings = safetyRatings
      self.tokenCount = tokenCount
      self.urlContextMetadata = urlContextMetadata
    }
    enum CodingKeys: String, CodingKey {
      case avgLogprobs = "avgLogprobs"
      case citationMetadata = "citationMetadata"
      case content = "content"
      case finishMessage = "finishMessage"
      case finishReason = "finishReason"
      case groundingAttributions = "groundingAttributions"
      case groundingMetadata = "groundingMetadata"
      case index = "index"
      case logprobsResult = "logprobsResult"
      case safetyRatings = "safetyRatings"
      case tokenCount = "tokenCount"
      case urlContextMetadata = "urlContextMetadata"
    }
  }
}