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
  /// An internal data model for `Candidate`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCandidate`
  /// 
  /// A response candidate generated from the model.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1Candidate`
  /// 
  /// A response candidate generated from the model.
  package struct Candidate: Codable, Sendable, Equatable, Hashable {
    /// Output only. Index of the candidate in the list of response candidates.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Index of the candidate in the list of response candidates.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The 0-based index of this candidate in the list of generated
    /// responses. This is useful for distinguishing between multiple candidates
    /// when `candidate_count` > 1.
    package let index: Int?
    
    /// Output only. Generated content returned from the model.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Generated content returned from the model.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The content of the candidate.
    package let content: Content?
    
    /// Optional. Output only. The reason why the model stopped generating tokens.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Output only. The reason why the model stopped generating tokens.
    /// 
    /// If empty, the model has not stopped generating tokens.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The reason why the model stopped generating tokens. If empty,
    /// the model has not stopped generating.
    package let finishReason: FinishReason?
    
    /// Optional. Output only. Details the reason why the model stopped generating tokens.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Output only. Details the reason why the model stopped generating tokens.
    /// This is populated only when `finish_reason` is set.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Describes the reason the model stopped generating tokens in
    /// more detail. This field is returned only when `finish_reason` is set.
    package let finishMessage: String?
    
    /// List of ratings for the safety of a response candidate.
    /// 
    /// ### Gemini Developer API
    /// 
    /// List of ratings for the safety of a response candidate.
    /// 
    /// There is at most one rating per category.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A list of ratings for the safety of a response candidate.
    /// 
    /// There is at most one rating per category.
    package let safetyRatings: [SafetyRating]?
    
    /// Output only. Citation information for model-generated candidate.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Citation information for model-generated candidate.
    /// 
    /// This field may be populated with recitation information for any text
    /// included in the `content`. These are passages that are "recited" from
    /// copyrighted material in the foundational LLM's training data.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A collection of citations that apply to the generated content.
    package let citationMetadata: CitationMetadata?
    
    /// Output only. Token count for this candidate.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Token count for this candidate.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let tokenCount: Int?
    
    /// Output only. Attribution information for sources that contributed to a grounded answer.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Attribution information for sources that contributed to a grounded answer.
    /// 
    /// This field is populated for `GenerateAnswer` calls.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let groundingAttributions: [GroundingAttribution]?
    
    /// Output only. Grounding metadata for the candidate.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Grounding metadata for the candidate.
    /// 
    /// This field is populated for `GenerateContent` calls.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Metadata returned when grounding is enabled. It contains the
    /// sources used to ground the generated content.
    package let groundingMetadata: GroundingMetadata?
    
    /// Output only. Average log probability score of the candidate.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Average log probability score of the candidate.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The average log probability of the tokens in this candidate.
    /// This is a length-normalized score that can be used to compare the quality
    /// of candidates of different lengths. A higher average log probability
    /// suggests a more confident and coherent response.
    package let avgLogprobs: Double?
    
    /// Output only. Log-likelihood scores for the response tokens and top tokens
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Log-likelihood scores for the response tokens and top tokens
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The detailed log probability information for the tokens in
    /// this candidate. This is useful for debugging, understanding model
    /// uncertainty, and identifying potential "hallucinations".
    package let logprobsResult: LogprobsResult?
    
    /// Output only. Metadata related to url context retrieval tool.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Metadata related to url context retrieval tool.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Metadata returned when the model uses the `url_context` tool
    /// to get information from a user-provided URL.
    package let urlContextMetadata: UrlContextMetadata?
    

    /// Creates a new `Candidate`.
    ///
    /// - Parameters:
    ///   - index: Output only. Index of the candidate in the list of response candidates. (behavior varies by backend). For more details, see ``index``.
    ///   - content: Output only. Generated content returned from the model. (behavior varies by backend). For more details, see ``content``.
    ///   - finishReason: Optional. Output only. The reason why the model stopped generating tokens. (behavior varies by backend). For more details, see ``finishReason``.
    ///   - finishMessage: Optional. Output only. Details the reason why the model stopped generating tokens. (behavior varies by backend). For more details, see ``finishMessage``.
    ///   - safetyRatings: List of ratings for the safety of a response candidate. (behavior varies by backend). For more details, see ``safetyRatings``.
    ///   - citationMetadata: Output only. Citation information for model-generated candidate. (behavior varies by backend). For more details, see ``citationMetadata``.
    ///   - tokenCount: Output only. Token count for this candidate. (Gemini Developer API only). For more details, see ``tokenCount``.
    ///   - groundingAttributions: Output only. Attribution information for sources that contributed to a grounded answer. (Gemini Developer API only). For more details, see ``groundingAttributions``.
    ///   - groundingMetadata: Output only. Grounding metadata for the candidate. (behavior varies by backend). For more details, see ``groundingMetadata``.
    ///   - avgLogprobs: Output only. Average log probability score of the candidate. (behavior varies by backend). For more details, see ``avgLogprobs``.
    ///   - logprobsResult: Output only. Log-likelihood scores for the response tokens and top tokens (behavior varies by backend). For more details, see ``logprobsResult``.
    ///   - urlContextMetadata: Output only. Metadata related to url context retrieval tool. (behavior varies by backend). For more details, see ``urlContextMetadata``.
    package init(
      index: Int? = nil,
      content: Content? = nil,
      finishReason: FinishReason? = nil,
      finishMessage: String? = nil,
      safetyRatings: [SafetyRating]? = nil,
      citationMetadata: CitationMetadata? = nil,
      tokenCount: Int? = nil,
      groundingAttributions: [GroundingAttribution]? = nil,
      groundingMetadata: GroundingMetadata? = nil,
      avgLogprobs: Double? = nil,
      logprobsResult: LogprobsResult? = nil,
      urlContextMetadata: UrlContextMetadata? = nil
    ) {
      self.index = index
      self.content = content
      self.finishReason = finishReason
      self.finishMessage = finishMessage
      self.safetyRatings = safetyRatings
      self.citationMetadata = citationMetadata
      self.tokenCount = tokenCount
      self.groundingAttributions = groundingAttributions
      self.groundingMetadata = groundingMetadata
      self.avgLogprobs = avgLogprobs
      self.logprobsResult = logprobsResult
      self.urlContextMetadata = urlContextMetadata
    }
    enum CodingKeys: String, CodingKey {
      case index = "index"
      case content = "content"
      case finishReason = "finishReason"
      case finishMessage = "finishMessage"
      case safetyRatings = "safetyRatings"
      case citationMetadata = "citationMetadata"
      case tokenCount = "tokenCount"
      case groundingAttributions = "groundingAttributions"
      case groundingMetadata = "groundingMetadata"
      case avgLogprobs = "avgLogprobs"
      case logprobsResult = "logprobsResult"
      case urlContextMetadata = "urlContextMetadata"
    }
  }
}