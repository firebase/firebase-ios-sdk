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

  /// Returns a `Date` representation of the `ProtoDate`.
  ///
  /// - Throws: An error of type `DateConversionError` if the `ProtoDate` cannot be represented as
  ///   a `Date`.
  func asDate() throws -> Date {
    guard year != nil else {
      throw DateConversionError(message: "Missing a year: \(self)")
    }
    guard month != nil else {
      throw DateConversionError(message: "Missing a month: \(self)")
    }
    guard day != nil else {
      throw DateConversionError(message: "Missing a day: \(self)")
    }
    guard dateComponents.isValidDate, let date = dateComponents.date else {
      throw DateConversionError(message: "Invalid date: \(self)")
    }
    return date
  }

  struct DateConversionError: Error {
    let localizedDescription: String

    init(message: String) {
      localizedDescription = message
    }
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
      guard year >= 1 && year <= 9999 else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: [CodingKeys.year], debugDescription: "Invalid year: \(year)")
        )
      }
      self.year = year
    } else {
      year = nil
    }

    if let month = try container.decodeIfPresent(Int.self, forKey: .month), month != 0 {
      guard month >= 1 && month <= 12 else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: [CodingKeys.month], debugDescription: "Invalid month: \(month)")
        )
      }
      self.month = month
    } else {
      month = nil
    }

    if let day = try container.decodeIfPresent(Int.self, forKey: .day), day != 0 {
      guard day >= 1 && day <= 31 else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: [CodingKeys.day], debugDescription: "Invalid day: \(day)")
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
