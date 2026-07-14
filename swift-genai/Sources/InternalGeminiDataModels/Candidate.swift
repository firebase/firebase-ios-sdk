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
  /// A response candidate generated from the model.
  package struct Candidate: Codable, Sendable, Equatable, Hashable {
    /// Output only. Grounding metadata for the candidate. This field is populated for `GenerateContent` calls.
    /// 
    /// Variant:
    /// Output only. Metadata returned when grounding is enabled. It contains the sources used to ground the generated content.
    package let groundingMetadata: GroundingMetadata?
    
    /// Output only. Index of the candidate in the list of response candidates.
    /// 
    /// Variant:
    /// Output only. The 0-based index of this candidate in the list of generated responses. This is useful for distinguishing between multiple candidates when `candidate_count` > 1.
    package let index: Int?
    
    /// Optional. Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating tokens.
    /// 
    /// Variant:
    /// Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating.
    package let finishReason: FinishReason?
    
    /// Output only. Attribution information for sources that contributed to a grounded answer. This field is populated for `GenerateAnswer` calls.
    /// 
    /// > Important: `groundingAttributions` is only available in the Gemini Developer API.
    package let groundingAttributions: [GroundingAttribution]?
    
    /// Output only. Token count for this candidate.
    /// 
    /// > Important: `tokenCount` is only available in the Gemini Developer API.
    package let tokenCount: Int?
    
    /// Output only. Metadata related to url context retrieval tool.
    /// 
    /// Variant:
    /// Output only. Metadata returned when the model uses the `url_context` tool to get information from a user-provided URL.
    package let urlContextMetadata: UrlContextMetadata?
    
    /// Output only. Log-likelihood scores for the response tokens and top tokens
    /// 
    /// Variant:
    /// Output only. The detailed log probability information for the tokens in this candidate. This is useful for debugging, understanding model uncertainty, and identifying potential "hallucinations".
    package let logprobsResult: LogprobsResult?
    
    /// Output only. Citation information for model-generated candidate. This field may be populated with recitation information for any text included in the `content`. These are passages that are "recited" from copyrighted material in the foundational LLM's training data.
    /// 
    /// Variant:
    /// Output only. A collection of citations that apply to the generated content.
    package let citationMetadata: CitationMetadata?
    
    /// Output only. Average log probability score of the candidate.
    /// 
    /// Variant:
    /// Output only. The average log probability of the tokens in this candidate. This is a length-normalized score that can be used to compare the quality of candidates of different lengths. A higher average log probability suggests a more confident and coherent response.
    package let avgLogprobs: Double?
    
    /// Optional. Output only. Details the reason why the model stopped generating tokens. This is populated only when `finish_reason` is set.
    /// 
    /// Variant:
    /// Output only. Describes the reason the model stopped generating tokens in more detail. This field is returned only when `finish_reason` is set.
    package let finishMessage: String?
    
    /// List of ratings for the safety of a response candidate. There is at most one rating per category.
    /// 
    /// Variant:
    /// Output only. A list of ratings for the safety of a response candidate. There is at most one rating per category.
    package let safetyRatings: [SafetyRating]?
    
    /// Output only. Generated content returned from the model.
    /// 
    /// Variant:
    /// Output only. The content of the candidate.
    package let content: Content?
    
    /// Creates a new `Candidate`.
    package init(
      groundingMetadata: GroundingMetadata? = nil,
      index: Int? = nil,
      finishReason: FinishReason? = nil,
      groundingAttributions: [GroundingAttribution]? = nil,
      tokenCount: Int? = nil,
      urlContextMetadata: UrlContextMetadata? = nil,
      logprobsResult: LogprobsResult? = nil,
      citationMetadata: CitationMetadata? = nil,
      avgLogprobs: Double? = nil,
      finishMessage: String? = nil,
      safetyRatings: [SafetyRating]? = nil,
      content: Content? = nil
    ) {
      self.groundingMetadata = groundingMetadata
      self.index = index
      self.finishReason = finishReason
      self.groundingAttributions = groundingAttributions
      self.tokenCount = tokenCount
      self.urlContextMetadata = urlContextMetadata
      self.logprobsResult = logprobsResult
      self.citationMetadata = citationMetadata
      self.avgLogprobs = avgLogprobs
      self.finishMessage = finishMessage
      self.safetyRatings = safetyRatings
      self.content = content
    }
    enum CodingKeys: String, CodingKey {
      case groundingMetadata = "groundingMetadata"
      case index = "index"
      case finishReason = "finishReason"
      case groundingAttributions = "groundingAttributions"
      case tokenCount = "tokenCount"
      case urlContextMetadata = "urlContextMetadata"
      case logprobsResult = "logprobsResult"
      case citationMetadata = "citationMetadata"
      case avgLogprobs = "avgLogprobs"
      case finishMessage = "finishMessage"
      case safetyRatings = "safetyRatings"
      case content = "content"
    }
  }
}