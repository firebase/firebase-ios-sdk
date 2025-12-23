// Copyright 2025 Google LLC
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

public struct TimeGranularity: Sendable, Equatable, Hashable {
  enum Kind: String {
    case microsecond
    case millisecond
    case second
    case minute
    case hour
    case day
    case week
    case weekMonday = "week(monday)"
    case weekTuesday = "week(tuesday)"
    case weekWednesday = "week(wednesday)"
    case weekThursday = "week(thursday)"
    case weekFriday = "week(friday)"
    case weekSaturday = "week(saturday)"
    case weekSunday = "week(sunday)"
    case isoweek
    case month
    case quarter
    case year
    case isoyear
  }

  public static let microsecond = TimeGranularity(kind: .microsecond)
  public static let millisecond = TimeGranularity(kind: .millisecond)
  public static let second = TimeGranularity(kind: .second)
  public static let minute = TimeGranularity(kind: .minute)
  public static let hour = TimeGranularity(kind: .hour)
  /// The day in the Gregorian calendar year that contains the value to truncate.
  public static let day = TimeGranularity(kind: .day)
  /// The first day in the week that contains the value to truncate. Weeks begin on Sundays. WEEK is
  /// equivalent to WEEK(SUNDAY).
  public static let week = TimeGranularity(kind: .week)
  /// The first day in the week that contains the value to truncate. Weeks begin on Monday.
  public static let weekMonday = TimeGranularity(kind: .weekMonday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Tuesday.
  public static let weekTuesday = TimeGranularity(kind: .weekTuesday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Wednesday.
  public static let weekWednesday = TimeGranularity(kind: .weekWednesday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Thursday.
  public static let weekThursday = TimeGranularity(kind: .weekThursday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Friday.
  public static let weekFriday = TimeGranularity(kind: .weekFriday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Saturday.
  public static let weekSaturday = TimeGranularity(kind: .weekSaturday)
  /// The first day in the week that contains the value to truncate. Weeks begin on Sunday.
  public static let weekSunday = TimeGranularity(kind: .weekSunday)
  /// The first day in the ISO 8601 week that contains the value to truncate. The ISO week begins on
  /// Monday. The first ISO week of each ISO year contains the first Thursday of the corresponding
  /// Gregorian calendar year.
  public static let isoweek = TimeGranularity(kind: .isoweek)
  /// The first day in the month that contains the value to truncate.
  public static let month = TimeGranularity(kind: .month)
  /// The first day in the quarter that contains the value to truncate.
  public static let quarter = TimeGranularity(kind: .quarter)
  /// The first day in the year that contains the value to truncate.
  public static let year = TimeGranularity(kind: .year)
  /// The first day in the ISO 8601 week-numbering year that contains the value to truncate. The ISO
  /// year is the Monday of the first week where Thursday belongs to the corresponding Gregorian
  /// calendar year.
  public static let isoyear = TimeGranularity(kind: .isoyear)

  public let rawValue: String

  init(kind: Kind) {
    rawValue = kind.rawValue
  }
}
