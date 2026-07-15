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
  /// An internal data model for `GenerateContentResponse`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGenerateContentResponse`
  /// 
  /// Response from the model supporting multiple candidate responses.
  /// 
  /// Safety ratings and content filtering are reported for both
  /// prompt in `GenerateContentResponse.prompt_feedback` and for each candidate
  /// in `finish_reason` and in `safety_ratings`. The API:
  ///  - Returns either all requested candidates or none of them
  ///  - Returns no candidates at all only if there was something wrong with the
  ///    prompt (check `prompt_feedback`)
  ///  - Reports feedback on each candidate in `finish_reason` and
  ///    `safety_ratings`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerateContentResponse`
  /// 
  /// Response message for [PredictionService.GenerateContent].
  package struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable {
    /// Candidate responses from the model.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Candidate responses from the model.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Generated candidates.
    package let candidates: [Candidate]?
    
    /// Returns the prompt's feedback related to the content filters.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Returns the prompt's feedback related to the content filters.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Content filter results for a prompt sent in the request.
    /// Note: Sent only in the first stream chunk.
    /// Only happens when no candidates were generated due to content violations.
    package let promptFeedback: PromptFeedback?
    
    /// Output only. Metadata on the generation requests' token usage.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Metadata on the generation requests' token usage.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Usage metadata about the response(s).
    package let usageMetadata: UsageMetadata?
    
    /// Output only. The model version used to generate the response.
    package let modelVersion: String?
    
    /// Output only. response_id is used to identify each response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. response_id is used to identify each response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. response_id is used to identify each response. It is the encoding of the
    /// event_id.
    package let responseId: String?
    
    /// Output only. The current model status of this model.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. The current model status of this model.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let modelStatus: ModelStatus?
    
    /// Output only. Timestamp when the request is made to the server.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. Timestamp when the request is made to the server.
    package let createTime: String?
    

    /// Creates a new `GenerateContentResponse`.
    ///
    /// - Parameters:
    ///   - candidates: Candidate responses from the model. (behavior varies by backend). For more details, see ``candidates``.
    ///   - promptFeedback: Returns the prompt's feedback related to the content filters. (behavior varies by backend). For more details, see ``promptFeedback``.
    ///   - usageMetadata: Output only. Metadata on the generation requests' token usage. (behavior varies by backend). For more details, see ``usageMetadata``.
    ///   - modelVersion: Output only. The model version used to generate the response.
    ///   - responseId: Output only. response_id is used to identify each response. (behavior varies by backend). For more details, see ``responseId``.
    ///   - modelStatus: Output only. The current model status of this model. (Gemini Developer API only). For more details, see ``modelStatus``.
    ///   - createTime: Output only. Timestamp when the request is made to the server. (Gemini Enterprise Agent Platform only). For more details, see ``createTime``.
    package init(
      candidates: [Candidate]? = nil,
      promptFeedback: PromptFeedback? = nil,
      usageMetadata: UsageMetadata? = nil,
      modelVersion: String? = nil,
      responseId: String? = nil,
      modelStatus: ModelStatus? = nil,
      createTime: String? = nil
    ) {
      self.candidates = candidates
      self.promptFeedback = promptFeedback
      self.usageMetadata = usageMetadata
      self.modelVersion = modelVersion
      self.responseId = responseId
      self.modelStatus = modelStatus
      self.createTime = createTime
    }
    enum CodingKeys: String, CodingKey {
      case candidates = "candidates"
      case promptFeedback = "promptFeedback"
      case usageMetadata = "usageMetadata"
      case modelVersion = "modelVersion"
      case responseId = "responseId"
      case modelStatus = "modelStatus"
      case createTime = "createTime"
    }
  }
}