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
package import SharedDataModels
package import GoogleAIDataModels
package import AgentPlatformDataModels

// MARK: - GenerateContentResponse

/// Response from the model supporting multiple candidate responses.
public struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable {
  /// Candidate responses from the model.
  public var candidates: [Candidate]?

  /// The model version used to generate the response.
  public var modelVersion: String?

  /// Returns the prompt's feedback related to content filters.
  public var promptFeedback: PromptFeedback?

  /// response_id is used to identify each response.
  public var responseId: String?

  /// Metadata on the generation request's token usage.
  public var usageMetadata: UsageMetadata?

  // GoogleAI Exclusives
  /// - Note: Only supported on GoogleAI backend.
  package var modelStatus: GoogleAIDataModels.GoogleAI.ModelStatus?

  // AgentPlatform Exclusives
  /// - Note: Only supported on AgentPlatform backend.
  public var createTime: Date?

  public init(
    candidates: [Candidate]? = nil,
    modelVersion: String? = nil,
    promptFeedback: PromptFeedback? = nil,
    responseId: String? = nil,
    usageMetadata: UsageMetadata? = nil,
    createTime: Date? = nil
  ) {
    self.candidates = candidates
    self.modelVersion = modelVersion
    self.promptFeedback = promptFeedback
    self.responseId = responseId
    self.usageMetadata = usageMetadata
    self.modelStatus = nil
    self.createTime = createTime
  }

  package init(
    candidates: [Candidate]? = nil,
    modelVersion: String? = nil,
    promptFeedback: PromptFeedback? = nil,
    responseId: String? = nil,
    usageMetadata: UsageMetadata? = nil,
    modelStatus: GoogleAIDataModels.GoogleAI.ModelStatus? = nil,
    createTime: Date? = nil
  ) {
    self.candidates = candidates
    self.modelVersion = modelVersion
    self.promptFeedback = promptFeedback
    self.responseId = responseId
    self.usageMetadata = usageMetadata
    self.modelStatus = modelStatus
    self.createTime = createTime
  }
}

// MARK: - GoogleAI Mappings

extension GenerateContentResponse {
  package func toGoogleAI() -> GoogleAI.GenerateContentResponse {
    GoogleAI.GenerateContentResponse(
      candidates: candidates?.map { $0.toGoogleAI() },
      modelStatus: modelStatus,
      modelVersion: modelVersion,
      promptFeedback: promptFeedback?.toGoogleAI(),
      responseId: responseId,
      usageMetadata: usageMetadata?.toGoogleAI()
    )
  }

  package init(fromGoogleAI res: GoogleAI.GenerateContentResponse) {
    self.candidates = res.candidates?.map { Candidate(fromGoogleAI: $0) }
    self.modelVersion = res.modelVersion
    self.promptFeedback = res.promptFeedback.map { PromptFeedback(fromGoogleAI: $0) }
    self.responseId = res.responseId
    self.usageMetadata = res.usageMetadata.map { UsageMetadata(fromGoogleAI: $0) }
    self.modelStatus = res.modelStatus
    self.createTime = nil
  }
}

// MARK: - AgentPlatform Mappings

extension GenerateContentResponse {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponse {
    AgentPlatform.GenerateContentResponse(
      candidates: candidates?.map { $0.toAgentPlatform() },
      createTime: createTime,
      modelVersion: modelVersion,
      promptFeedback: promptFeedback?.toAgentPlatform(),
      responseId: responseId,
      usageMetadata: usageMetadata?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform res: AgentPlatform.GenerateContentResponse) {
    self.candidates = res.candidates?.map { Candidate(fromAgentPlatform: $0) }
    self.modelVersion = res.modelVersion
    self.promptFeedback = res.promptFeedback.map { PromptFeedback(fromAgentPlatform: $0) }
    self.responseId = res.responseId
    self.usageMetadata = res.usageMetadata.map { UsageMetadata(fromAgentPlatform: $0) }
    self.modelStatus = nil
    self.createTime = res.createTime
  }
}
