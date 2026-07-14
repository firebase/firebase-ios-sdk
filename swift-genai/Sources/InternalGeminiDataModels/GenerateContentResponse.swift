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

public import Foundation




extension GeminiDataModels {
  /// Response from the model supporting multiple candidate responses. Safety ratings and content filtering are reported for both prompt in `GenerateContentResponse.prompt_feedback` and for each candidate in `finish_reason` and in `safety_ratings`. The API: - Returns either all requested candidates or none of them - Returns no candidates at all only if there was something wrong with the prompt (check `prompt_feedback`) - Reports feedback on each candidate in `finish_reason` and `safety_ratings`.
  /// 
  /// Variant:
  /// Response message for [PredictionService.GenerateContent].
  package struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable {
    /// Returns the prompt's feedback related to the content filters.
    /// 
    /// Variant:
    /// Output only. Content filter results for a prompt sent in the request. Note: Sent only in the first stream chunk. Only happens when no candidates were generated due to content violations.
    package let promptFeedback: PromptFeedback?
    
    /// Output only. The current model status of this model.
    /// 
    /// > Important: `modelStatus` is only available in the Gemini Developer API.
    package let modelStatus: ModelStatus?
    
    /// Candidate responses from the model.
    /// 
    /// Variant:
    /// Output only. Generated candidates.
    package let candidates: [Candidate]?
    
    /// Output only. Metadata on the generation requests' token usage.
    /// 
    /// Variant:
    /// Usage metadata about the response(s).
    package let usageMetadata: UsageMetadata?
    
    /// Output only. response_id is used to identify each response.
    /// 
    /// Variant:
    /// Output only. response_id is used to identify each response. It is the encoding of the event_id.
    package let responseId: String?
    
    /// Output only. The model version used to generate the response.
    package let modelVersion: String?
    
    /// Output only. Timestamp when the request is made to the server.
    /// 
    /// > Important: `createTime` is only available in the Gemini Enterprise Agent Platform.
    package let createTime: Date?
    
    /// Creates a new `GenerateContentResponse`.
    package init(
      promptFeedback: PromptFeedback? = nil,
      modelStatus: ModelStatus? = nil,
      candidates: [Candidate]? = nil,
      usageMetadata: UsageMetadata? = nil,
      responseId: String? = nil,
      modelVersion: String? = nil,
      createTime: Date? = nil
    ) {
      self.promptFeedback = promptFeedback
      self.modelStatus = modelStatus
      self.candidates = candidates
      self.usageMetadata = usageMetadata
      self.responseId = responseId
      self.modelVersion = modelVersion
      self.createTime = createTime
    }
    enum CodingKeys: String, CodingKey {
      case promptFeedback = "promptFeedback"
      case modelStatus = "modelStatus"
      case candidates = "candidates"
      case usageMetadata = "usageMetadata"
      case responseId = "responseId"
      case modelVersion = "modelVersion"
      case createTime = "createTime"
    }
  }
}