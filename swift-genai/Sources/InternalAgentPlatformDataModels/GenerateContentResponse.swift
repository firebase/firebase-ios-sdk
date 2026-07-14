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




extension AgentPlatform {
  /// Response message for [PredictionService.GenerateContent].
  public struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable {
    /// Output only. Generated candidates.
    public var candidates: [Candidate]?
    
    /// Output only. Timestamp when the request is made to the server.
    public var createTime: Date?
    
    /// Output only. The model version used to generate the response.
    public var modelVersion: String?
    
    /// Output only. Content filter results for a prompt sent in the request. Note: Sent only in the first stream chunk. Only happens when no candidates were generated due to content violations.
    public var promptFeedback: GenerateContentResponsePromptFeedback?
    
    /// Output only. response_id is used to identify each response. It is the encoding of the event_id.
    public var responseId: String?
    
    /// Usage metadata about the response(s).
    public var usageMetadata: GenerateContentResponseUsageMetadata?
    
    /// Creates a new `GenerateContentResponse`.
    public init(
      candidates: [Candidate]? = nil,
      createTime: Date? = nil,
      modelVersion: String? = nil,
      promptFeedback: GenerateContentResponsePromptFeedback? = nil,
      responseId: String? = nil,
      usageMetadata: GenerateContentResponseUsageMetadata? = nil
    ) {
      self.candidates = candidates
      self.createTime = createTime
      self.modelVersion = modelVersion
      self.promptFeedback = promptFeedback
      self.responseId = responseId
      self.usageMetadata = usageMetadata
    }
    enum CodingKeys: String, CodingKey {
      case candidates = "candidates"
      case createTime = "createTime"
      case modelVersion = "modelVersion"
      case promptFeedback = "promptFeedback"
      case responseId = "responseId"
      case usageMetadata = "usageMetadata"
    }
  }
}