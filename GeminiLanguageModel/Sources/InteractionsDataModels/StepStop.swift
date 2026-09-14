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

/// An internal data model for `StepStop`.
package struct StepStop: Codable, Sendable, Equatable, Hashable {

  /// The event_id token to be used to resume the interaction stream, from
  /// this event.
  package let eventId: String?

  package let eventType: String?

  package let index: Int?

  /// Model usage stats for this specific step.
  package let stepUsage: Usage?

  /// Cumulative model usage stats from the start of the session.
  package let usage: Usage?

  /// Creates a new `StepStop`.
  ///
  /// - Parameters:
  ///   - eventId: The event_id token to be used to resume the interaction stream, from
  ///   - index: For more details, see ``index``.
  ///   - stepUsage: Model usage stats for this specific step.
  ///   - usage: Cumulative model usage stats from the start of the session.
  package init(
    eventId: String? = nil,
    index: Int?,
    stepUsage: Usage? = nil,
    usage: Usage? = nil
  ) {
    self.eventId = eventId
    self.eventType = "step.stop"
    self.index = index
    self.stepUsage = stepUsage
    self.usage = usage
  }
  enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case eventType = "event_type"
    case index = "index"
    case stepUsage = "step_usage"
    case usage = "usage"
  }
}
