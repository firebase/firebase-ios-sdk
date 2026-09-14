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

/// Parameters for creating model interactions
package struct CreateModelInteraction: Codable, Sendable, Equatable, Hashable {

  /// Input only. Whether to run the model interaction in the background.
  package let background: Bool?

  /// Required. Output only. The time at which the response was created in ISO 8601 format
  /// (YYYY-MM-DDThh:mm:ssZ).
  package let created: String?

  /// The environment configuration for the interaction. Can be an object specifying remote environment sources or a string referencing an existing environment ID.
  package let environment: JSONValue?

  /// Output only. The environment ID for the interaction. Only populated if environment
  /// config is set in the request.
  package let environmentId: String?

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

  /// Input only. Whether to store the response and request for later retrieval.
  package let store: Bool?

  /// Input only. Whether the interaction will be streamed.
  package let stream: Bool?

  /// System instruction for the interaction.
  package let systemInstruction: String?

  /// A list of tool declarations the model may call during interaction.
  package let tools: [Tool]?

  /// Required. Output only. The time at which the response was last updated in ISO 8601 format
  /// (YYYY-MM-DDThh:mm:ssZ).
  package let updated: String?

  /// Optional. Webhook configuration for receiving notifications when the
  /// interaction completes.
  package let webhookConfig: WebhookConfig?

  /// Creates a new `CreateModelInteraction`.
  ///
  /// - Parameters:
  ///   - background: Input only. Whether to run the model interaction in the background.
  ///   - created: Required. Output only. The time at which the response was created in ISO 8601 format
  ///   - environment: The environment configuration for the interaction. Can be an object specifying remote environment sources or a string referencing an existing environment ID.
  ///   - environmentId: Output only. The environment ID for the interaction. Only populated if environment
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
  ///   - store: Input only. Whether to store the response and request for later retrieval.
  ///   - stream: Input only. Whether the interaction will be streamed.
  ///   - systemInstruction: System instruction for the interaction.
  ///   - tools: A list of tool declarations the model may call during interaction.
  ///   - updated: Required. Output only. The time at which the response was last updated in ISO 8601 format
  ///   - webhookConfig: Optional. Webhook configuration for receiving notifications when the
  package init(
    background: Bool? = nil,
    created: String? = nil,
    environment: JSONValue? = nil,
    environmentId: String? = nil,
    generationConfig: GenerationConfig? = nil,
    id: String? = nil,
    input: InteractionsInput?,
    labels: [String: String]? = nil,
    model: Model?,
    previousInteractionId: String? = nil,
    responseFormat: JSONValue? = nil,
    responseMimeType: String? = nil,
    responseModalities: [ResponseModality]? = nil,
    safetySettings: [SafetySetting]? = nil,
    serviceTier: ServiceTier? = nil,
    status: Status? = nil,
    store: Bool? = nil,
    stream: Bool? = nil,
    systemInstruction: String? = nil,
    tools: [Tool]? = nil,
    updated: String? = nil,
    webhookConfig: WebhookConfig? = nil
  ) {
    self.background = background
    self.created = created
    self.environment = environment
    self.environmentId = environmentId
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
    self.store = store
    self.stream = stream
    self.systemInstruction = systemInstruction
    self.tools = tools
    self.updated = updated
    self.webhookConfig = webhookConfig
  }
  enum CodingKeys: String, CodingKey {
    case background = "background"
    case created = "created"
    case environment = "environment"
    case environmentId = "environment_id"
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
    case store = "store"
    case stream = "stream"
    case systemInstruction = "system_instruction"
    case tools = "tools"
    case updated = "updated"
    case webhookConfig = "webhook_config"
  }
}
