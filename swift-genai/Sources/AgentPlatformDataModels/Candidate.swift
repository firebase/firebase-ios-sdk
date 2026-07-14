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
  /// A response candidate generated from the model.
  public struct Candidate: Codable, Sendable, Equatable, Hashable {
    /// Output only. The average log probability of the tokens in this candidate. This is a length-normalized score that can be used to compare the quality of candidates of different lengths. A higher average log probability suggests a more confident and coherent response.
    public var avgLogprobs: Double?
    
    /// Output only. A collection of citations that apply to the generated content.
    public var citationMetadata: CitationMetadata?
    
    /// Output only. The content of the candidate.
    public var content: Content?
    
    /// Output only. Describes the reason the model stopped generating tokens in more detail. This field is returned only when `finish_reason` is set.
    public var finishMessage: String?
    
    /// Output only. The reason why the model stopped generating tokens. If empty, the model has not stopped generating.
    public var finishReason: FinishReason?
    
    /// Output only. Metadata returned when grounding is enabled. It contains the sources used to ground the generated content.
    public var groundingMetadata: GroundingMetadata?
    
    /// Output only. The 0-based index of this candidate in the list of generated responses. This is useful for distinguishing between multiple candidates when `candidate_count` > 1.
    public var index: Int?
    
    /// Output only. The detailed log probability information for the tokens in this candidate. This is useful for debugging, understanding model uncertainty, and identifying potential "hallucinations".
    public var logprobsResult: LogprobsResult?
    
    /// Output only. A list of ratings for the safety of a response candidate. There is at most one rating per category.
    public var safetyRatings: [SafetyRating]?
    
    /// Output only. Metadata returned when the model uses the `url_context` tool to get information from a user-provided URL.
    public var urlContextMetadata: UrlContextMetadata?
    
    /// Creates a new `Candidate`.
    public init(
      avgLogprobs: Double? = nil,
      citationMetadata: CitationMetadata? = nil,
      content: Content? = nil,
      finishMessage: String? = nil,
      finishReason: FinishReason? = nil,
      groundingMetadata: GroundingMetadata? = nil,
      index: Int? = nil,
      logprobsResult: LogprobsResult? = nil,
      safetyRatings: [SafetyRating]? = nil,
      urlContextMetadata: UrlContextMetadata? = nil
    ) {
      self.avgLogprobs = avgLogprobs
      self.citationMetadata = citationMetadata
      self.content = content
      self.finishMessage = finishMessage
      self.finishReason = finishReason
      self.groundingMetadata = groundingMetadata
      self.index = index
      self.logprobsResult = logprobsResult
      self.safetyRatings = safetyRatings
      self.urlContextMetadata = urlContextMetadata
    }
    enum CodingKeys: String, CodingKey {
      case avgLogprobs = "avgLogprobs"
      case citationMetadata = "citationMetadata"
      case content = "content"
      case finishMessage = "finishMessage"
      case finishReason = "finishReason"
      case groundingMetadata = "groundingMetadata"
      case index = "index"
      case logprobsResult = "logprobsResult"
      case safetyRatings = "safetyRatings"
      case urlContextMetadata = "urlContextMetadata"
    }
  }
}