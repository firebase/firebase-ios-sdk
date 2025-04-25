// Copyright 2024 Google LLC
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

/// Represents a whole or partial calendar date, such as a birthday.
///
/// The time of day and time zone are either specified elsewhere or are insignificant. The date is
/// relative to the Gregorian Calendar. This can represent one of the following:
/// - A full date, with non-zero year, month, and day values
/// - A month and day value, with a zero year, such as an anniversary
/// - A year on its own, with zero month and day values
/// - A year and month value, with a zero day, such as a credit card expiration date
///
/// This represents a
/// [`google.type.Date`](https://cloud.google.com/vertex-ai/docs/reference/rest/Shared.Types/Date).
struct ProtoDate {
  /// Year of the date.
  ///
  /// Must be from 1 to 9999, or 0 to specify a date without a year.
  let year: Int?

  /// Month of a year.
  ///
  /// Must be from 1 to 12, or 0 to specify a year without a month and day.
  let month: Int?

  /// Day of a month.
  ///
  /// Must be from 1 to 31 and valid for the year and month, or 0 to specify a year by itself or a
  /// year and month where the day isn't significant.
  let day: Int?

  /// Returns the a `DateComponents` representation of the `ProtoDate`.
  ///
  /// > Note: This uses the Gregorian `Calendar` to match the `google.type.Date` definition.
  var dateComponents: DateComponents {
    DateComponents(
      calendar: Calendar(identifier: .gregorian),
      year: year,
      month: month,
      day: day
    )
  }
}

// MARK: - Codable Conformance

extension ProtoDate: Decodable {
  enum CodingKeys: CodingKey {
    case year
    case month
    case day
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let year = try container.decodeIfPresent(Int.self, forKey: .year), year != 0 {
      if year < 0 || year > 9999 {
        VertexLog.warning(
          code: .decodedInvalidProtoDateYear,
          """
          Invalid year: \(year); must be from 1 to 9999, or 0 for a date without a specified year.
          """
        )
      }
      self.year = year
    } else {
      year = nil
    }

    if let month = try container.decodeIfPresent(Int.self, forKey: .month), month != 0 {
      if month < 0 || month > 12 {
        VertexLog.warning(
          code: .decodedInvalidProtoDateMonth,
          """
          Invalid month: \(month); must be from 1 to 12, or 0 for a year date without a specified \
          month and day.
          """
        )
      }
      self.month = month
    } else {
      month = nil
    }

    if let day = try container.decodeIfPresent(Int.self, forKey: .day), day != 0 {
      if day < 0 || day > 31 {
        VertexLog.warning(
          code: .decodedInvalidProtoDateDay,
          "Invalid day: \(day); must be from 1 to 31, or 0 for a date without a specified day."
        )
      }
      self.day = day
    } else {
      day = nil
    }

    guard year != nil || month != nil || day != nil else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [CodingKeys.year, CodingKeys.month, CodingKeys.day],
        debugDescription: "Invalid date: missing year, month and day"
      ))
    }
  }
}
