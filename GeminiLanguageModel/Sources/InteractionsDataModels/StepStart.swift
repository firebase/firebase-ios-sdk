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

/// An internal data model for `StepStart`.
package struct StepStart: Codable, Sendable, Equatable, Hashable {

  /// The event_id token to be used to resume the interaction stream, from
  /// this event.
  package let eventId: String?

  package let eventType: String?

  package let index: Int?

  package let step: Step?

  /// Creates a new `StepStart`.
  ///
  /// - Parameters:
  ///   - eventId: The event_id token to be used to resume the interaction stream, from
  ///   - index: For more details, see ``index``.
  ///   - step: For more details, see ``step``.
  package init(
    eventId: String? = nil,
    index: Int?,
    step: Step?
  ) {
    self.eventId = eventId
    self.eventType = "step.start"
    self.index = index
    self.step = step
  }
  enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case eventType = "event_type"
    case index = "index"
    case step = "step"
  }
}
