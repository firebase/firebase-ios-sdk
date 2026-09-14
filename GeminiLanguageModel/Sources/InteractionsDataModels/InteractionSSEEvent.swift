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

/// An internal data model for `InteractionSSEEvent`.
package enum InteractionSSEEvent: Codable, Sendable, Equatable, Hashable {

  /// An internal data model for `ErrorEvent`.
  case errorEvent(ErrorEvent)

  /// An internal data model for `InteractionCompletedEvent`.
  case interactionCompletedEvent(InteractionCompletedEvent)

  /// An internal data model for `InteractionCreatedEvent`.
  case interactionCreatedEvent(InteractionCreatedEvent)

  /// An internal data model for `InteractionStatusUpdate`.
  case interactionStatusUpdate(InteractionStatusUpdate)

  /// An internal data model for `StepDelta`.
  case stepDelta(StepDelta)

  /// An internal data model for `StepStart`.
  case stepStart(StepStart)

  /// An internal data model for `StepStop`.
  case stepStop(StepStop)

  /// Unrecognized case.
  case unrecognized(JSONValue)

  private enum CodingKeys: String, CodingKey {
    case discriminator = "event_type"
    case typeFallback = "type"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let discValue =
      try container.decodeIfPresent(String.self, forKey: .discriminator)
      ?? container.decode(String.self, forKey: .typeFallback)
    switch discValue {
    case "error":
      let val = try ErrorEvent(from: decoder)
      self = .errorEvent(val)
    case "interaction.completed":
      let val = try InteractionCompletedEvent(from: decoder)
      self = .interactionCompletedEvent(val)
    case "interaction.created":
      let val = try InteractionCreatedEvent(from: decoder)
      self = .interactionCreatedEvent(val)
    case "interaction.status_update":
      let val = try InteractionStatusUpdate(from: decoder)
      self = .interactionStatusUpdate(val)
    case "step.delta":
      let val = try StepDelta(from: decoder)
      self = .stepDelta(val)
    case "step.start":
      let val = try StepStart(from: decoder)
      self = .stepStart(val)
    case "step.stop":
      let val = try StepStop(from: decoder)
      self = .stepStop(val)
    default:
      let val = try JSONValue(from: decoder)
      self = .unrecognized(val)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .errorEvent(let val):
      try val.encode(to: encoder)
    case .interactionCompletedEvent(let val):
      try val.encode(to: encoder)
    case .interactionCreatedEvent(let val):
      try val.encode(to: encoder)
    case .interactionStatusUpdate(let val):
      try val.encode(to: encoder)
    case .stepDelta(let val):
      try val.encode(to: encoder)
    case .stepStart(let val):
      try val.encode(to: encoder)
    case .stepStop(let val):
      try val.encode(to: encoder)
    case .unrecognized(let val):
      try val.encode(to: encoder)
    }
  }
}
