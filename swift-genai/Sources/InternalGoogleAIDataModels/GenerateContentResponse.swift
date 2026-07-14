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
  /// Response from the model supporting multiple candidate responses. Safety ratings and content filtering are reported for both prompt in `GenerateContentResponse.prompt_feedback` and for each candidate in `finish_reason` and in `safety_ratings`. The API: - Returns either all requested candidates or none of them - Returns no candidates at all only if there was something wrong with the prompt (check `prompt_feedback`) - Reports feedback on each candidate in `finish_reason` and `safety_ratings`.
  public struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable {
    /// Candidate responses from the model.
    public var candidates: [Candidate]?
    
    /// Output only. The current model status of this model.
    public var modelStatus: ModelStatus?
    
    /// Output only. The model version used to generate the response.
    public var modelVersion: String?
    
    /// Returns the prompt's feedback related to the content filters.
    public var promptFeedback: PromptFeedback?
    
    /// Output only. response_id is used to identify each response.
    public var responseId: String?
    
    /// Output only. Metadata on the generation requests' token usage.
    public var usageMetadata: UsageMetadata?
    
    /// Creates a new `GenerateContentResponse`.
    public init(
      candidates: [Candidate]? = nil,
      modelStatus: ModelStatus? = nil,
      modelVersion: String? = nil,
      promptFeedback: PromptFeedback? = nil,
      responseId: String? = nil,
      usageMetadata: UsageMetadata? = nil
    ) {
      self.candidates = candidates
      self.modelStatus = modelStatus
      self.modelVersion = modelVersion
      self.promptFeedback = promptFeedback
      self.responseId = responseId
      self.usageMetadata = usageMetadata
    }
    enum CodingKeys: String, CodingKey {
      case candidates = "candidates"
      case modelStatus = "modelStatus"
      case modelVersion = "modelVersion"
      case promptFeedback = "promptFeedback"
      case responseId = "responseId"
      case usageMetadata = "usageMetadata"
    }
  }
}