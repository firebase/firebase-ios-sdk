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

public struct TimePart: Sendable, Equatable, Hashable {
  enum Kind: String {
    case microsecond
    case millisecond
    case second
    case minute
    case hour
    case dayOfWeek = "dayofweek"
    case day
    case dayOfYear = "dayofyear"
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

  public static let microsecond = TimePart(kind: .microsecond)
  public static let millisecond = TimePart(kind: .millisecond)
  public static let second = TimePart(kind: .second)
  public static let minute = TimePart(kind: .minute)
  public static let hour = TimePart(kind: .hour)
  public static let dayOfWeek = TimePart(kind: .dayOfWeek)
  public static let day = TimePart(kind: .day)
  public static let dayOfYear = TimePart(kind: .dayOfYear)
  public static let week = TimePart(kind: .week)
  public static let weekMonday = TimePart(kind: .weekMonday)
  public static let weekTuesday = TimePart(kind: .weekTuesday)
  public static let weekWednesday = TimePart(kind: .weekWednesday)
  public static let weekThursday = TimePart(kind: .weekThursday)
  public static let weekFriday = TimePart(kind: .weekFriday)
  public static let weekSaturday = TimePart(kind: .weekSaturday)
  public static let weekSunday = TimePart(kind: .weekSunday)
  public static let isoweek = TimePart(kind: .isoweek)
  public static let month = TimePart(kind: .month)
  public static let quarter = TimePart(kind: .quarter)
  public static let year = TimePart(kind: .year)
  public static let isoyear = TimePart(kind: .isoyear)

  public let rawValue: String

  init(kind: Kind) {
    rawValue = kind.rawValue
  }
}
