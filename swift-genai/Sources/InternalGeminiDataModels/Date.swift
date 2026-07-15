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


extension GeminiDataModels {
  /// An internal data model for `Date`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `Date`
  /// 
  /// Represents a whole or partial calendar date, such as a birthday. The time of
  /// day and time zone are either specified elsewhere or are insignificant. The
  /// date is relative to the Gregorian Calendar. This can represent one of the
  /// following:
  /// 
  /// * A full date, with non-zero year, month, and day values.
  /// * A month and day, with a zero year (for example, an anniversary).
  /// * A year on its own, with a zero month and a zero day.
  /// * A year and month, with a zero day (for example, a credit card expiration
  ///   date).
  /// 
  /// Related types:
  /// 
  /// * google.type.TimeOfDay
  /// * google.type.DateTime
  /// * google.protobuf.Timestamp
  package struct Date: Codable, Sendable, Equatable, Hashable {
    /// Year of the date. Must be from 1 to 9999, or 0 to specify a date without
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Year of the date. Must be from 1 to 9999, or 0 to specify a date without
    /// a year.
    package let year: Int?
    
    /// Month of a year. Must be from 1 to 12, or 0 to specify a year without a
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Month of a year. Must be from 1 to 12, or 0 to specify a year without a
    /// month and day.
    package let month: Int?
    
    /// Day of a month. Must be from 1 to 31 and valid for the year and month, or 0
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Day of a month. Must be from 1 to 31 and valid for the year and month, or 0
    /// to specify a year by itself or a year and month where the day isn't
    /// significant.
    package let day: Int?
    

    /// Creates a new `Date`.
    ///
    /// - Parameters:
    ///   - year: Year of the date. Must be from 1 to 9999, or 0 to specify a date without (Gemini Enterprise Agent Platform only). For more details, see ``year``.
    ///   - month: Month of a year. Must be from 1 to 12, or 0 to specify a year without a (Gemini Enterprise Agent Platform only). For more details, see ``month``.
    ///   - day: Day of a month. Must be from 1 to 31 and valid for the year and month, or 0 (Gemini Enterprise Agent Platform only). For more details, see ``day``.
    package init(
      year: Int? = nil,
      month: Int? = nil,
      day: Int? = nil
    ) {
      self.year = year
      self.month = month
      self.day = day
    }
    enum CodingKeys: String, CodingKey {
      case year = "year"
      case month = "month"
      case day = "day"
    }
  }
}