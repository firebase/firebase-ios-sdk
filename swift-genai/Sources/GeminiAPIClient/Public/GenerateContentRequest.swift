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
package import SharedDataModels
package import GoogleAIDataModels
package import AgentPlatformDataModels

// MARK: - GenerateContentRequest

/// Request to generate a completion from the model.
public struct GenerateContentRequest: Codable, Sendable, Equatable, Hashable {
  /// The name of the `Model` to use for generating the completion.
  /// - Note: Primarily used by GoogleAI backend. AgentPlatform usually specifies the model name in URL path.
  public var model: String?

  /// Required. The content of the current conversation with the model.
  public var contents: [GeminiContent]?

  /// Optional. Configuration options for model generation and outputs.
  public var generationConfig: GenerationConfig?

  /// Optional. A list of unique `SafetySetting` instances for blocking unsafe content.
  public var safetySettings: [SafetySetting]?

  /// Optional. Developer set system instruction(s).
  public var systemInstruction: GeminiContent?

  /// Optional. A list of tools the model may use.
  public var tools: [GeminiTool]?

  /// Optional. Tool configuration.
  public var toolConfig: ToolConfig?

  /// Optional. The name of the cached content to use as context.
  public var cachedContent: String?

  // GoogleAI Exclusives
  /// - Note: Only supported on GoogleAI backend.
  public var serviceTier: ServiceTier?

  /// - Note: Only supported on GoogleAI backend.
  public var store: Bool?

  // AgentPlatform Exclusives
  /// - Note: Only supported on AgentPlatform backend.
  public var labels: [String: String]?

  /// - Note: Only supported on AgentPlatform backend.
  package var modelArmorConfig: AgentPlatformDataModels.AgentPlatform.ModelArmorConfig?

  public init(
    model: String? = nil,
    contents: [GeminiContent]? = nil,
    generationConfig: GenerationConfig? = nil,
    safetySettings: [SafetySetting]? = nil,
    systemInstruction: GeminiContent? = nil,
    tools: [GeminiTool]? = nil,
    toolConfig: ToolConfig? = nil,
    cachedContent: String? = nil,
    serviceTier: ServiceTier? = nil,
    store: Bool? = nil,
    labels: [String: String]? = nil
  ) {
    self.model = model
    self.contents = contents
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.systemInstruction = systemInstruction
    self.tools = tools
    self.toolConfig = toolConfig
    self.cachedContent = cachedContent
    self.serviceTier = serviceTier
    self.store = store
    self.labels = labels
    self.modelArmorConfig = nil
  }

  package init(
    model: String? = nil,
    contents: [GeminiContent]? = nil,
    generationConfig: GenerationConfig? = nil,
    safetySettings: [SafetySetting]? = nil,
    systemInstruction: GeminiContent? = nil,
    tools: [GeminiTool]? = nil,
    toolConfig: ToolConfig? = nil,
    cachedContent: String? = nil,
    serviceTier: ServiceTier? = nil,
    store: Bool? = nil,
    labels: [String: String]? = nil,
    modelArmorConfig: AgentPlatformDataModels.AgentPlatform.ModelArmorConfig? = nil
  ) {
    self.model = model
    self.contents = contents
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.systemInstruction = systemInstruction
    self.tools = tools
    self.toolConfig = toolConfig
    self.cachedContent = cachedContent
    self.serviceTier = serviceTier
    self.store = store
    self.labels = labels
    self.modelArmorConfig = modelArmorConfig
  }
}

// MARK: - GoogleAI Mappings

extension GenerateContentRequest {
  package func toGoogleAI() -> GoogleAI.GenerateContentRequest {
    GoogleAI.GenerateContentRequest(
      cachedContent: cachedContent,
      contents: contents?.map { $0.toGoogleAI() },
      generationConfig: generationConfig?.toGoogleAI(),
      model: model,
      safetySettings: safetySettings?.map { $0.toGoogleAI() },
      serviceTier: serviceTier?.toGoogleAI(),
      store: store,
      systemInstruction: systemInstruction?.toGoogleAI(),
      toolConfig: toolConfig?.toGoogleAI(),
      tools: tools?.map { $0.toGoogleAI() }
    )
  }

  package init(fromGoogleAI request: GoogleAI.GenerateContentRequest) {
    self.model = request.model
    self.contents = request.contents?.map { GeminiContent(fromGoogleAI: $0) }
    self.generationConfig = request.generationConfig.map { GenerationConfig(fromGoogleAI: $0) }
    self.safetySettings = request.safetySettings?.map { SafetySetting(fromGoogleAI: $0) }
    self.systemInstruction = request.systemInstruction.map { GeminiContent(fromGoogleAI: $0) }
    self.tools = request.tools?.map { GeminiTool(fromGoogleAI: $0) }
    self.toolConfig = request.toolConfig.map { ToolConfig(fromGoogleAI: $0) }
    self.cachedContent = request.cachedContent
    self.serviceTier = request.serviceTier.map { ServiceTier(fromGoogleAI: $0) }
    self.store = request.store
    self.labels = nil
    self.modelArmorConfig = nil
  }
}

// MARK: - AgentPlatform Mappings

extension GenerateContentRequest {
  package func toAgentPlatform() -> AgentPlatform.GenerateContentRequest {
    AgentPlatform.GenerateContentRequest(
      cachedContent: cachedContent,
      contents: contents?.map { $0.toAgentPlatform() },
      generationConfig: generationConfig?.toAgentPlatform(),
      labels: labels,
      modelArmorConfig: modelArmorConfig,
      safetySettings: safetySettings?.map { $0.toAgentPlatform() },
      systemInstruction: systemInstruction?.toAgentPlatform(),
      toolConfig: toolConfig?.toAgentPlatform(),
      tools: tools?.map { $0.toAgentPlatform() }
    )
  }

  package init(fromAgentPlatform request: AgentPlatform.GenerateContentRequest) {
    self.model = nil
    self.contents = request.contents?.map { GeminiContent(fromAgentPlatform: $0) }
    self.generationConfig = request.generationConfig.map { GenerationConfig(fromAgentPlatform: $0) }
    self.safetySettings = request.safetySettings?.map { SafetySetting(fromAgentPlatform: $0) }
    self.systemInstruction = request.systemInstruction.map { GeminiContent(fromAgentPlatform: $0) }
    self.tools = request.tools?.map { GeminiTool(fromAgentPlatform: $0) }
    self.toolConfig = request.toolConfig.map { ToolConfig(fromAgentPlatform: $0) }
    self.cachedContent = request.cachedContent
    self.serviceTier = nil
    self.store = nil
    self.labels = request.labels
    self.modelArmorConfig = request.modelArmorConfig
  }
}
