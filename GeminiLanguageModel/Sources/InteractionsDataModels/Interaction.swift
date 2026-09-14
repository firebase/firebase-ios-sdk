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

package import GeminiSharedDataModels

/// The Interaction resource.
package struct Interaction: Codable, Sendable, Equatable, Hashable {

  /// The name of the `Agent` used for generating the interaction.
  package let agent: AgentOption?

  /// Configuration parameters for the agent interaction.
  package let agentConfig: JSONValue?

  /// Output only. The time at which the response was created in ISO 8601 format
  /// (YYYY-MM-DDThh:mm:ssZ).
  package let created: String?

  /// The environment configuration for the interaction. Can be an object specifying remote environment sources or a string referencing an existing environment ID.
  package let environment: JSONValue?

  /// Output only. The environment ID for the interaction. Only populated if environment
  /// config is set in the request.
  package let environmentId: String?

  /// Output only. Diagnostic faults / platform errors recorded on the interaction.
  package let errors: [Error]?

  /// Input only. Configuration parameters for the model interaction.
  package let generationConfig: GenerationConfig?

  /// Required. Output only. A unique identifier for the interaction completion.
  package let id: String?

  package let input: InteractionsInput?

  /// The labels with user-defined metadata for the request.
  package let labels: [String: String]?

  /// The name of the `Model` used for generating the interaction.
  package let model: Model?

  /// The ID of the previous interaction, if any.
  package let previousInteractionId: String?

  /// Enforces that the generated response is a JSON object that complies with the JSON schema specified in this field.
  package let responseFormat: JSONValue?

  /// The mime type of the response. This is required if response_format is set.
  @available(*, deprecated)
  package let responseMimeType: String?

  /// The requested modalities of the response (TEXT, IMAGE, AUDIO).
  @available(*, deprecated)
  package let responseModalities: [ResponseModality]?

  /// Safety settings for the interaction.
  package let safetySettings: [SafetySetting]?

  /// The service tier for the interaction.
  package let serviceTier: ServiceTier?

  /// Required. Output only. The status of the interaction.
  package let status: Status?

  /// Output only. The steps that make up the interaction, when included in the response.
  package let steps: [Step]?

  /// System instruction for the interaction.
  package let systemInstruction: String?

  /// A list of tool declarations the model may call during interaction.
  package let tools: [Tool]?

  /// Output only. The time at which the response was last updated in ISO 8601 format
  /// (YYYY-MM-DDThh:mm:ssZ).
  package let updated: String?

  /// Output only. Statistics on the interaction request's token usage.
  package let usage: Usage?

  /// Optional. Webhook configuration for receiving notifications when the
  /// interaction completes.
  package let webhookConfig: WebhookConfig?

  /// Creates a new `Interaction`.
  ///
  /// - Parameters:
  ///   - agent: The name of the `Agent` used for generating the interaction.
  ///   - agentConfig: Configuration parameters for the agent interaction.
  ///   - created: Output only. The time at which the response was created in ISO 8601 format
  ///   - environment: The environment configuration for the interaction. Can be an object specifying remote environment sources or a string referencing an existing environment ID.
  ///   - environmentId: Output only. The environment ID for the interaction. Only populated if environment
  ///   - errors: Output only. Diagnostic faults / platform errors recorded on the interaction.
  ///   - generationConfig: Input only. Configuration parameters for the model interaction.
  ///   - id: Required. Output only. A unique identifier for the interaction completion.
  ///   - input: For more details, see ``input``.
  ///   - labels: The labels with user-defined metadata for the request.
  ///   - model: The name of the `Model` used for generating the interaction.
  ///   - previousInteractionId: The ID of the previous interaction, if any.
  ///   - responseFormat: Enforces that the generated response is a JSON object that complies with the JSON schema specified in this field.
  ///   - responseMimeType: The mime type of the response. This is required if response_format is set.
  ///   - responseModalities: The requested modalities of the response (TEXT, IMAGE, AUDIO).
  ///   - safetySettings: Safety settings for the interaction.
  ///   - serviceTier: The service tier for the interaction.
  ///   - status: Required. Output only. The status of the interaction.
  ///   - steps: Output only. The steps that make up the interaction, when included in the response.
  ///   - systemInstruction: System instruction for the interaction.
  ///   - tools: A list of tool declarations the model may call during interaction.
  ///   - updated: Output only. The time at which the response was last updated in ISO 8601 format
  ///   - usage: Output only. Statistics on the interaction request's token usage.
  ///   - webhookConfig: Optional. Webhook configuration for receiving notifications when the
  package init(
    agent: AgentOption? = nil,
    agentConfig: JSONValue? = nil,
    created: String? = nil,
    environment: JSONValue? = nil,
    environmentId: String? = nil,
    errors: [Error]? = nil,
    generationConfig: GenerationConfig? = nil,
    id: String? = nil,
    input: InteractionsInput? = nil,
    labels: [String: String]? = nil,
    model: Model? = nil,
    previousInteractionId: String? = nil,
    responseFormat: JSONValue? = nil,
    responseMimeType: String? = nil,
    responseModalities: [ResponseModality]? = nil,
    safetySettings: [SafetySetting]? = nil,
    serviceTier: ServiceTier? = nil,
    status: Status?,
    steps: [Step]? = nil,
    systemInstruction: String? = nil,
    tools: [Tool]? = nil,
    updated: String? = nil,
    usage: Usage? = nil,
    webhookConfig: WebhookConfig? = nil
  ) {
    self.agent = agent
    self.agentConfig = agentConfig
    self.created = created
    self.environment = environment
    self.environmentId = environmentId
    self.errors = errors
    self.generationConfig = generationConfig
    self.id = id
    self.input = input
    self.labels = labels
    self.model = model
    self.previousInteractionId = previousInteractionId
    self.responseFormat = responseFormat
    self.responseMimeType = responseMimeType
    self.responseModalities = responseModalities
    self.safetySettings = safetySettings
    self.serviceTier = serviceTier
    self.status = status
    self.steps = steps
    self.systemInstruction = systemInstruction
    self.tools = tools
    self.updated = updated
    self.usage = usage
    self.webhookConfig = webhookConfig
  }
  enum CodingKeys: String, CodingKey {
    case agent = "agent"
    case agentConfig = "agent_config"
    case created = "created"
    case environment = "environment"
    case environmentId = "environment_id"
    case errors = "errors"
    case generationConfig = "generation_config"
    case id = "id"
    case input = "input"
    case labels = "labels"
    case model = "model"
    case previousInteractionId = "previous_interaction_id"
    case responseFormat = "response_format"
    case responseMimeType = "response_mime_type"
    case responseModalities = "response_modalities"
    case safetySettings = "safety_settings"
    case serviceTier = "service_tier"
    case status = "status"
    case steps = "steps"
    case systemInstruction = "system_instruction"
    case tools = "tools"
    case updated = "updated"
    case usage = "usage"
    case webhookConfig = "webhook_config"
  }
}
