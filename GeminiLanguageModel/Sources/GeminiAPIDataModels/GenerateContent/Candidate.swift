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

/// A response candidate generated from the model.
package struct Candidate: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The average log probability of the tokens in this candidate. This is a length-normalized score
  /// that can be used to compare the quality of candidates of different lengths. A higher average
  /// log probability suggests a more confident and coherent response.
  package var avgLogprobs: Double?

  /// A collection of citations that apply to the generated content.
  package var citationMetadata: CitationMetadata?

  /// The content of the candidate.
  package var content: Content?

  /// Describes the reason the model stopped generating tokens in more detail. This field is
  /// returned only when `finish_reason` is set.
  package var finishMessage: String?

  /// The reason why the model stopped generating tokens. If empty, the model has not stopped
  /// generating.
  package var finishReason: FinishReason?

  /// Metadata returned when grounding is enabled. It contains the sources used to ground the
  /// generated content.
  package var groundingMetadata: GroundingMetadata?

  /// The 0-based index of this candidate in the list of generated responses. This is useful for
  /// distinguishing between multiple candidates when `candidate_count` > 1.
  package var index: Int?

  /// The detailed log probability information for the tokens in this candidate. This is useful for
  /// debugging, understanding model uncertainty, and identifying potential "hallucinations".
  package var logprobsResult: LogprobsResult?

  /// A list of ratings for the safety of a response candidate. There is at most one rating per
  /// category.
  package var safetyRatings: [SafetyRating]?

  /// Token count for this candidate.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var tokenCount: Int?

  /// Metadata returned when the model uses the `url_context` tool to get information from a
  /// user-provided URL.
  package var urlContextMetadata: URLContextMetadata?

  /// Initializes a new `Candidate`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case avgLogprobs
    case citationMetadata
    case content
    case finishMessage
    case finishReason
    case groundingMetadata
    case index
    case logprobsResult
    case safetyRatings
    case tokenCount
    case urlContextMetadata
  }
}
