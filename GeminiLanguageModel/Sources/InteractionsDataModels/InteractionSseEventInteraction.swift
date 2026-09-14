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

/// Partial interaction resource emitted by interaction lifecycle SSE events.
/// Streaming lifecycle payloads may omit fields that are only available on
/// full non-streaming Interaction responses.
package struct InteractionSseEventInteraction: Codable, Sendable, Equatable, Hashable {

  /// The agent to interact with.
  package let agent: String?

  /// Output only. The time at which the response was created in ISO 8601 format.
  package let created: String?

  /// Required. Output only. A unique identifier for the interaction completion.
  package let id: String?

  /// The model that will complete your prompt.
  package let model: String?

  /// Output only. The resource type.
  package let object: String?

  /// The service tier for the interaction.
  package let serviceTier: ServiceTier?

  /// Required. Output only. The status of the interaction.
  package let status: Status?

  /// Output only. The steps that make up the interaction, if included in this event.
  package let steps: [Step]?

  /// Output only. The time at which the response was last updated in ISO 8601 format.
  package let updated: String?

  /// Output only. Statistics on the interaction request's token usage.
  package let usage: Usage?

  /// Creates a new `InteractionSseEventInteraction`.
  ///
  /// - Parameters:
  ///   - agent: The agent to interact with.
  ///   - created: Output only. The time at which the response was created in ISO 8601 format.
  ///   - id: Required. Output only. A unique identifier for the interaction completion.
  ///   - model: The model that will complete your prompt.
  ///   - object: Output only. The resource type.
  ///   - serviceTier: The service tier for the interaction.
  ///   - status: Required. Output only. The status of the interaction.
  ///   - steps: Output only. The steps that make up the interaction, if included in this event.
  ///   - updated: Output only. The time at which the response was last updated in ISO 8601 format.
  ///   - usage: Output only. Statistics on the interaction request's token usage.
  package init(
    agent: String? = nil,
    created: String? = nil,
    id: String?,
    model: String? = nil,
    object: String? = nil,
    serviceTier: ServiceTier? = nil,
    status: Status?,
    steps: [Step]? = nil,
    updated: String? = nil,
    usage: Usage? = nil
  ) {
    self.agent = agent
    self.created = created
    self.id = id
    self.model = model
    self.object = object
    self.serviceTier = serviceTier
    self.status = status
    self.steps = steps
    self.updated = updated
    self.usage = usage
  }
  enum CodingKeys: String, CodingKey {
    case agent = "agent"
    case created = "created"
    case id = "id"
    case model = "model"
    case object = "object"
    case serviceTier = "service_tier"
    case status = "status"
    case steps = "steps"
    case updated = "updated"
    case usage = "usage"
  }
}
