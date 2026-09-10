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

/// An internal data model for `InteractionCompletedEvent`.
package struct InteractionCompletedEvent: Codable, Sendable, Equatable, Hashable {

  /// The event_id token to be used to resume the interaction stream, from
  /// this event.
  package let eventId: String?

  package let eventType: String?

  /// Partial completed interaction resource emitted at the end of the stream.
  package let interaction: InteractionSseEventInteraction?

  /// Creates a new `InteractionCompletedEvent`.
  ///
  /// - Parameters:
  ///   - eventId: The event_id token to be used to resume the interaction stream, from
  ///   - interaction: Partial completed interaction resource emitted at the end of the stream.
  package init(
    eventId: String? = nil,
    interaction: InteractionSseEventInteraction?
  ) {
    self.eventId = eventId
    self.eventType = "interaction.completed"
    self.interaction = interaction
  }
  enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case eventType = "event_type"
    case interaction = "interaction"
  }
}
