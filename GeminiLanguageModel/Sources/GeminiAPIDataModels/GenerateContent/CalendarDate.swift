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

/// Represents a whole or partial calendar date, such as a birthday. The time of day and time zone
/// are either specified elsewhere or are insignificant. The date is relative to the Gregorian
/// Calendar. This can represent one of the following: * A full date, with non-zero year, month, and
/// day values. * A month and day, with a zero year (for example, an anniversary). * A year on its
/// own, with a zero month and a zero day. * A year and month, with a zero day (for example, a
/// credit card expiration date). Related types: * google.type.TimeOfDay * google.type.DateTime *
/// google.protobuf.Timestamp
///
/// > Important: This type is not supported in the Gemini Developer API.
package struct CalendarDate: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Day of a month. Must be from 1 to 31 and valid for the year and month, or 0 to specify a year
  /// by itself or a year and month where the day isn't significant.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var day: Int?

  /// Month of a year. Must be from 1 to 12, or 0 to specify a year without a month and day.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var month: Int?

  /// Year of the date. Must be from 1 to 9999, or 0 to specify a date without a year.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var year: Int?

  /// Initializes a new `CalendarDate`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case day
    case month
    case year
  }
}
