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

/// An internal data model for `StepDelta`.
package struct StepDelta: Codable, Sendable, Equatable, Hashable {

  package let delta: StepDeltaData?

  /// The event_id token to be used to resume the interaction stream, from
  /// this event.
  package let eventId: String?

  package let eventType: String?

  package let index: Int?

  package let metadata: StepDeltaMetadata?

  /// Creates a new `StepDelta`.
  ///
  /// - Parameters:
  ///   - delta: For more details, see ``delta``.
  ///   - eventId: The event_id token to be used to resume the interaction stream, from
  ///   - index: For more details, see ``index``.
  ///   - metadata: For more details, see ``metadata``.
  package init(
    delta: StepDeltaData?,
    eventId: String? = nil,
    index: Int?,
    metadata: StepDeltaMetadata? = nil
  ) {
    self.delta = delta
    self.eventId = eventId
    self.eventType = "step.delta"
    self.index = index
    self.metadata = metadata
  }
  enum CodingKeys: String, CodingKey {
    case delta = "delta"
    case eventId = "event_id"
    case eventType = "event_type"
    case index = "index"
    case metadata = "metadata"
  }
}
